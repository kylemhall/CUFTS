#!/usr/local/bin/perl

##
## This script checks exports a global sync file for a specified site
##

use lib qw(lib);

use HTML::Entities;

use CUFTS::Exceptions;
use CUFTS::Config;
use CUFTS::Util::Simple;

use CUFTS::DB::DBI;

use CUFTS::DB::Sites;
use CUFTS::DB::Resources;
use CUFTS::DB::Journals;
use CUFTS::DB::JournalsActive;
use CUFTS::DB::Stats;

use CUFTS::ResourcesLoader;

use Getopt::Long;

use strict;

my $tmp_dir = '/tmp/global_import';


my %options;

my $infile = shift(@ARGV);

import();

sub import {

    my $timestamp = get_timestamp();
    $tmp_dir .= '_' . $timestamp;

    mkdir $tmp_dir or
        die("Unable to create temp dir: $!");
        
    `tar xzf ${infile} -C ${tmp_dir}` or
        die("Unable to extract import file.");

}

sub get_timestamp {
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();

    $year += 1900;
    $mon  += 1;

    return sprintf( "%04i%02i%02i%02i%02i%02i", $year, $mon, $mday, $hour, $min, $sec );
}




1;