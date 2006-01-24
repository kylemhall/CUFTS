#!/usr/local/bin/perl

use lib qw(lib);

$| = 1;

my $PROGRESS = 1;

use strict;

use Data::Dumper;

use CUFTS::Config;
use CUFTS::Util::Simple;

use CUFTS::DB::LocalJournals;
use CUFTS::DB::Journals;
use CUFTS::DB::JournalsAuthTitles;
use CUFTS::DB::JournalsAuth;
use CUFTS::JournalsAuth;

use Getopt::Long;
use MARC::Record;
use MARC::Field;
use MARC::File::USMARC;
use Term::ReadLine;


# Read command line arguments

my %options;
GetOptions( \%options, 'report', 'progress', 'local', 'interactive', 'site_key=s', 'site_id=i' );

my $searches = {
    issns => {
        issn         => { '!=' => undef },
        e_issn       => { '!=' => undef },
        journal_auth => undef,
        'resource.active' => 't',
    },
    issn => {
        issn         => { '!=' => undef },
        e_issn       => undef,
        journal_auth => undef,
        'resource.active' => 't',
    },
    e_issn => {
        issn         => undef,
        e_issn       => { '!=' => undef },
        journal_auth => undef,
        'resource.active' => 't',
    },
    no_issn => {
        issn              => undef,
        e_issn            => undef,
        journal_auth      => undef,
        'resource.active' => 't',
    },
    
};

main();

sub main {
   my $timestamp = CUFTS::DB::DBI->get_now();
   my $term;
   if ($options{'interactive'}) {
       my $term = new Term::ReadLine 'CUFTS Installation';
   }

    if ( $options{'local'} ) {
        my $site_id = get_site_id();
        load_journals( 'local', $timestamp, $site_id, $term );
    }
    else {
        load_journals( 'global', $timestamp, $term );
    }
    
    CUFTS::DB::DBI->dbi_commit();

    return 1;
}


sub load_journals {
    my ($flag, $timestamp, $site_id, $term) = @_;
    my $stats = {};

    my $search_extra = {};
    my $search_module; 

    # Add extra search information if we're doing a local resource build

    if ($flag eq 'local') {
        $search_extra  = { 'journal' => undef };
        $search_module = 'CUFTS::DB::LocalJournals';
        
        if ($site_id) {
            $search_extra->{'resource.site'}   = $site_id;
        }

    } else {
        $search_module = 'CUFTS::DB::Journals';
    }

    $PROGRESS && print "\n-=- Processing journals with both ISSN and eISSNs -=-\n\n";

    my $journals = $search_module->search( { %{$searches->{issns}}, %{$search_extra} } );
    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp, $term );
#        last if $stats->{count} % 100 == 99;
    }

    $PROGRESS && print "\n\n-=- Processing journals with only ISSNs -=-\n\n";

    $journals = $search_module->search( { %{$searches->{issn}}, %{$search_extra} } );
    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp, $term );
#        last if $stats->{count} % 100 == 99;
    }

    $PROGRESS && print "\n-=- Processing journals with only eISSNs -=-\n\n";

    $journals = $search_module->search( { %{$searches->{e_issn}}, %{$search_extra} } );
    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp, $term );
#        last if $stats->{count} % 100 == 99;
    }

    $PROGRESS && print "\n-=- Processing journals with no ISSNs -=-\n\n";

    $journals = $search_module->search( { %{$searches->{no_issn}}, %{$search_extra} } );
    while ( my $journal = $journals->next ) {
        process_journal( $journal, $stats, $timestamp, $term );
#        last if $stats->{count} % 100 == 99;
    }
    
    display_stats($stats);
    return 1;
}


sub process_journal {
    my ( $journal, $stats, $timestamp, $term ) = @_;

    # Skip journal if resource and journal is not active

    return undef if $journal->can('active') && !$journal->active;

    $stats->{'count'}++;

    # Find ISSN matches

    my @issn_search;

    if ( not_empty_string( $journal->issn ) ) {
        push @issn_search, $journal->issn;
    }
    if ( not_empty_string( $journal->e_issn ) && !grep { $_ eq $journal->e_issn } @issn_search ) {
        push @issn_search, $journal->e_issn;
    }

    my @journal_auths;
    my $journal_auth;

    if ( scalar(@issn_search) ) {
        @journal_auths = CUFTS::DB::JournalsAuth->search_by_issns(@issn_search);
    }
    else {
        @journal_auths = CUFTS::DB::JournalsAuth->search_by_exact_title_with_no_issns($journal->title);
    }

    if ( scalar(@journal_auths) > 1 ) {
        if (defined($term)) {
            # Interactive
            
            display_journal($journal);
            foreach my $ja (@journal_auths) {
                display_journal_auth($ja);
            }
            
INPUT:
            while (1) {
                print "[S]kip record, [c]reate new journal_auth, [m]erge all journal_auths, or enter journal_auth ids.\n";
                my $input = $term->readline('[S/c/m/ids]: ');

        	    if ( $input =~ /^[cC]/ ) {
        	        $journal_auth = create_ja_record($journal, \@issn_search, $timestamp, $stats);
        	        last INPUT;
        	    } elsif ( $input =~ /^[mM]/ ) {
        	        $journal_auth = CUFTS::JournalsAuth->merge( map {$_->id} @journal_auths );
        	        last INPUT;
        	    } elsif ( $input =~ /^[sS]/ || $input eq '' ) {
        	        return undef;
        	    } elsif ( $input =~ /^[\d ]+$/ ) {

        	        my @merge_ids = split /\s+/, $input;
        	        foreach my $merge_id (@merge_ids) {
        	            $merge_id = int($merge_id);
        	            if ( !grep { $merge_id == $_->id } @journal_auths ) {
        	                print "id input does not match possible merge targets: $merge_id\n";
        	                next INPUT;
        	            }
        	            $journal_auth = CUFTS::JournalsAuth->merge(@merge_ids);
        	            last INPUT;
        	        }

        	    }
        	}
        }
        else {
            push @{$stats->{multiple_matches}}, $journal;
            $journal_auth = create_ja_record($journal, \@issn_search, $timestamp, $stats);
            
        }
    }
    elsif ( scalar(@journal_auths) == 1 ) {
        $journal_auth = update_ja_record($journal_auths[0], $journal, \@issn_search, $timestamp, $stats);
    }
    else {
        $journal_auth = create_ja_record($journal, \@issn_search, $timestamp, $stats);
    }

    if ( $PROGRESS && $stats->{'count'} % 100 == 0 ) {
        print "\n$stats->{'count'}\n";
    }

    return $journal_auth;
}

sub display_journal {
    my ($journal) = @_;
    
    print "New journal record\n--------------\n";
    print $journal->title, "\n";
    if ($journal->issn) {
        print $journal->issn, "\n";
    }
    if ($journal->e_issn) {
        print $journal->e_issn, "\n";
    }
    print $journal->resource->name, ' - ', $journal->resource->provider, "\n";
    print "-------------------\n";
    
    return 1;
}

sub display_journal_auth {
    my ($ja) = @_;
    
    print "Existing JournalAuth record\n-------------------\n";
    print "ID: ", $ja->id, "\n";
    print $ja->title, "\n";
    if ($ja->issns) {
        print join ' ', map {$_->issn} $ja->issns;
    }
    foreach my $title ($ja->titles) {
        print $title, "\n";
    }
    print "-------------------\n";

    return 1;
}


sub create_ja_record {
    my ($journal, $issns, $timestamp, $stats) = @_;

    my $title = trim_string($journal->title);
    
    # Test ISSNs
    foreach my $issn (@$issns) {
        my @issns = CUFTS::DB::JournalsAuthISSNs->search( { issn => $issn } );
        if ( scalar(@issns) ) {
            push @{$stats->{ issn_dupe }}, $journal;
            return undef;
        }
    }
    
    
    my $journal_auth = CUFTS::DB::JournalsAuth->create(
        {   
            title    => $title,
            created  => $timestamp,
            modified => $timestamp,
        }
    );

    CUFTS::DB::JournalsAuthTitles->create(
        {   
            'journal_auth' => $journal_auth->id,
            'title'        => $title,
            'title_count'  => 1
        }
    );

    $journal->journal_auth( $journal_auth->id );
    $journal->update;

    foreach my $issn (@$issns) {
        $journal_auth->add_to_issns(
            {
                issn => $issn,
                info => 'CUFTS (initial load)',
            }
        );
    }

    $stats->{new_record}++;

    $PROGRESS and print "!";
    
    return $journal_auth;
}

sub update_ja_record {
    my ($journal_auth, $journal, $issns, $timestamp, $stats) = @_;

    my @journal_auth_issns = map { $_->issn } $journal_auth->issns;

    # Test ISSNs
    foreach my $issn (@$issns) {
        if ( !grep { $issn eq $_ } @journal_auth_issns ) {
        
            my @issns = CUFTS::DB::JournalsAuthISSNs->search( { issn => $issn } );
            if ( scalar(@issns) ) {
                push @{$stats->{ issn_dupe }}, $journal;
                return undef;
            }

        }
    }

    $journal->journal_auth( $journal_auth->id );
    $journal->update;

    my $title = trim_string($journal->title);

    my $title_rec = CUFTS::DB::JournalsAuthTitles->find_or_create(
        {
            'title' => $title,
            'journal_auth' => $journal_auth->id
        }
    );
    $title_rec->title_count( $title_rec->title_count + 1 );
    $title_rec->update;

    foreach my $issn (@$issns) {
        if ( !grep { $issn eq $_ } @journal_auth_issns ) {

            $journal_auth->add_to_issns(
                {
                    issn => $issn,
                    info => 'CUFTS (initial load)'
                }
            );

        }
    }

    $journal_auth->modified($timestamp);
    $journal_auth->update;
    
    $stats->{match}++;

    $PROGRESS and print "1";
    
    return $journal_auth;
}

sub show_report {
    # slow, but easy
    
    my $journal_auths = CUFTS::DB::JournalsAuth->retrieve_all;
    while (my $journal_auth = $journal_auths->next) {
        my @titles = $journal_auth->titles;
        next if scalar(@titles) == 1;
        
        my @issns = $journal_auth->issns;
        my $issn_string = join ',', map {substr($_->issn,0,4) . '-' . substr($_->issn,4)} @issns;

        print $issn_string, "\n";
        foreach my $title (@titles) {
            print $title->title, "\n";
        }
        print "\n";
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

sub display_stats {
    my ($stats) = @_;
    
    print "Journal records checked: ", $stats->{count}, "\n";
    print "journal_auth records created: ", $stats->{new_record}, "\n";
    print "journal_auth records matched: ", $stats->{matched}, "\n";
    
    print "Records skipped due to existing ISSNs\n------------------------------------\n";
    foreach my $journal ( @{$stats->{issn_dupe}} ) {
        print $journal->title, "  ";
        print $journal->issn, " ";
        print $journal->e_issn, " ";
        print $journal->resource->name, "\n";
    }
    
    print "Records skipped due to multiple matches\n------------------------------------\n";
    foreach my $journal ( @{$stats->{multiple_matches}} ) {
        print $journal->title, "  ";
        print $journal->issn, " ";
        print $journal->e_issn, " ";
        print $journal->resource->name, "\n";
    }

    return 1;
}