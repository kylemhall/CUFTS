#!/usr/local/bin/perl

##
## This script checks all CUFTS sites for files that are
## marked for reloading and then loads the print/CUFTS records
## if required.
##

use Data::Dumper;

use lib qw(lib);

use CUFTS::Exceptions;
use CUFTS::Config;
use CUFTS::CJDB::Util;

use CJDB::DB::DBI;
use CUFTS::DB::DBI;

use CUFTS::DB::Sites;
use CUFTS::DB::Resources;
use CUFTS::DB::Journals;
use CUFTS::DB::JournalsActive;
use CUFTS::DB::Stats;

use CJDB::DB::Journals;

use MARC::File;
use MARC::File::USMARC;
use MARC::Record;

use CUFTS::CJDB::Util;
use CUFTS::CJDB::Loader::MARC::MARCStore;

use CUFTS::Resolve;

use Getopt::Long;

use strict;

my %options;
GetOptions(\%options, 'site_key=s', 'site_id=i', 'append', 'module=s', 'print_only', 'cufts_only');
my @files = @ARGV;

if ($options{site_key} || $options{site_id}) {
    my $site = get_site();
    load_site($site, @files);
} else {
    load_all_sites();
}

sub load_all_sites {
    my $site_iter = CUFTS::DB::Sites->retrieve_all;

SITE:
    while (my $site = $site_iter->next) {
    	my $site_id = $site->id;	

    	print "Checking " . $site->name . "\n";

    	next if    ( !defined($site->rebuild_cjdb) || $site->rebuild_cjdb eq '' )
    	        && ( !defined($site->rebuild_ejournals_only) || $site->rebuild_ejournals_only ne '1' );

    	print " * Found files marked for rebuild.\n";
	
    	# First load any LCC subject files.

    	if (-e "${CUFTS::Config::CJDB_SITE_DATA_DIR}/${site_id}/lccn_subjects") {
            # eval this, since it shouldn't be fatal if this fails.
        
            eval {
    		    `util/load_lcc_subjects.pl --site_id=${site_id}  ${CUFTS::Config::CJDB_SITE_DATA_DIR}/${site_id}/lccn_subjects`;
    		    `util/create_subject_browse.pl --site_id=${site_id}`;
    		}
    	}

        # eval this, since it shouldn't be fatal if this fails.
    
        eval {
		    `util/build_journals_auth.pl --site_id=${site_id} --local`;
		};

        clear_site($site_id);
        if (!$options{cufts_only}) {
        	my @files = split /\|/, $site->rebuild_cjdb;
            foreach my $file (@files) {
        		$file = $CUFTS::Config::CJDB_SITE_DATA_DIR . '/' . $site_id . '/' .$file;
        	}
            eval {
                load_print($site, \@files);
            };
            if ($@) {
                    print("* Error found while loading print records.  Skipping remaining processing for this site.\n");
                    CUFTS::DB::DBI->dbi_rollback;
                    CJDB::DB::DBI->dbi_rollback;
                    next SITE;
            }
        }
			
        if (!$options{print_only}) {
    		print " * Loading CUFTS journals records\n";
            eval {
                load_cufts($site);
            };
            if ($@) {
                    print("* Error found while loading CUFTS records.  Skipping remaining processing for this site.\n");
                    CUFTS::DB::DBI->dbi_rollback;
                    CJDB::DB::DBI->dbi_rollback;
                    next SITE;
            }
        }

    	$site->rebuild_cjdb(undef);
    	$site->rebuild_ejournals_only(undef);
    	$site->update;
    	CUFTS::DB::DBI->dbi_commit;
    	CJDB::DB::DBI->dbi_commit;

    	print "Finished ", $site->name,  "\n";
    }	
}

sub load_site {
    my ($site, @files) = @_;

	my $site_id = $site->id;	

    clear_site($site_id);
    if (!$options{cufts_only}) {
		print " * Loading print journals records\n";
        load_print($site, \@files);
    }
			
    if (!$options{print_only}) {
		print " * Loading CUFTS journals records\n";
        load_cufts($site);
    }

	CUFTS::DB::DBI->dbi_commit;
	CJDB::DB::DBI->dbi_commit;

    return 1;
}


sub load_print {
    my ($site, $files) = @_;
    # Some loaders might need a first pass at the data to do thing like combine
    # holdings records with bib records.  This returns a new list of processed
    # files (probably "tmp" files now) or the original list if no pre-processing
    # was done.

    my $loader = load_print_module($site);
    $loader->site_id($site->id);
    my @files = $loader->pre_process(@$files);

    # Do a first pass at loading.  If we're merging on ISSN, we have to do two passes, one
    # on records with multiple ISSNs, and then a second pass on records with only one
    # ISSN.  This avoids having multiple single ISSN records that would have to be merged
    # later.

    my $batch = $loader->get_batch(@files);
    $batch->strict_off;

    while (my $record = $batch->next()) {
    	next if $loader->skip_record($record);

    	if ($loader->merge_by_issns) {
    		my @issns = $loader->get_issns($record);
    		next unless scalar(@issns) > 1;
    	}

    	process_print_record($record, $loader);
    }

    # Second pass if we're merging

    if ($loader->merge_by_issns) {
    	$batch = $loader->get_batch(@files);
    	$batch->strict_off;

    	while (my $record = $batch->next()) {
    	    next if $loader->skip_record($record);

    		process_print_record($record, $loader);
        }
    }
}


sub load_print_module {
	my ($site) = @_;
	my $site_key = $site->key;

	my $module_name = 'CUFTS::CJDB::Loader::MARC::';
	if ($options{'module'}) {
		$module_name .= $options{'module'};
	} elsif (defined($site_key)) {
		$module_name .= $site_key;
	} else {
		die("Unable to determine module name");
	}

	eval "require $module_name";
	if ($@) {
		die("Unable to require $module_name: $@");
	}
	
	my $module = $module_name->new;
	defined($module) or
		die("Failed to create new loading object from module: $module_name");
		
	return $module;
}


sub process_print_record {
	my ($record, $loader) = @_;

	my $journal = $loader->load_journal($record);
	return if !defined($journal);
	
	$loader->load_titles($record, $journal);

	$loader->load_MARC_subjects($record, $journal);

	$loader->load_LCC_subjects($record, $journal);
		
	$loader->load_associations($record, $journal);

	$loader->load_relations($record, $journal);

	$loader->load_link($record, $journal);
}	


sub load_cufts {
	my ($site) = @_;

	my $local_resources_iter = CUFTS::DB::LocalResources->search('active' => 'true', 'site' => $site->id);

	while (my $local_resource = $local_resources_iter->next) {
		if (defined($local_resource->resource) and !$local_resource->resource->active) {
			next;
		}

		CUFTS::Resolve->overlay_global_resource_data($local_resource);
		next unless defined($local_resource->module);
		
		my $module = CUFTS::Resolve::__module_name($local_resource->module);
		CUFTS::Resolve->__require($module);

		my $journals_iter = CUFTS::DB::LocalJournals->search('resource' => $local_resource->id, 'active' => 'true');
		while (my $local_journal = $journals_iter->next) {

			$local_journal = $module->overlay_global_title_data($local_journal);
			my $journal_auth = $local_journal->journal_auth;
			unless (defined($journal_auth)) {
				print "Skipping journal '", $local_journal->title, "' due to missing journal_auth record.\n";
				next;
			}

			my $new_link = {
				resource      => $local_resource->id,
				rank          => $local_resource->rank,
				site          => $site->id,
				local_journal => $local_journal->id,
			};
			
			my $ft_coverage = get_cufts_ft_coverage($local_journal);
			defined($ft_coverage) and
				$new_link->{'fulltext_coverage'} = $ft_coverage;
					
			my $cit_coverage = get_cufts_cit_coverage($local_journal);
			defined($cit_coverage) and
				$new_link->{'citation_coverage'} = $cit_coverage;

			if (defined($local_journal->embargo_days)) {
				$new_link->{'embargo'} = $local_journal->embargo_days . ' days';
			}

			if (defined($local_journal->embargo_months)) {
				$new_link->{'embargo'} = $local_journal->embargo_months . ' months';
			}

			# Skip if citations are turned off and we have no fulltext coverage data
				
			next if !defined($new_link->{'fulltext_coverage'}) && !$site->cjdb_show_citations;

			##
			## Create a request object and use the resolver to create journal/database level links
			##

			my $request = new CUFTS::Request;
			$request->title($local_journal->title);
			$request->genre('journal');
			$request->pid({});

			my @links;
			if ( $module->can_getJournal($request) ) {
					
				my $results = $module->build_linkJournal([$local_journal], $local_resource, $site, $request);
				foreach my $result (@$results) {
					$module->prepend_proxy($result, $local_resource, $site, $request);
					$new_link->{URL} = $result->url;
					$new_link->{link_type} = 1;
					my %temp_hash = %{$new_link};
					push @links, \%temp_hash;
				}

			}
			elsif ( $module->can_getDatabase($request) ) {

				my $results = $module->build_linkDatabase([$local_journal], $local_resource, $site, $request);
				foreach my $result (@$results) {
					$module->prepend_proxy($result, $local_resource, $site, $request);
					$new_link->{'URL'} = $result->url;
					$new_link->{'link_label'} = 'Link to journal';
					$new_link->{link_type} = 2;
					my %temp_hash = %{$new_link};
					push @links, \%temp_hash;
				}

			}
				
			if (scalar(@links) > 0) {
		
				my @CJDB_records = CJDB::DB::Journals->search(journals_auth => $journal_auth->id, site => $site->id);
	
				if (scalar(@CJDB_records) == 0) {
					my $record = get_MARC_data($site, $journal_auth);
					defined($record) and
						push @CJDB_records, $record;
				}

				if (scalar(@CJDB_records) == 0) {
					my $record = build_basic_record($site, $journal_auth);
					defined($record) and
						push @CJDB_records, $record;
				}

				foreach my $CJDB_record (@CJDB_records) {
					foreach my $link (@links) {
						# Add resource name as an association
							
						my %temp_link = %{$link};  # Grab a copy because we edit it, but it may be reused if there's multiple CJDB records
						
						CJDB::DB::Associations->find_or_create({
							'journal'            => $CJDB_record->id,
							'association'        => $local_resource->name,
							'search_association' => CUFTS::CJDB::Util::strip_title($local_resource->name),
							'site'               => $site->id,
						});
					
						# Create links

						$temp_link{'journal'} = $CJDB_record->id;
						CJDB::DB::Links->create(\%temp_link);
					}
				}
			}
		}
	}
	
	CJDB::DB::DBI->dbi_commit;
}

sub get_cufts_ft_coverage {
	my ($local_journal) = @_;
	
	my $ft_coverage;
	
	if (defined($local_journal->ft_start_date) || defined($local_journal->ft_end_date)) {
		$ft_coverage = $local_journal->ft_start_date;
		if (defined($local_journal->vol_ft_start) || defined($local_journal->iss_ft_start)) {
			$ft_coverage .= ' (';
			defined($local_journal->vol_ft_start) and
				$ft_coverage .= 'v.' . $local_journal->vol_ft_start;
			if (defined($local_journal->iss_ft_start)) {
				defined($local_journal->vol_ft_start) and
					$ft_coverage .= ' ';
				$ft_coverage .= 'i.' . $local_journal->iss_ft_start;
			}
			$ft_coverage .= ')';
		}

		$ft_coverage .= ' - ';
		$ft_coverage .= $local_journal->ft_end_date;

		if (defined($local_journal->vol_ft_end) || defined($local_journal->iss_ft_end)) {
			$ft_coverage .= ' (';
			defined($local_journal->vol_ft_end) and
				$ft_coverage .= 'v.' . $local_journal->vol_ft_end;
			if (defined($local_journal->iss_ft_end)) {
				defined($local_journal->vol_ft_end) and
					$ft_coverage .= ' ';
				$ft_coverage .= 'i.' . $local_journal->iss_ft_end;
			}
			$ft_coverage .= ')';
		}
	}
	
	return $ft_coverage;
}
	
sub get_cufts_cit_coverage {
	my ($local_journal) = @_;
	
	my $cit_coverage;

	if (defined($local_journal->cit_start_date) || defined($local_journal->cit_end_date)) {
		$cit_coverage = $local_journal->cit_start_date;
		if (defined($local_journal->vol_cit_start) || defined($local_journal->iss_cit_start)) {
			$cit_coverage .= ' (';
			defined($local_journal->vol_cit_start) and
				$cit_coverage .= 'v.' . $local_journal->vol_cit_start;
			if (defined($local_journal->iss_cit_start)) {
				defined($local_journal->vol_cit_start) and
					$cit_coverage .= ' ';
				$cit_coverage .= 'i.' . $local_journal->iss_cit_start;
			}
			$cit_coverage .= ')';

		}
						
		$cit_coverage .= ' - ';
		$cit_coverage .= $local_journal->cit_end_date;
						
		if (defined($local_journal->vol_cit_end) || defined($local_journal->iss_cit_end)) {
			$cit_coverage .= ' (';
			defined($local_journal->vol_cit_end) and
				$cit_coverage .= 'v.' . $local_journal->vol_cit_end;
			if (defined($local_journal->iss_cit_end)) {
				defined($local_journal->vol_cit_end) and
					$cit_coverage .= ' ';
				$cit_coverage .= 'i.' . $local_journal->iss_cit_end;
			}
			$cit_coverage .= ')';
		}
	}
	
	return $cit_coverage;
}


sub strip_title {
	my ($string) = @_;
	
	return CUFTS::CJDB::Util::strip_title($string);
}


sub build_basic_record {
	my ($site, $journal_auth) = @_;
	
	my $record = {};
	

	my $title = $journal_auth->title;

	my $sort_title = $title;
	$sort_title = CUFTS::CJDB::Util::strip_articles($sort_title);

	my $stripped_sort_title = strip_title($sort_title);

	$record->{'title'} = $title;
	$record->{'sort_title'} = $sort_title;
	$record->{'stripped_sort_title'} = $stripped_sort_title;
	$record->{'site'} = $site->id;
	$record->{'journals_auth'} = $journal_auth->id;
	
	my $journal = CJDB::DB::Journals->create($record);
	my $journal_id = $journal->id;

	CJDB::DB::Titles->create({
		'journal' => $journal_id,
		'site' => $site->id,
		'search_title' => $stripped_sort_title,
		'title' => $sort_title,
		'main' => 1,
	});
	
	my @issns = $journal_auth->issns;
	foreach my $issn (@issns) {
		CJDB::DB::ISSNs->find_or_create({
			'journal' => $journal_id,
			'issn' => $issn->issn,
			'site' => $site->id,
		});
	}
	
	return $journal;
}

sub get_MARC_data {
	my ($site, $journal_auth) = @_;

	defined($journal_auth->MARC) or
		return undef;
	my $record = MARC::File::USMARC::decode($journal_auth->MARC);


	my $loader = CUFTS::CJDB::Loader::MARC::MARCStore->new();
	$loader->site_id($site->id);

	my $journal = $loader->load_journal($record, $journal_auth->id);
	defined($journal) or 
		next;
	
	$loader->load_titles($record, $journal);
	
	$loader->load_MARC_subjects($record, $journal);

	$loader->load_LCC_subjects($record, $journal);

	$loader->load_associations($record, $journal);

	$loader->load_relations($record, $journal);

	CJDB::DB::DBI->dbi_commit;

	return $journal;
}

sub get_site {
	defined($options{'site_id'}) and
		return CUFTS::DB::Sites->retrieve(int($options{'site_id'}));

	my @sites = CUFTS::DB::Sites->search('key' => $options{'site_key'});
	
	scalar(@sites) == 1 or
		die('Could not get CUFTS site for key: ' . $options{'site_key'});
		
	return $sites[0];
}


sub clear_site {
	my ($site_id) = @_;

    return 0 if $options{append};

	defined($site_id) && $site_id ne '' && int($site_id) > 0 or
		die("Site id not properly defined in clear_site: $site_id");

	$site_id = int($site_id);

	# Make raw database calls to speed up this process.  Since we're deleting
	# everything for a site from all tables, we don't need Class::DBI triggers
	# being called.

	my $dbh = CJDB::DB::DBI->db_Main;
	foreach my $table (qw(cjdb_associations cjdb_journals cjdb_links cjdb_subjects cjdb_titles cjdb_issns cjdb_relations)) {
		print "Deleting from table $table... ";
		$dbh->do("DELETE FROM $table WHERE site=$site_id");
		print "done\n";
	}

	return 1;
}	



