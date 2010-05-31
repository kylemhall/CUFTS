
use strict;
use lib qw(lib);

use CUFTS::DB::LocalJournals;
use CUFTS::DB::Journals;
use CUFTS::DB::LocalResources;
use CUFTS::DB::JournalsAuth;
use CUFTS::DB::Sites;

use CJDB::DB::Journals;

use CJDB::DB::DBI;
use CUFTS::DB::DBI;

use CUFTS::CJDB::Loader::MARC::JournalsAuth;
use CUFTS::CJDB::Util;
use CUFTS::Resolve;

use Getopt::Long;
use String::Util qw(hascontent trim);
use List::MoreUtils qw(any uniq);

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

# Global variables used to avoid recomputing, probably could be done with the new "state" feature in 5.10
my $global_current_date;

load();

sub load {
    my $logger = Log::Log4perl->get_logger();

    my %options;
    GetOptions( \%options, 'site_key=s@', 'site_id=i@', 'print_file=s', 'force' );

    $logger->info('Starting CJDB rebuild script.');

    my @sites = scalar(@{$options{site_id}})    ? CUFTS::DB::Sites->search( { id =>  { '-in' => [ grep { $_ } map { int($_) } @{$options{site_id}} ] } } )
              : scalar(@{$options{site_key}})   ? CUFTS::DB::Sites->search( { key => { '-in' => $options{site_key} } } )
              : CUFTS::DB::Sites->search({ '-or' => { rebuild_cjdb => { '!=' => undef }, rebuild_ejournals_only => '1' } });

SITE:
    foreach my $site (@sites) {
        next if !hascontent( $site->rebuild_cjdb )
             && $site->rebuild_ejournals_only ne '1'
             && !$options{force};

        $logger->info('Rebuild started for site: ', $site->name, ' (', $site->key, ')');
        my $start_time = time;

        build_local_journal_auths($site);

        # TODO: Rebuild print records goes here.

        my $MARC_cache = {};
        eval {
            load_cufts_data( $logger, $site, \%options, $MARC_cache );
        };
        if ($@) {
            $logger->error('Error loading CUFTS data: ', $@);
            $logger->info('Skipping site due to error, no data was saved.');
            CUFTS::DB::DBI->dbi_rollback;
            CJDB::DB::DBI->dbi_rollback;
            next SITE;
        }


        $site->rebuild_cjdb(undef);
        $site->rebuild_ejournals_only(undef);
        $site->update;

        CUFTS::DB::DBI->dbi_commit;
        CJDB::DB::DBI->dbi_commit;

        build_dump( $logger, $site, $MARC_cache );

        $logger->info('Rebuild complete for site: ', $site->name, ' (', $site->key, '): ', format_duration(time-$start_time));
    }

    $logger->info('Finished CJDB rebuilds.');
}

##
## Print record loading code - reads journal records and builds a set of large hashrefs representing the whole update.
## No transaction is started during this part
##

sub load_print_data {
    my ( $logger, $site, $links, $journal_auths, $options, $MARC_cache ) = @_;

    my $site_id = $site->id;

    return if !hascontent($site->rebuild_cjdb) && !hascontent($options->{print_file});
    
    my @files =   $options->{print_file} ? ( $options->{print_file} )
                : map { $CUFTS::Config::CJDB_SITE_DATA_DIR . '/' . $site->id . '/' . $_ }
                    split /\|/, $site->rebuild_cjdb;

    my $start_time = time;
    $logger->info('Starting to process print data.');

    my $loader = load_print_module( $logger, $site );
    $loader->site_id( $site->id );
    @files = $loader->pre_process(@files);

    my $batch = $loader->get_batch(@files);
    $batch->strict_off;

    my $count = 0;
    while ( my $record = $batch->next() ) {
        $count++;

        next if !defined($record) || $loader->skip_record($record);

        my $journal_auth_id = $loader->match_journals_auth($record);

        # Create a new journal auth record based on the print data if necessary.
        # This is done in its own transaction to keep it from locking tables for the whole CJDB update.
        if ( !defined($journal_auth_id) ) {
            $journal_auth_id = create_basic_ja( $logger, $loader, $record );
        }

        if ( !defined($journal_auth_id) ) {
            $logger->warn('Unable to find or create a journal auth record for print title: ' . $loader->get_title($record) );
            next;
        }

        $MARC_cache->{$journal_auth_id}->{MARC} = $record;
        
        # Print records are used to populate both links and "journal auth" data
        
        load_print_link( $logger, $site, $loader, $links, $journal_auth_id, $record ); 

        next if exists $journal_auths->{$journal_auth_id};
        
        $journal_auths->{$journal_auth_id} = {
            title  => $loader->get_title($record),
            issns  => [ $loader->get_issns($record) ],
            titles => [ $loader->get_alt_titles($record) ],
        };

        ja_augment_with_marc( $loader, $logger, $journal_auths->{$journal_auth_id}, $record, $site_id );

    }

    $logger->info('Finished processing print data: ', format_duration(time-$start_time));
}

# Gets the print module for a site, requires it, and creates a loader object

sub load_print_module {
    my ( $logger, $site ) = @_;
    my $site_key = $site->key;

    my $module_name = 'CUFTS::CJDB::Loader::MARC::' . $site_key;
    $logger->trace( 'Loading print module: ', $module_name );

    eval { require $module_name };
    if ($@) {
        die("Unable to require $module_name: $@");
    }

    my $module = $module_name->new();
    defined($module)
        or die("Failed to create new loading object from module: $module_name");

    return $module;
}

# Gets a set of print links for a MARC record and adds it to the links hash

sub load_print_link {
    my ( $logger, $site, $loader, $links, $journal_auth_id, $record ) = @_;
    
    my $new_link = {
        print_coverage  => $loader->get_coverage($record),
        urls            => [ [ 0, $loader->get_link($record) ] ],
        rank            => $loader->get_rank(),
    };
    
    return if !hascontent($new_link->{print_coverage}) || !defined($new_link->{urls});

    $links->{$journal_auth_id} = [] if !exists $links->{$journal_auth_id};
    push @{ $links->{$journal_auth_id} }, $new_link;
}

sub create_basic_ja{
    my ( $logger, $loader, $record ) = @_;
    
    my $title = $loader->get_title($record);
    my @issns = $loader->get_clean_issn_list($record);
    
    my $journals_auth = CUFTS::DB::JournalsAuth->create({ title => $title });
    return undef if !defined($journals_auth);

    $journals_auth->add_to_titles({ title => $title, title_count => 1 });

    foreach my $issn ( uniq @issns ) {
        $journals_auth->add_to_issns({ issn => $issn });
    }

    CUFTS::DB::DBI->dbi_commit();
    
    $logger->info( 'Created JA (', $journals_auth->id, '): ', $title );
    
    return $journals_auth->id;
}

##
## CUFTS Loading code - reads journal records and builds a set of large hashrefs representing the whole update.
## No transaction is started during this part
##


sub load_cufts_data {
    my ( $logger, $site, $options, $MARC_cache ) = @_;

    $logger->info('Starting to process CUFTS data.');
    
    my ( %links, %journal_auths, %resource_names );

    load_cufts_links(   $logger, $site, \%links, \%resource_names );
    load_print_data(    $logger, $site, \%links, \%journal_auths, $options, $MARC_cache );
    load_journal_auths( $logger, $site, \%links, \%journal_auths );
    update_records(     $logger, $site, \%journal_auths, \%links, \%resource_names );

    $logger->info('Completed CUFTS data processing.');
}

# Loop through active local resources, gathering holdings information and URLs.
sub load_cufts_links {
    my ( $logger, $site, $links, $resource_names ) = @_;
    
    my $start_time = time;
    my $site_id = $site->id;
    my $show_citations = $site->cjdb_show_citations;
    
    my @local_resources = CUFTS::DB::LocalResources->search({ site => $site_id, active => 't' });
    my $resource_count = 0;

    my $total_journals_count = 0;

    foreach my $local_resource (@local_resources) {
        $resource_count++;
        next if defined($local_resource->resource) && !$local_resource->resource->active;  # Skip deactivated global resources

        my $resource = CUFTS::Resolve->overlay_global_resource_data($local_resource);
        next if !defined( $resource->module );

        $logger->info("Processing resource: $resource_count/", scalar(@local_resources), ': ', $resource->name);
        my $resource_id   = $resource->id;
        my $resource_rank = $resource->rank;
        my $module = CUFTS::Resolve::__module_name( $resource->module );
        $resource_names->{$resource_id} = $resource->name;

        my $journals_iter = CUFTS::DB::LocalJournals->search({
               resource => $local_resource->id,
               active   => 'true',
        });

        my $resource_journals_count = 0;

JOURNAL:
        while ( my $local_journal = $journals_iter->next ) {

            $total_journals_count++;
            $resource_journals_count++;
            $logger->trace($resource_journals_count) if $resource_journals_count % 100 == 0;

            $local_journal = $module->fast_overlay_global_title_data($local_journal);
            my $journal_auth = $local_journal->journal_auth;

            if ( !defined($journal_auth) ) {
                $logger->trace("Skipping journal '", $local_journal->title, "' due to missing journal_auth record.");  # hmm.. trace or info?
                next JOURNAL;
            }
            my $journal_auth_id = $journal_auth->id;

            my $link = get_coverage( $local_journal, $resource_id, $resource_rank, $site_id, $show_citations );

            if ( defined($link) ) {
                my $urls = get_ft_urls( $local_journal, $resource, $site, $module );
                next JOURNAL if !defined($urls) || !scalar(@$urls);

                $link->{urls} = $urls;

                $links->{$journal_auth_id} = [] if !exists $links->{$journal_auth_id};
                push @{ $links->{$journal_auth_id} }, $link;
            }
        }
        
        $logger->info("Finished resource, found: $resource_journals_count journals.");
    }

    $logger->info('Link loading complete: ', format_duration(time-$start_time));
}


sub load_journal_auths {
    my ( $logger, $site, $links, $journal_auths ) = @_;
    
    my $start_time = time;
    $logger->info('Loading journal authority records for ', scalar(keys(%$links)), ' journals with links.');
    my $loader = CUFTS::CJDB::Loader::MARC::JournalsAuth->new()
        or die("Unable to create JournalsAuth loader");
        my $site_id = $site->id;
    $loader->site_id( $site_id );
    
    foreach my $ja_id ( keys %$links ) {
        next if exists $journal_auths->{$ja_id};  # We may already have a record from print

        my $journal_auth = CUFTS::DB::JournalsAuth->retrieve($ja_id);
        
        $journal_auths->{$ja_id} = {
            title  => $journal_auth->title,
            issns  => [ map { $_->issn }  $journal_auth->issns ],
            titles => [ map { $_->title } $journal_auth->titles ],
        };
        
        ja_augment_with_marc( $loader, $logger, $journal_auths->{$ja_id}, $journal_auth->marc_object, $site_id );
        
    }

    $logger->info('Completed journal authority loading: ', format_duration(time-$start_time));
}

sub ja_augment_with_marc {
    my ( $loader, $logger, $journal, $marc, $site_id ) = @_;
    
    return undef if !defined($marc);

    push @{$journal->{issns}}, $loader->get_issns( $marc );  # Blindly add, these should be deduped before storing

    $journal->{subjects}     = [ $loader->get_MARC_subjects( $marc ) ];
    $journal->{associations} = [ $loader->get_associations( $marc ) ];
    $journal->{relations}    = [ $loader->get_relations( $marc ) ];

    my $lcc_subjects = $loader->get_LCC_subjects( $marc, $site_id );
    foreach my $subject ( @$lcc_subjects ) {
        push( @{ $journal->{subjects} }, $subject->subject1 ) if hascontent($subject->subject1);
        push( @{ $journal->{subjects} }, $subject->subject2 ) if hascontent($subject->subject2);
        push( @{ $journal->{subjects} }, $subject->subject3 ) if hascontent($subject->subject3);
    }

}


##
## Updating code.  These save the assembled records in a transaction.
##

sub update_records {
    my ( $logger, $site, $journal_auths, $links, $resource_names ) = @_;

    my $site_id = $site->id;
    
    $logger->info('Starting database updates.');
    
    clear_site($logger, $site_id);     # Transaction starts here
    
    my $start_time = time;
    $logger->info('Creating CJDB journal records.');
    foreach my $journal_auth_id ( keys(%$journal_auths) ) {
        store_journal_record( $logger, $journal_auth_id, $journal_auths->{$journal_auth_id}, $site_id );
    }
    $logger->info('Done creating CJDB journal records: ', format_duration(time-$start_time));

    store_titles(           $logger, $journal_auths, $site_id );
    store_issns(            $logger, $journal_auths, $site_id );
    store_resource_names(   $logger, $journal_auths, $links, $resource_names, $site_id );
    store_links(            $logger, $journal_auths, $links, $resource_names, $site_id );
    store_associations(     $logger, $journal_auths, $site_id );
    store_subjects(         $logger, $journal_auths, $site_id );
    store_relations(        $logger, $journal_auths, $site_id );
        
    # We should be done with the journal_auth hash now, so delete it.
    $journal_auths = undef;
    
    $logger->info('Database updates completed, transaction closed.');

    return 1;
}

# Creates a CJDB record and adds the cjdb_id to the journal_auth hash.
sub store_journal_record {
    my ( $logger, $journal_auth_id, $journal_auth, $site_id ) = @_;

    my $title               = $journal_auth->{title};
    my $sort_title          = CUFTS::CJDB::Util::strip_articles($title);
    my $stripped_sort_title = CUFTS::CJDB::Util::strip_title($sort_title);

    my $record = {
        title               => $title,
        sort_title          => $sort_title,
        stripped_sort_title => $stripped_sort_title,
        site                => $site_id,
        journals_auth       => $journal_auth_id,
    };

    my $journal = CJDB::DB::Journals->create($record);
    my $journal_id = $journal->id;
    $journal_auth->{cjdb_id} = $journal_id;
    $journal_auth->{processed_titles} = { $stripped_sort_title => $sort_title };
    $journal_auth->{main_title} = $stripped_sort_title;

    return $journal_id;
}

# Stores deduped titles
sub store_titles {
    my ( $logger, $journal_auths, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching titles.');

    foreach my $journal_auth ( values %$journal_auths ) {

        # Dedupe on stripped_sort_title.  This is extra work here, but it saves storing a bunch of similar titles.

        my $main_title = $journal_auth->{main_title};
        my $titles = $journal_auth->{processed_titles};
        foreach my $title ( @{ $journal_auth->{titles} } ) {
            my $processed = ref($title) eq 'ARRAY' ? $title : get_processed_titles($title);  # [ $stripped, $sort ]
            next if !defined($processed) || exists $titles->{$processed->[0]};
            $titles->{$processed->[0]} = $processed->[1];
        }

        while ( my ( $stripped, $sort ) = each %$titles ) {
            my $title_id = CJDB::DB::Titles->find_or_create({
                search_title => $stripped,
                title        => $sort,
            })->id;

            CJDB::DB::JournalsTitles->create({
                title   => $title_id,
                journal => $journal_auth->{cjdb_id},
                site    => $site_id,
                main    => $stripped eq $main_title ? 1 : 0,
            });
        }
        
        delete $journal_auth->{processed_titles};  # Done with these
        delete $journal_auth->{main_title};
    }

    $logger->info('Done attaching titles: ', format_duration(time-$start_time));
}

# Dedupe ISSNs and store. These should probably be changed to an ISSN and link table.
sub store_issns {
    my ( $logger, $journal_auths, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching ISSNs.');

    foreach my $journal_auth ( values %$journal_auths ) {
        foreach my $issn ( uniq @{ $journal_auth->{issns} } ) {
            CJDB::DB::ISSNs->create({
                journal => $journal_auth->{cjdb_id},
                issn    => $issn,
                site    => $site_id,
            });
        }
    }

    $logger->info('Done attaching ISSNs: ', format_duration(time-$start_time));
}


# Dedupe associations and store.
sub store_associations {
    my ( $logger, $journal_auths, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching associations.');

    foreach my $journal_auth ( values %$journal_auths ) {
        next if !defined($journal_auth->{associations});
        foreach my $association ( @{ $journal_auth->{associations} } ) {
            my $association_id = CJDB::DB::Associations->find_or_create({
               association        => $association,
               search_association => CUFTS::CJDB::Util::strip_title($association),
            })->id;

            CJDB::DB::JournalsAssociations->create({
                journal     => $journal_auth->{cjdb_id},
                association => $association_id,
                site        => $site_id,
            });
        }
    }

    $logger->info('Done attaching associations: ', format_duration(time-$start_time));
}


# Dedupe subjects and store.
sub store_subjects {
    my ( $logger, $journal_auths, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching subjects.');

    foreach my $journal_auth ( values %$journal_auths ) {
        next if !defined($journal_auth->{subjects});
        foreach my $subject ( uniq @{ $journal_auth->{subjects} } ) {
            my $subject_id = CJDB::DB::Subjects->find_or_create({
               subject        => $subject,
               search_subject => CUFTS::CJDB::Util::strip_title($subject),
            })->id;

            CJDB::DB::JournalsSubjects->create({
                journal => $journal_auth->{cjdb_id},
                subject => $subject_id,
                site    => $site_id,
            });
        }
    }

    $logger->info('Done attaching subjects: ', format_duration(time-$start_time));
}

# Store relations.
sub store_relations {
    my ( $logger, $journal_auths, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching relations.');

    JOURNALAUTH:
    foreach my $journal_auth ( values %$journal_auths ) {
        next if !defined($journal_auth->{relations});
        RELATION:
        foreach my $relation ( @{ $journal_auth->{relations} } ) {
            next RELATION if !hascontent($relation->{title});
            CJDB::DB::Relations->find_or_create({
                journal  => $journal_auth->{cjdb_id},
                site     => $site_id,
                relation => $relation->{relation},
                title    => $relation->{title},
                issn     => $relation->{issn},
            });
        }
    }

    $logger->info('Done attaching relations: ', format_duration(time-$start_time));
}



sub store_resource_names {
    my ( $logger, $journal_auths, $links, $resource_names, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching resource names.');

    my %resource_map;
    while ( my ($resource_id, $resource_name) = each %$resource_names ) {
        $resource_map{$resource_id} = CJDB::DB::Associations->find_or_create({
           association        => $resource_name,
           search_association => CUFTS::CJDB::Util::strip_title($resource_name),
        })->id;
    }

    while ( my ($journal_auth_id, $journal_auth) = each %$journal_auths ) {
        my $cjdb_id = $journal_auth->{cjdb_id};
        my @resource_ids = map { $resource_map{ $_->{resource_id} } } @{ $links->{$journal_auth_id} };

        foreach my $resource_id (uniq @resource_ids) {
            next if !$resource_id;
            CJDB::DB::JournalsAssociations->find_or_create({
                association  => $resource_id,
                site         => $site_id,
                journal      => $cjdb_id,
            });
        }
    }
    
    $logger->info('Done attaching resource names:', format_duration(time-$start_time));
}

sub store_links {
    my ( $logger, $journal_auths, $links, $resource_names, $site_id ) = @_;

    my $start_time = time;
    $logger->info('Attaching links.');

    while ( my ($journal_auth_id, $ja_links) = each %$links ) {
        my $journal_auth = $journal_auths->{$journal_auth_id};
        my $cjdb_id = $journal_auth->{cjdb_id};

        # This has more copying of data than is really necessary, but it
        # makes the temporary hashes that are built more sane - "resource_id" instead of "resource"
        foreach my $link (@$ja_links) {
            foreach my $url ( @{$link->{urls}} ) {
                my $new_link = {
                    resource            => $link->{resource_id},
                    journal             => $cjdb_id,
                    link_type           => $url->[0],
                    URL                 => $url->[1],
                    site                => $site_id,
                    rank                => $link->{rank},
                    local_journal       => $link->{local_journal_id},
                    fulltext_coverage   => $link->{fulltext_coverage},
                    citation_coverage   => $link->{citation_coverage},
                    print_coverage      => $link->{print_coverage},
                    embargo             => $link->{embargo},
                    current             => $link->{current},
                };
                CJDB::DB::Links->create($new_link);
            }
        }
    }
    
    $logger->info('Done attaching links: ', format_duration(time-$start_time));
}


##
## Format coverage statements
##

sub get_coverage {
    my ( $local_journal, $resource_id, $rank, $site_id, $show_citations ) = @_;

    my $new_link = {
        resource_id      => $resource_id,
        rank             => $rank,
        local_journal_id => $local_journal->id,
    };

    my $ft_coverage = get_cufts_ft_coverage($local_journal);
    defined($ft_coverage)
        and $new_link->{fulltext_coverage} = $ft_coverage;

    if ( $show_citations ) {
        my $cit_coverage = get_cufts_cit_coverage($local_journal);
        $new_link->{citation_coverage} = $cit_coverage if defined($cit_coverage);
    }

    if ( hascontent($local_journal->embargo_days) && $local_journal->embargo_days ) {
        $new_link->{embargo} = $local_journal->embargo_days . ' days';
    }

    if ( hascontent($local_journal->embargo_months) && $local_journal->embargo_months ) {
        $new_link->{embargo} = $local_journal->embargo_months . ' months';
    }

    if ( hascontent($local_journal->current_months) && $local_journal->current_months ) {
        $new_link->{current} = $local_journal->current_months . ' months';
    }
    elsif ( hascontent($local_journal->current_years) && $local_journal->current_years ) {
        $new_link->{current} = $local_journal->current_years . ' years';
    }

    # Skip if citations are turned off and we have no fulltext coverage data

    if ( !hascontent($new_link->{fulltext_coverage}) && !hascontent($new_link->{embargo}) && !hascontent($new_link->{current})
         && ( !$show_citations || !hascontent($new_link->{citation_coverage}) ) ) {
        # warn("Skipping journal '", $local_journal->title, "' due to no fulltext coverage information.\n");
        return undef;
    }

    return $new_link;
}


sub get_cufts_ft_coverage {
    my ($local_journal) = @_;

    if ( hascontent($local_journal->coverage) ) {
        return $local_journal->coverage;
    }

    my $ft_coverage;

    if ( defined( $local_journal->ft_start_date ) || defined( $local_journal->ft_end_date ) ) {
        $ft_coverage = format_date_vol_iss( $local_journal->ft_start_date, $local_journal->vol_ft_start, $local_journal->iss_ft_start );
        $ft_coverage .= ' - ';

        my $end_date = $local_journal->ft_end_date;
        $end_date =~ s/\-//g;
    
        if ( $end_date <= get_current_date() ) {
            $ft_coverage .= format_date_vol_iss( $local_journal->ft_end_date, $local_journal->vol_ft_end, $local_journal->iss_ft_end );
        }
    }

    return $ft_coverage;
}

sub get_cufts_cit_coverage {
    my ($local_journal) = @_;

    my $cit_coverage;

    if ( defined( $local_journal->cit_start_date ) || defined( $local_journal->cit_end_date ) ) {
        $cit_coverage = format_date_vol_iss( $local_journal->cit_start_date, $local_journal->vol_cit_start, $local_journal->iss_cit_start );
        $cit_coverage .= ' - ';

        my $end_date = $local_journal->cit_end_date;
        $end_date =~ s/\-//g;
    
        if ( $end_date <= get_current_date() ) {
            $cit_coverage .= format_date_vol_iss( $local_journal->cit_end_date, $local_journal->vol_cit_end, $local_journal->iss_cit_end );
        }
    }

    return $cit_coverage;
}

##
## Create fulltext links
##

sub get_ft_urls {
    my ( $local_journal, $resource, $site, $module ) = @_;

    my $request = new CUFTS::Request;
    $request->title( $local_journal->title );
    $request->genre('journal');
    $request->pid({});

    my @urls;

    if ( $module->can_getJournal($request) ) {
        my $results = $module->build_linkJournal( [$local_journal], $resource, $site, $request );
        foreach my $result (@$results) {
            $module->prepend_proxy( $result, $resource, $site, $request );
            push @urls, [ 1, $result->url ];
        }
    }

    if ( !scalar(@urls) && $module->can_getDatabase($request) ) {
        my $results = $module->build_linkDatabase( [$local_journal], $resource, $site, $request );
        foreach my $result (@$results) {
            $module->prepend_proxy( $result, $resource, $site, $request );
            push @urls, [ 2, $result->url ];
        }
    }
    
    return \@urls;
}


##
## Various utility functions
##


# NOTE: This uses a global date computed once to avoid recomputing it thousands of times.
sub get_current_date {
    if ( !defined($global_current_date) ) {
        my ( $day, $mon, $year ) = (localtime())[3..5];
        $global_current_date = sprintf( "%04i%02i%02i", $year + 1900, $mon + 1, $day );
    }
    return $global_current_date;
}

# Format a date, volume, and issue into a consistent format for a holdings statement: YYYY-MM-DD (v.1 i.2)
sub format_date_vol_iss {
    my ( $date, $vol, $iss ) = @_;
    
    my $string = $date;

    if ( hascontent($vol) || hascontent($iss) ) {
        $string .= ' (';
        $string .= "v.$vol" if hascontent($vol);
        $string .= ' ' if hascontent($vol) && hascontent($iss);
        $string .= "i.$iss" if hascontent($iss);
        $string .= ')';
    }

    return $string;
}


# Clears all the CJDB tables in anticipation of reloading them.  Should be done in a transaction so it can be
# rolled back if necessary.
sub clear_site {
    my ($logger, $site_id) = @_;

    defined($site_id) && $site_id ne '' && int($site_id) > 0
        or die("Site id not properly defined in clear_site: $site_id");

    $site_id = int($site_id);

    # Make raw database calls to speed up this process.  Since we're deleting
    # everything for a site from all tables, we don't need Class::DBI triggers
    # being called.

    $logger->info('Deleting existing CJDB data for site.');
    my $dbh = CJDB::DB::DBI->db_Main;
    foreach my $table ( qw(cjdb_journals_associations cjdb_journals cjdb_links cjdb_journals_subjects cjdb_journals_titles cjdb_issns cjdb_relations) ) {
        $logger->trace("Deleting from table $table");
        $dbh->do("DELETE FROM $table WHERE site=$site_id");
    }
    $logger->info('Existing CJDB data deleted.');

    return 1;
}

# Calls an external script to link/build journal auth records for site's local resources
sub build_local_journal_auths {
    my $site = shift;
    my $site_id = $site->id;
    # No catch here, building journal auths should not be fatal.
    eval { `perl util/build_journals_auth.pl --site_id=${site_id} --local`; };
}


# This returns an array ref consisting of a cleaned and stripped title ready for
# saving as a CJDBTitles record.
sub get_processed_titles {
    my ( $title ) = @_;
    
    $title = CUFTS::CJDB::Util::strip_articles( trim($title) );

    # Remove trailing (...)  eg. (Toronto, ON) and [...] eg. [electronic resource]

    $title =~ s/ \( .+? \)  \s* \.? \s* $//xsm;
    $title =~ s/ \[ .+? \]  \s* \.? \s* $//xsm;

    my $stripped_title = CUFTS::CJDB::Util::strip_title($title);

    # Exit if we have an empty title, or the title is too long

    return undef if    !hascontent($title)
                    || !hascontent($stripped_title)
                    || length($title) > 1024;

    # Skip alternate titles that match common single words
    # like "Journal" and "Review".

    return undef if any { $stripped_title eq $_ } ( 'review', 'journal', 'proceedings' );

    return [ $stripped_title, $title ];
}

# Format the rebuild time into a readable string
sub format_duration {
    my ( $seconds ) = @_;
    
    my $hours = int($seconds / 3600);
    $seconds -= $hours * 3600;
    my $minutes = int($seconds / 60);
    $seconds = $seconds % 60;
    
    return sprintf( "%i:%02i:%02i", $hours, $minutes, $seconds );
}

##
## Custom loading module utilities
##

sub load_print_module {
    my ( $logger, $site ) = @_;
    my $site_key = $site->key;

    my $module_name = 'CUFTS::CJDB::Loader::MARC::';
    if ( defined($site_key) ) {
        $module_name .= $site_key;
    }
    else {
        die("Unable to determine module name");
    }

    eval "require $module_name";
    if ($@) {
        die("Unable to require $module_name: $@");
    }

    my $module = $module_name->new;
    defined($module)
        or die("Failed to create new loading object from module: $module_name");

    return $module;
}


##
## MARC dump file building
##

sub build_dump {
    my ( $logger, $site, $MARC_cache ) = @_;

    $logger->info('Starting MARC dump.');
    my $start_time = time;

    my $site_id = $site->id;
    
    my $loader = load_print_module( $logger, $site );
    $loader->site_id( $site_id );

    # Set up site variables so we don't have to (expensively) retrieve them from the site object in a tight loop

    my $site_cjdb_display_db_name_only          = $site->cjdb_display_db_name_only;
    my $site_marc_dump_holdings_field           = $site->marc_dump_holdings_field;
    my $site_marc_dump_holdings_subfield        = $site->marc_dump_holdings_subfield;
    my $site_marc_dump_holdings_indicator1      = $site->marc_dump_holdings_indicator1;
    my $site_marc_dump_holdings_indicator2      = $site->marc_dump_holdings_indicator2;
    my $site_marc_dump_856_link_label           = $site->marc_dump_856_link_label;
    my $site_marc_dump_direct_links             = $site->marc_dump_direct_links;
    my $site_marc_dump_duplicate_title_field    = $site->marc_dump_duplicate_title_field;
    my $site_marc_dump_medium_text              = $site->marc_dump_medium_text;
    my $site_marc_dump_cjdb_id_field            = $site->marc_dump_cjdb_id_field;
    my $site_marc_dump_cjdb_id_subfield         = $site->marc_dump_cjdb_id_subfield;
    my $site_marc_dump_cjdb_id_indicator1       = $site->marc_dump_cjdb_id_indicator1;
    my $site_marc_dump_cjdb_id_indicator2       = $site->marc_dump_cjdb_id_indicator2;
    
    
    # Make sure the site is set up correctly for dumping MARC data.
    # If not, we can exit out early.
    
    if ( !hascontent($site_marc_dump_holdings_field) || !hascontent($site_marc_dump_holdings_subfield) ) {
        $logger->info('Site does not have MARC dump holdings fields configured.');
        return undef;
    }

    my ( $sec, $min, $hour, $day, $mon, $year ) = localtime();
    my $datestamp = sprintf( '%04i%02i%02i%02i%02i%02i.0', $year + 1900, $mon + 1, $day, $hour, $min, $sec );

    my $base_url = $CUFTS::Config::CJDB_URL;
    if ( $base_url !~ m{/$} ) {
        $base_url .= '/';
    }
    $base_url .= $site->key . '/journal/';

    # Cache resource information
    
    my %resources_display;
    my $resources_iter = CUFTS::DB::LocalResources->search({ site => $site_id });

    while ( my $resource = $resources_iter->next ) {
        my $resource_id     = $resource->id;
        my $global_resource = $resource->resource;

        $resources_display{$resource_id}->{name} =   hascontent($resource->name)  ? $resource->name
                                                   : defined($global_resource)    ? $global_resource->name
                                                   : '';
                                                   
        if ( !$site_cjdb_display_db_name_only ) {
            my $provider =   hascontent($resource->provider) ? $resource->provider
                           : defined($global_resource)       ? $global_resource->provider
                           : '';
            $resources_display{$resource_id}->{name} .= " - $provider";
        }
    }

    my $dir = create_dump_dir($logger, $site_id);

    # Open log files

    open MARC_OUTPUT,  ">$dir/marc_dump.mrc" or
        die("Unable to open MARC dump file for MARC: $!");
        
    open ASCII_OUTPUT, ">$dir/marc_dump.txt" or
        die("Unable to open MARC dump file for text: $!");


    my $cjdb_record_iter = CJDB::DB::Journals->search( site => $site_id );

CJDB_RECORD:
    while ( my $cjdb_record = $cjdb_record_iter->next ) {
        my $journals_auth_id = $cjdb_record->journals_auth->id;


        my $MARC_record;
        if ( defined( $MARC_cache->{$journals_auth_id}->{MARC} ) ) {
            if ( !$loader->preserve_print_MARC ) {
                $MARC_record = strip_print_MARC( $logger, $site, $MARC_cache->{$journals_auth_id}->{MARC} );
            }
            else {
                $MARC_record = $MARC_cache->{$journals_auth_id}->{MARC};
            }
        }
        elsif ( defined($cjdb_record->journals_auth->MARC) ) {
            $MARC_record = $cjdb_record->journals_auth->marc_object;
            $MARC_record->leader('00000nas  22001577a 4500');
        }
        else {
            $MARC_record = create_brief_MARC( $logger, $site, $cjdb_record->journals_auth );
        }

        # Add holdings statements, skip if no electronic so we don't duplicate print only journals uselessly

        my $has_holdings = 0;
        HOLDINGS:
        foreach my $link ( $cjdb_record->links ) {

            my $holdings;

            if ( hascontent($link->print_coverage) && $loader->export_print_holdings ) {
                $holdings = "Available in print: " . $link->print_coverage;
            }
            elsif ( hascontent( $link->fulltext_coverage )
                 || hascontent( $link->embargo )
                 || hascontent( $link->current ) ) {

                $holdings = "Available full text from " . ( $resources_display{$link->resource}->{name} || 'Unknown resource' ) . ':';

                if ( hascontent( $link->fulltext_coverage ) ) {
                    $holdings .= ' ' . $link->fulltext_coverage;
                }
                if ( hascontent( $link->embargo ) ) {
                    $holdings .= ' '. $link->embargo . ' embargo';
                }
                if ( hascontent( $link->current ) ) {
                    $holdings .= ' most recent '. $link->current;
                }
            }
            else {
                next HOLDINGS;
            }
            
            my $holdings_field = MARC::Field->new(
                $site_marc_dump_holdings_field,
                $site_marc_dump_holdings_indicator1,
                $site_marc_dump_holdings_indicator2,
                $site_marc_dump_holdings_subfield => latin1_to_marc8($logger, $holdings)
            );
            $MARC_record->append_fields( $holdings_field );

            $has_holdings = 1;

        }
        
        if ( !$has_holdings ) {
            $logger->debug("Skipping MARC dump of record due to missing holdings.");
            next CJDB_RECORD;
        }

        if ( !defined($MARC_record) ) {
            $logger->debug("Unable to create MARC record.");
            next CJDB_RECORD;
        }
        
        # Add 005 field

        my $existing_005 = $MARC_record->field('005');
        if ( defined($existing_005) ) {
                $MARC_record->delete_field( $existing_005 );
        }
        $MARC_record->append_fields(
                MARC::Field->new( '005', $datestamp )
        );
        
        # Add 856 link(s)
        
        if ( $site_marc_dump_direct_links ) {
            foreach my $link ( $cjdb_record->links ) {
                next if !hascontent( $link->fulltext_coverage )
                     && !hascontent( $link->embargo )
                     && !hascontent( $link->current );

                next if hascontent( $link->print_coverage );

                my $resource_name = $resources_display{$link->resource}->{name} || 'Unknown resource';

                my $field_856 = MARC::Field->new( '856', '4', '0', 'u' => $link->URL, 'z' => latin1_to_marc8($logger, $resource_name) );
                $MARC_record->append_fields( $field_856 );
            
            }
        }
        else {
            my $field_856 = MARC::Field->new( '856', '4', '0', 'u' => $base_url . $journals_auth_id );
            if ( hascontent($site_marc_dump_856_link_label) ) {
                $field_856->add_subfields( 'z' => latin1_to_marc8($logger, $site_marc_dump_856_link_label) );
            }
            $MARC_record->append_fields( $field_856 );
        }


        # Add medium to title fields

        if ( hascontent($site_marc_dump_medium_text) ) {
            foreach my $field_num ( '245', '246' ) {
                my @title_fields = $MARC_record->field( $field_num );
                foreach my $title_field ( @title_fields ) {
                    $title_field->delete_subfield( code => 'h' );
                    $title_field->add_subfields( 'h', latin1_to_marc8($logger, $site_marc_dump_medium_text) );
                }
            }
        }


        # Clone the title fields if necessary (for journal title indexing)
        
        if ( hascontent($site_marc_dump_duplicate_title_field) ) {
            foreach my $field_num ( '245', '246', '210' ) {
                my @title_fields = $MARC_record->field( $field_num );
                foreach my $title_field ( @title_fields ) {
                    my @subfields = map { @{ $_ } } $title_field->subfields;  # Flatten subfields
                    my $new_field = MARC::Field->new( $site_marc_dump_duplicate_title_field, $title_field->indicator(1), $title_field->indicator(2), @subfields );
                    $MARC_record->append_fields( $new_field );
                }
            }
        }
        
        # Add CJDB identifier if defined
        
        if ( hascontent($site_marc_dump_cjdb_id_field) && hascontent($site_marc_dump_cjdb_id_subfield) ) {
            my $identifier_field = MARC::Field->new( 
                $site_marc_dump_cjdb_id_field,
                $site_marc_dump_cjdb_id_indicator1,
                $site_marc_dump_cjdb_id_indicator2,
                $site_marc_dump_cjdb_id_subfield => 'CJDB' . $journals_auth_id
            );
            $MARC_record->append_fields( $identifier_field );
        }
        
        print MARC_OUTPUT  $MARC_record->as_usmarc();
        print ASCII_OUTPUT $MARC_record->as_formatted(), "\n\n";
    }
    
    close(MARC_OUTPUT );
    close(ASCII_OUTPUT);

    $logger->info('Finished MARC dump: ', format_duration(time-$start_time));

    return 1;
}



sub strip_print_MARC {
    my ( $logger, $site, $MARC_record ) = @_;
    
    my $new_MARC_record = MARC::Record->new();
    $new_MARC_record->leader('00000nas  22001577a 4500');
    
    my @keep_fields = qw(
        022
        050
        055
        110
        210
        245
        246
        260
        310
        321
        362
        6..
        710
        780
        785
    );

    foreach my $keep_field (@keep_fields) {
        my @fields = $MARC_record->field($keep_field);
        next if !scalar(@fields);
        $new_MARC_record->append_fields(@fields);
    }
    
    return $new_MARC_record;
}


sub create_brief_MARC {
    my ( $logger, $site, $journals_auth ) = @_;

    my %seen;
    my $MARC_record = MARC::Record->new();

    $MARC_record->leader('00000nas  22001577a 4500');

    # ISSNs

    foreach my $issn ( map {$_->issn_dash} $journals_auth->issns ) {
        $MARC_record->append_fields( MARC::Field->new( '022', '#', '#', 'a' => $issn ) );
    }

    # Title

    my $title = $journals_auth->title;
    $seen{title}{ lc($title) }++;
    my $article_count = CUFTS::CJDB::Util::count_articles($title);
    $MARC_record->append_fields( MARC::Field->new( '245', '0', $article_count, 'a' => latin1_to_marc8($title) ) );

    # Alternate titles

    foreach my $title_field ($journals_auth->titles) {
        next if $seen{title}{ lc($title_field->title) }++;
        $MARC_record->append_fields( MARC::Field->new( '246', '0', '#', 'a' => latin1_to_marc8($title_field->title) ) );
    }
    
    return $MARC_record;
}

sub latin1_to_marc8 {
    my ( $logger, $string ) = @_;
    
    return '' if !hascontent($string);
    
    my $output;
    eval {
        $output = CUFTS::CJDB::Util::latin1_to_marc8($string);
    };
    if ( $@ ) {
        $logger->debug("Error processing marc8 conversion for: $string\nERROR: $@");
        return $string;
    }

    return $output;
}


sub create_dump_dir {
    my ( $logger, $site_id ) = @_;

    my $dir = $CUFTS::Config::CJDB_SITE_TEMPLATE_DIR;

    -d $dir
        or die("No directory for the CUFTS CJDB site files: $dir");

    $dir .= '/' . $site_id;
    -d $dir
        or mkdir $dir
            or die("Unable to create directory $dir: $!");

    $dir .= '/static';
    -d $dir
        or mkdir $dir
            or die("Unable to create directory $dir: $!");

    return $dir;
}