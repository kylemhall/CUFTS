#!/usr/local/bin/perl

use lib qw(lib);

$| = 1;

use strict;

use SQL::Abstract;
use Data::Dumper;

use CUFTS::Config;
use CUFTS::Util::Simple;

use CUFTS::DB::LocalJournals;
use CUFTS::DB::Journals;
use CUFTS::DB::JournalsAuthTitles;
use CUFTS::DB::JournalsAuth;
use MARC::Record;
use MARC::Field;
use MARC::File::USMARC;

use Getopt::Long;

# Read command line arguments

my %options;
GetOptions( \%options, 'local', 'site_key=s', 'site_id=i' );

my $timestamp = CUFTS::DB::DBI->get_now();

if ( $options{'local'} ) {
    my $site_id = get_site_id();
    load_local_journals($timestamp, $site_id);
}
else {
    load_journals($timestamp);
}

update_titles($timestamp);
create_MARC_records($timestamp);

CUFTS::DB::DBI->dbi_commit;

sub load_journals {
    my ($timestamp) = @_;


    my $stats = {};

# First load up all the titles with both ISSNs and eISSNs.  By processing those first, we
# should help cut down the problem of two records, each with a ISSN/eISSN and then having
# to merge them.

    load_journals_dual_issn($stats, $timestamp);
    load_journals_issn($stats, $timestamp);
    load_journals_e_issn($stats, $timestamp);
    load_journals_no_issn($stats, $timestamp);

    print Dumper($stats);

}

sub load_journals_dual_issn {
    my ($stats) = @_;

    print "\n-=- Processing journals with both ISSN and eISSNs -=-\n\n";

    my $journals = CUFTS::DB::Journals->search_where(
        'issn'         => { '!=', undef },
        'e_issn'       => { '!='  => undef },
        'journal_auth' => undef
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    return 1;
}

sub load_journals_issn {
    my ($stats) = @_;

    print "\n\n-=- Processing journals with only ISSNs -=-\n\n";

    my $journals = CUFTS::DB::Journals->search_where(
        'issn'         => { '!=', undef },
        'e_issn'       => undef,
        'journal_auth' => undef
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    return 1;
}

sub load_journals_e_issn {
    my ($stats) = @_;

    print "\n-=- Processing journals with only eISSNs -=-\n\n";

    my $journals = CUFTS::DB::Journals->search_where(
        'e_issn'       => { '!=', undef },
        'issn'         => undef,
        'journal_auth' => undef
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    return 1;
}

sub load_journals_no_issn {
    my ($stats) = @_;

    print "\n-=- Processing journals without ISSNs -=-\n\n";

    my $journals = CUFTS::DB::Journals->search_where(
        'e_issn'       => undef,
        'issn'         => undef,
        'journal_auth' => undef
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    return 1;
}

sub load_local_journals {
    my ($timestamp, $site_id) = @_;
    
    my $stats = {};

# First load up all the titles with both ISSNs and eISSNs.  By processing those first, we
# should help cut down the problem of two records, each with a ISSN/eISSN and then having
# to merge them.

    print "\n-=- Processing local journals with both ISSN and eISSNs -=-\n\n";

    my @basic_search = (
        'journal_auth', undef,
        'journal', undef
    );
    if (defined($site_id)) {
        push @basic_search, 'resource.site', $site_id;
        push @basic_search, 'resource.active', 't';
    }

    my $journals = CUFTS::DB::LocalJournals->search(
        {
            'issn'         => { '!=', undef },
            'e_issn'       => { '!='  => undef },
            @basic_search
        }
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    print "\n-=- Processing local journals with only ISSNs -=-\n\n";

    $journals = CUFTS::DB::LocalJournals->search(
        {
            'issn'         => { '!=', undef },
            'e_issn'       => undef,
            @basic_search
        }
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    print "\n-=- Processing local journals with only eISSNs -=-\n\n";

    $journals = CUFTS::DB::LocalJournals->search(
        {
            'e_issn'       => { '!=', undef },
            'issn'         => undef,
            @basic_search
        }
    );

    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp );
    }

    print Dumper($stats);
}

sub process_journal {
    my ( $journal, $stats, $timestamp ) = @_;

    # Skip journal if resource is not active
    
    return undef if !$journal->resource->active;

    $stats->{'count'}++;

    # Find ISSN matches

    my @issn_search;

    if ( not_empty_string($journal->issn) ) {
        push @issn_search, $journal->issn;
    }
    if ( not_empty_string($journal->e_issn) && !grep $journal->e_issn, @issn_search ) {
        push @issn_search, $journal->e_issn;
    }

    my @journal_auths;

    if ( scalar(@issn_search) ) {
        @journal_auths = CUFTS::DB::JournalsAuth->search_by_issns(@issn_search);
    }
    else {
        @journal_auths = CUFTS::DB::JournalsAuth->search_where(
            title => { 'ilike' => $journal->title } );
            
        warn('title search: ' . scalar(@journal_auths));
    }

    if ( scalar(@journal_auths) > 1 ) {
        print Dumper($journal), "\n";
        print Dumper( \@journal_auths ), "\n";

        warn(
            "Multiple journal_auth matches for ISSN.  This should not happen during the original build"
        );
    }
    elsif ( scalar(@journal_auths) == 1 ) {

        my $journal_auth = $journal_auths[0];

        # Check for title match in alternate titles, add if not found.

        $journal->journal_auth( $journal_auth->id );
        $journal->update;

        my $title = $journal->title;
        $title =~ s/^\s+//;
        $title =~ s/\s+$//;

        my $title_rec = CUFTS::DB::JournalsAuthTitles->find_or_create(
            { 'title' => $title, 'journal_auth' => $journal_auth->id } );
        $title_rec->title_count( $title_rec->title_count + 1 );
        $title_rec->update;

        my @journal_auth_issns = map { $_->issn } $journal_auth->issns;

        foreach my $issn (@issn_search) {
            if ( !grep { $issn eq $_ } @journal_auth_issns ) {
                $journal_auth->add_to_issns(
                    { issn => $issn, info => 'CUFTS (initial load)' } );
            }
        }

        $journal_auth->modified($timestamp);
        $journal_auth->update;
        
        $stats->{match}++;

        print "1";

    }
    else {

        # Add new records

        my $title = $journal->title;
        $title =~ s/^\s+//;
        $title =~ s/\s+$//;

        # Create a record with a blank title.. we're going to search for blank title records
        # later and promote a JournalAuthTitles record to the official title.

        my $journal_auth = CUFTS::DB::JournalsAuth->create(
            {
                title    => $title,
                created  => $timestamp,
                modified => $timestamp,
             }
        );

        CUFTS::DB::JournalsAuthTitles->create(
            {   'journal_auth' => $journal_auth->id,
                'title'        => $title,
                'title_count'  => 1
            }
        );

        $journal->journal_auth( $journal_auth->id );
        $journal->update;

        foreach my $issn (@issn_search) {
            $journal_auth->add_to_issns(
                { issn => $issn, info => 'CUFTS (initial load)' } );
        }

        $stats->{'new_record'}++;

        print "!";
    }

    $stats->{'count'} % 80 == 0
        and print "\n$stats->{'count'}\n";

}

# Set up "official titles" based on number of title matches

sub update_titles {
    my ($timestamp) = @_;
    
    my $auths = CUFTS::DB::JournalsAuth->search( 'modified' => $timestamp );

    print "\n-=- Promoting titles to create official journal_auth title -=-\n";

    while ( my $auth = $auths->next ) {
        my @titles = $auth->titles;
        next unless @titles > 1;

        @titles = sort { $b->title_count <=> $a->title_count } @titles;

        if ( $titles[0]->title ne $auth->title ) {
            $auth->title( $titles[0]->title );
            $auth->update;
        }
    }
}

# Create stub MARC records based on existing data

sub update_MARC_records {
    my ($timestamp) = @_;
    
    print "\n-=- Updating titles on existing MARC records -=-\n";
    
    my $auths = CUFTS::DB::JournalsAuth->search( 'modified' => $timestamp );

    while ( my $auth = $auths->next ) {
        next if !defined($auth->marc);
        
        my $MARC = MARC::File::USMARC::decode($auth->MARC);

        my @title_fields = MARC->field('246');
        my @existing_titles = map { $_->subfield('a') } @title_fields;

ALT_TITLE:
        foreach my $alt_title ( map { $_->title } $auth->titles ) {
            next ALT_TITLE if grep { $_ eq $alt_title } @existing_titles;
            my $alt_field = MARC::Field->new( 246, 2, 3, 'a' => $alt_title );
            $MARC->append_fields($alt_field);
        }

        $auth->MARC( $MARC->as_usmarc );
        $auth->update;
    }

    return 1;
}
    
# Create stub MARC records based on existing data

sub create_MARC_records {
    my ($timestamp) = @_;
    
    print "\n-=- Creating simple MARC records -=-\n";

    my (@articles) = (
        'An\s+',  'The\s+', 'La\s+', 'Le\s+', 'Les\s+', 'L\'',
        'Der\s+', 'Das\s+', 'Die\s+',
    );

    my ( $sec, $min, $hour, $day, $mon, $year ) = localtime;
    my $MARC_timestamp = sprintf(
        "%i4%i2%i2%i2%i2%i2\.0",
        $year + 1900,
        $mon + 1, $day, $hour, $min, $sec
    );
    my $time_field = MARC::Field->new( '005', $MARC_timestamp );
    my $field_006  = MARC::Field->new( '006', 'm        d        ' );
    my $field_007  = MARC::Field->new( '007', 'cr u||||||||||' );
    my $field_008  = MARC::Field->new( '008', '050706||||||||||||||||||||d|||||||||||||' );

    my $auths = CUFTS::DB::JournalsAuth->search( marc => undef );

    while ( my $auth = $auths->next ) {
        next if $auth->MARC;

        my $MARC = MARC::Record->new();

        $MARC->append_fields( $time_field, $field_006, $field_007, $field_008 );

        # Set ISSN fields

        foreach my $issn ( map { $_->issn } $auth->issns ) {
            substr( $issn, 4, 0 ) = '-';
            my $issn_field
                = MARC::Field->new( '022', '#', '#', 'a' => $issn );
            $MARC->append_fields($issn_field);
        }

        my $title = $auth->title;

        # Check for article so we can set the 245 indicator

        my $lead_chars = 0;
        foreach my $article (@articles) {
            if ( $title =~ /^(${article})/ ) {
                $lead_chars = length($1);
                last;
            }
        }

        # Create main title field

        my $title_field
            = MARC::Field->new( 245, 0, $lead_chars, 'a' => $title );

        $MARC->append_fields($title_field);

        foreach my $alt_title ( map { $_->title } $auth->titles ) {
            my $alt_field = MARC::Field->new( 246, 2, 3, 'a' => $alt_title );
            $MARC->append_fields($alt_field);
        }

        $auth->MARC( $MARC->as_usmarc );
        $auth->update;
    }
}


sub get_site_id {
	return $options{'site_id'} if defined($options{'site_id'});
    return undef if !defined($options{'site_key'});

	my @sites = CUFTS::DB::Sites->search('key' => $options{'site_key'});
	
	scalar(@sites) == 1 or
		die('Could not get CUFTS site for key: ' . $options{'site_key'});
		
	return $sites[0]->id;
}


