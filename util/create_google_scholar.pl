#!/usr/local/bin/perl

##
## This script checks all CUFTS sites for files that are
## marked for reloading and then loads the print/CUFTS records
## if required.
##


$| = 1;

use Data::Dumper;

use lib qw(lib);

use CJDB::DB::DBI;
use CUFTS::DB::DBI;

use CUFTS::DB::Sites;
use CUFTS::DB::Resources;
use CUFTS::DB::Journals;
use CUFTS::DB::JournalsAuth;

use CUFTS::Util::Simple;

use Net::IP;

use Unicode::String qw(utf8 latin1);

use Getopt::Long;

use strict;

my %options;
GetOptions( \%options, 'site_key=s', 'site_id=i' );

if ($options{site_key} || $options{site_id}) {
    my $site = get_site();
    load_site($site);
} else {
    load_all_sites();
}

sub load_all_sites {
    my $site_iter = CUFTS::DB::Sites->retrieve_all;

SITE:
    while (my $site = $site_iter->next) {
    	my $site_id = $site->id;	

    	print "Checking " . $site->name . "\n";

    	next if $site->update_gs ne '1';

        load_site($site);

    	print "Finished ", $site->name,  "\n";
    }	
}

sub load_site {
    my ($site) = @_;

	my $site_id = $site->id;	

    my $lj_iter = CUFTS::DB::LocalJournals->search({
        'active'          => 't',
        'resource.active' => 't',
        'resource.site'   => $site_id,
#        'journal.journal_auth' => 315128,
    });
    my %jas;
    my $count;
    while ( my $lj = $lj_iter->next ) {
        last if $count++ > 50;
        
        if ( $lj->journal ) {
            my $gj = $lj->journal;
            $lj = $gj->resource->do_module('overlay_global_title_data', $lj, $gj)
        }

        my $ja_id = $lj->journal_auth;
        next if !defined($ja_id);

        if ( !defined($lj->ft_start_date) ) {
            $jas{$ja_id}->{start} = '0000-00-00';
        }
        elsif ( !defined($jas{$ja_id}->{start}) || $lj->ft_start_date lt $jas{$ja_id}->{start} ) {
            $jas{$ja_id}->{start} = $lj->ft_start_date;
        }

        if ( !defined($lj->ft_end_date) ) {
            $jas{$ja_id}->{end} = '9999-99-99';
        }
        elsif ( !defined($jas{$ja_id}->{end}) || $lj->ft_end_date gt $jas{$ja_id}->{end} ) {
            $jas{$ja_id}->{end} = $lj->ft_end_date;
        }

        my $embargo_days = $lj->embargo_days;
        if ( not_empty_string($lj->embargo_months) ) {
            $embargo_days = $lj->embargo_months * 30;
        }
        if ( not_empty_string($embargo_days) ) {
            if ( !defined($jas{$ja_id}->{embargo}) || $embargo_days < $jas{$ja_id}->{embargo} ) {
                $jas{$ja_id}->{embargo} = $embargo_days;
            }
        }
 
    }

    my $output;
    my $file_count = 0;

    foreach my $ja_id ( keys %jas ) {
        my $journal_auth = CUFTS::DB::JournalsAuth->retrieve($ja_id);
        $output .=  "<item type=\"electronic\">\n";
        my $title = latin1($journal_auth->title)->utf8;

        # Do this better.

        $title =~ s/&/&amp;/g;
        $title =~ s/</&lt;/g;
        $title =~ s/>/&gt;/g;

        $output .=  "<title>$title</title>\n";
        foreach my $issn ( map { $_->issn } $journal_auth->issns ) {
            substr($issn, 4, 0) = '-';
            $output .=  "<issn>$issn</issn>\n";
        }

        $output .=  "<coverage>\n";
        if ( $jas{$ja_id}->{start} ne '0000-00-00' ) {
            my ($year, $month, $day) = split '-', $jas{$ja_id}->{start};
            $output .=  "<from>\n";
            $output .=  "<year>$year</year>\n";
            $output .=  "<month>$month</month>\n";
            $output .=  "</from>\n";
        }
        if ( $jas{$ja_id}->{end} ne '9999-99-99' ) {
            my ($year, $month, $day) = split '-', $jas{$ja_id}->{end};
            $output .=  "<to>\n";
            $output .=  "<year>$year</year>\n";
            $output .=  "<month>$month</month>\n";
            $output .=  "</to>\n";
        }

        if ( not_empty_string($jas{$ja_id}->{embargo}) ) {
            $output .=  "<embargo>\n";
            $output .=  "<days_not_available>" . $jas{$ja_id}->{embargo} ."</days_not_available>\n";
            $output .=  "</embargo>\n";
        }
        
        
        $output .=  "</coverage>\n";
        $output .=  "</item>\n";

        if ( length($output) > 1046528 ) {
            $file_count = output( $site, $file_count, \$output );
            $output = '';
        }

    }

    $file_count = output( $site, $file_count, \$output );

    create_summary($site, $file_count);

    return 1;
}

sub create_summary {
    my ($site, $file_count) = @_;
    
    my $dir = $CUFTS::Config::CUFTS_RESOLVER_SITE_DIR . '/' . $site->id . '/static/GoogleScholar';
    my $file = "$dir/institutional_links.xml";
    open GSFILE, ">$file"
        or die("Unable to open file ($file)for writing: $!");

    print GSFILE qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n};
    print GSFILE qq{<!DOCTYPE institutional_links PUBLIC "-//GOOGLE//Institutional Links 1.0//EN" "http://scholar.google.com/scholar/institutional_links.dtd">\n};
    print GSFILE "<institutional_links>\n";

    print GSFILE "<institution>" . $site->name . "</institution>\n";
    print GSFILE "<keywords>" . $site->key . "</keywords>\n";
    print GSFILE "<contact>" . $site->email . "</contact>\n";
    print GSFILE "<electronic_link_label>electronic journals</electronic_link_label>\n";
    
    print GSFILE "<openurl_base>http://cufts2.lib.sfu.ca:8082/Resolver/site/" . $site->key . "/resolve/openurl/main</openurl_base>\n";
    
    print GSFILE "<openurl_option>doi</openurl_option>\n";
    print GSFILE "<openurl_option>journal-title</openurl_option>\n";

    print GSFILE "<electronic_holdings>\n";
    foreach my $count ( 1 .. ( $file_count - 1 ) ) {
        print GSFILE "<url>http://cufts2.lib.sfu.ca:8082/Resolver/sites/1/static/GoogleScholar/journal${count}.xml</url>\n";
    }
    print GSFILE "</electronic_holdings>\n";
    
    foreach my $network ( map { $_->network } $site->ips ) {
        my $ip = Net::IP->new($network);
        my $start = $ip->ip;
        my $end   = $ip->last_ip;
        print GSFILE "<patron_ip_range>${start}-${end}</patron_ip_range>\n";
    }
    
    print GSFILE "</institutional_links>\n";
    close GSFILE;
    
    
}


sub output {
    my ($site, $file_count, $output) = @_;

    if ( !defined($site) ) {
        die("No site defined in output()");
    }

    my $dir = $CUFTS::Config::CUFTS_RESOLVER_SITE_DIR;

    if ( $file_count == 0 ) {
        
        # First run - create directories if necessary, delete any
        # existing files.

        $dir = $CUFTS::Config::CUFTS_RESOLVER_SITE_DIR;
        -d $dir
            or die("No directory for the CUFTS resolver site files: $dir");

        $dir .= '/' . $site->id;
        -d $dir
            or mkdir $dir
                or die("Unable to create directory $dir: $!");

        $dir .= '/static';
        -d $dir
            or mkdir $dir
                or die("Unable to create directory $dir: $!");

        $dir .= '/GoogleScholar';
        -d $dir
            or mkdir $dir
                or die("Unable to create directory $dir: $!");

        opendir GSDIR, $dir
            or die("Unable to open GS dir: $!");
            
        # Delete all files in GoogleScholar directory that do not start with '.'

        my @unlink_files = map { "$dir/$_" } grep !/^\./, readdir GSDIR;
        closedir GSDIR;
        my @unlink_errs = grep {not unlink} @unlink_files;
        if (@unlink_errs) {
            die("Unable to remove exising GS files: @unlink_errs\n")
        }

        $file_count++;
    } else {
        $dir = '/' . $site->id . '/static/GoogleScholar';
    }

    my $file = "$dir/journals${file_count}.xml";
    open GSFILE, ">$file"
        or die("Unable to open file ($file)for writing: $!");

    print GSFILE qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n};
    print GSFILE qq{<!DOCTYPE institutional_holdings PUBLIC "-//GOOGLE//Institutional Holdings 1.0//EN" "http://scholar.google.com/scholar/institutional_holdings.dtd">\n};
    print GSFILE "<institutional_holdings>\n" . $$output . "</institutional_holdings>\n";

    close GSFILE;
    $file_count++;

    return $file_count;
}


sub get_site {
	defined($options{'site_id'}) and
		return CUFTS::DB::Sites->retrieve(int($options{'site_id'}));

	my @sites = CUFTS::DB::Sites->search('key' => $options{'site_key'});
	
	scalar(@sites) == 1 or
		die('Could not get CUFTS site for key: ' . $options{'site_key'});
		
	return $sites[0];
}



