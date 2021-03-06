#!/usr/local/bin/perl

##
## This script checks all CUFTS sites for files that are
## marked for reloading and then loads the print/CUFTS records
## if required.
##

$| = 1;

use lib qw(lib);

use CUFTS::Config;
use CUFTS::Util::Simple;

use String::Util qw(hascontent trim);
use Net::IP;
use Log::Log4perl qw(:easy);
use Unicode::String qw(utf8 latin1);

use strict;

Log::Log4perl->easy_init($INFO);
my $logger = Log::Log4perl->get_logger();

load_all_sites($logger);

sub load_all_sites {
    my ( $logger ) = @_;

    $logger->info('Starting Google Scholar build script.');

    my $output;
    $output .= qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n};
    $output .= qq{<!DOCTYPE institutions PUBLIC "-//GOOGLE//Institutional Links List 1.0//EN" "http://scholar.google.com/scholar/institutions.dtd">\n};
    $output .= "<institutions>\n";

    my $schema   = CUFTS::Config::get_schema();
    my $sites_rs = $schema->resultset('Sites')->search({ active => 't' });

SITE:
    while ( my $site = $sites_rs->next ) {
    	print "Checking " . $site->name . "\n";

    	next if $site->google_scholar_on ne '1' && $site->google_scholar_on ne 't';

    	my $errors = 0;
    	if ( !hascontent($site->google_scholar_e_link_label) ) {
    	    $logger->error("Electronic link label field is empty");
    	    $errors++;
    	}
    	if ( !hascontent($site->google_scholar_other_link_label) ) {
    	    $logger->error("Other link label field is empty");
    	    $errors++;
    	}
    	if ( !hascontent($site->google_scholar_openurl_base) ) {
    	    $logger->error("OpenURL base field is empty");
    	    $errors++;
    	}
    	if ( !scalar($site->ips) ) {
    	    $logger->error("No site IP ranges defined");
    	    $errors++;
    	}

        next if $errors;

        $output .= load_site($site, $schema, $logger);

    	$logger->info("Finished " . $site->name);
    }
    $output .= "</institutions>\n";

    $logger->info("Attempting to create control file");

    my $dir = $CUFTS::Config::CUFTS_RESOLVER_SITE_DIR . '/static';
    -d $dir
        or mkdir $dir
            or die("Unable to create directory for Google Scholar control file ($dir): $!");

    $dir .= '/GoogleScholar';
    -d $dir
         or mkdir $dir
             or die("Unable to create directory for Google Scholar control file ($dir): $!");

    my $file = $dir . '/institutions.xml';
    open GSFILE, ">$file"
        or die("Unable to open file ($file) for writing: $!");

    print GSFILE $output;
    close GSFILE;

    print "Done!\n";
}

sub load_site {
    my ($site, $schema, $logger) = @_;

	my $site_id = $site->id;

    my $local_journals_rs = $site->local_journals(
        {
            'me.active'             => 't',
            'local_resource.active' => 't',
        }
    );

    my %jas;
    my $count;

    $logger->info('Processing journals');

    while ( my $lj = $local_journals_rs->next ) {

        # Merge date and embargo data

        my $gj = $lj->global_journal;

        # Get appropriate journal auth id or skip

        my $ja_id = defined($lj->get_column('journal_auth')) ? $lj->get_column('journal_auth') : defined($gj) ? $gj->get_column('journal_auth') : undef;
        next if !defined($ja_id);

        # Figure out coverage

        my $ft_start_date  = defined($lj->ft_start_date)  ? $lj->ft_start_date  : defined($gj) ? $gj->ft_start_date  : undef;
        my $ft_end_date    = defined($lj->ft_end_date)    ? $lj->ft_end_date    : defined($gj) ? $gj->ft_end_date    : undef;
        my $embargo_days   = defined($lj->embargo_days)   ? $lj->embargo_days   : defined($gj) ? $gj->embargo_days   : undef;
        my $embargo_months = defined($lj->embargo_months) ? $lj->embargo_months : defined($gj) ? $gj->embargo_months : undef;

        # Set embargo_days based on 30 day month

        if ( hascontent($embargo_months) && !hascontent($embargo_days) ) {
            $embargo_days = $embargo_months * 30;
        }

        # Clear future end dates and treat as not set ("current")

        if ( hascontent($ft_end_date) && $ft_end_date gt '2019-01-01' ) {
            $ft_end_date = undef;
        }

        # Skip if there's no fulltext start date. TODO - add "current" support

        next if !hascontent($ft_start_date);

        # Store coverage

        push @{$jas{$ja_id}}, {
            start => $ft_start_date,
            end   => $ft_end_date,
            embargo => $embargo_days,
        };
    }

    my $output;
    my $file_count = 0;

    $logger->info('Writing records');

    foreach my $ja_id ( keys %jas ) {
        my $journal_auth = $schema->resultset('JournalsAuth')->find({ id => $ja_id });
        next if !defined($journal_auth);

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

        foreach my $coverage ( @{$jas{$ja_id}} ) {
            $output .=  "<coverage>\n";

            my ($year, $month, $day) = split '-', $coverage->{start};
            $output .=  "<from>\n";
            $output .=  "<year>$year</year>\n";
            $output .=  "<month>$month</month>\n";
            $output .=  "</from>\n";

            if ( hascontent($coverage->{embargo}) ) {
                $output .=  "<embargo>\n";
                $output .=  "<days_not_available>" . $coverage->{embargo} ."</days_not_available>\n";
                $output .=  "</embargo>\n";
            }
            elsif ( !hascontent($coverage->{embargo}) && hascontent($coverage->{end}) ) {
                my ($year, $month, $day) = split '-', $coverage->{end};
                $output .=  "<to>\n";
                $output .=  "<year>$year</year>\n";
                $output .=  "<month>$month</month>\n";
                $output .=  "</to>\n";
            }

            $output .=  "</coverage>\n";

        }

        $output .=  "</item>\n";

        if ( length($output) > 1046528 ) {
            $file_count = output( $site, $file_count, \$output );
            $output = '';
        }

    }

    $file_count = output( $site, $file_count, \$output );

    $logger->info('Creating summary block');

    return create_summary($site, $file_count);
}

sub create_summary {
    my ($site, $file_count) = @_;

    my $site_key = $site->key;
    my $site_id  = $site->id;

    my $output = qq{<institutional_links id="$site_key">\n};

    $output .= "<institution>" . $site->name . "</institution>\n";
    if ( hascontent($site->google_scholar_keywords) ) {
        $output .=  "<keywords>" . $site->google_scholar_keywords . "</keywords>\n";
    }
    $output .=  "<contact>" . $site->email . "</contact>\n";
    $output .=  "<electronic_link_label>" .  $site->google_scholar_e_link_label . "</electronic_link_label>\n";
    $output .=  "<other_link_label>" .  $site->google_scholar_other_link_label . "</other_link_label>\n";

    $output .=  "<openurl_base>" . $site->google_scholar_openurl_base . "</openurl_base>\n";

    $output .=  "<openurl_option>doi</openurl_option>\n";
    $output .=  "<openurl_option>journal-title</openurl_option>\n";
    $output .=  "<openurl_option>pmid</openurl_option>\n";

    $output .=  "<electronic_holdings>\n";
    foreach my $count ( 1 .. ( $file_count - 1 ) ) {
        $output .=  "<url>${CUFTS::Config::CUFTS_RESOLVER_URL}/sites/${site_id}/static/GoogleScholar/journals${count}.xml</url>\n";
    }
    $output .=  "</electronic_holdings>\n";

    foreach my $ip ( $site->ips ) {
        my $start = $ip->ip_low;
        my $end   = $ip->ip_high;
        $output .=  "<patron_ip_range>${start}-${end}</patron_ip_range>\n";
    }

    if ( hascontent($site->google_scholar_other_xml) ) {
        $output .= $site->google_scholar_other_xml;
    }

    $output .=  "</institutional_links>\n";

    return $output;
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
        $dir .= '/' . $site->id . '/static/GoogleScholar';
    }

    my $file = "$dir/journals${file_count}.xml";
    open GSFILE, ">$file"
        or die("Unable to open file ($file) for writing: $!");

    print GSFILE qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n};
    print GSFILE qq{<!DOCTYPE institutional_holdings PUBLIC "-//GOOGLE//Institutional Holdings 1.0//EN" "http://scholar.google.com/scholar/institutional_holdings.dtd">\n};
    print GSFILE "<institutional_holdings>\n" . $$output . "</institutional_holdings>\n";

    close GSFILE;
    $file_count++;

    return $file_count;
}
