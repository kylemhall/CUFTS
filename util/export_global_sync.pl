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

my $tmp_dir = '/tmp/global_export';


my %options;
GetOptions( \%options, 'site_key=s', 'site_id=i', 'timestamp=s' );

my $check_timestamp = $options{timestamp};
if ( defined($check_timestamp) ) {

    if ( $check_timestamp =~ / (\d{4}) - (\d{2}) - (\d{2}) /xsm ) {
        $check_timestamp = "$1$2$3";
    }
    else {
        die("Timestamp does not match YYYY-MM-DD format: $check_timestamp");
    }
    
}

export();

sub export {

    my $site;
    if ( $options{site_id} ) {
        $site = CUFTS::DB::Sites->search( id => int($options{site_id}) )->first or
            die("Could not find site: " . $options{site_id});
    }
    elsif ( $options{site_key} ) {
        $site = CUFTS::DB::Sites->search( key => $options{site_key} )->first or
            die("Could not find site: " . $options{site_key});
    }
    else {
        usage();
        exit;
    }

    my $site_id = $site->id;

    my $timestamp = get_timestamp();
    $tmp_dir .= '_' . $timestamp;

    mkdir ${tmp_dir} or
        die("Unable to create temp dir: $!");

    my $local_resources_iter = CUFTS::DB::LocalResources->search( 
        site => $site_id, 
        active => 't', 
        resource => { '!=' => undef }
    );
    
    my $resource_xml;

RESOURCE:

    while ( my $local_resource = $local_resources_iter->next ) {
        my $resource = $local_resource->resource;

        print "Checking: ", $resource->name, "\n";

        if ( !$resource->do_module('has_title_list') ) {
            print "Resource does not use title lists, skipping.\n";
            next RESOURCE;
        }

        if ( defined($check_timestamp) ) {
            my $scanned = $resource->title_list_scanned;
            if ( $scanned =~ /^ (\d{4}) - (\d{2}) - (\d{2}) /xsm ) {
                $scanned = "$1$2$3";
            }
            else {
                print "Unable to match date in timetamp: " . $resource->title_list_scanned . "\n";
                next RESOURCE;
            }

            if ( $scanned >= $check_timestamp ) {
                print "Updated after timestamp check date.\n";
            }
            else {
                print "Not updated after timestamp check date.\n";
                next RESOURCE;
            }

        }

        ##
        ## Check for a global export key.  Resources without a key will not be
        ## exported since they can't be matched reliably with a remote install.
        ##


        my $key = $resource->key;
        if ( !defined($key) ) {
            print "No key defined, skipping resource.\n";
            next RESOURCE;
        }
        if ( $key =~ / [^a-zA-Z_] /xsm ) {
            print "Invalid characters detected in key ($key), skipping resource.\n";
            next RESOURCE;
        }

        ##
        ## Create titles export file
        ##

    
        my $columns = $resource->do_module( 'title_list_fields' );
        next RESOURCE if !defined($columns);
        
        open OUTPUT, ">$tmp_dir/$key" or
            die "Unable to create output file: $!";
            
        @$columns = grep { $_ ne 'id' } @$columns;

        print OUTPUT join "\t", @$columns;
        print OUTPUT "\n";
        
        my $db_module = $resource->do_module( 'global_db_module' );
        if ( is_empty_string($db_module) ) {
            print "Missing DB module, skipping resource.\n";
            next RESOURCE;
        }
        
        my $titles_iter = $db_module->search( resource => $resource->id );
        while ( my $title = $titles_iter->next ) {
            print OUTPUT join "\t", map { $title->$_ } @$columns;
            print OUTPUT "\n";
        }
        
        close OUTPUT;
        
        $resource_xml .= create_resource_xml( $local_resource, $resource );

    }
    
}


sub create_resource_xml {
    my ( $local_resource, $resource ) = @_;
  
    my $output = "<resource>\n";
    
    my @skip_fields = qw(
        id
        resource_type
        active
        title_list_scanned
        created
        modified
        resource_identifier
        title_count
    );
    
    foreach my $column ( $resource->columns, $resource->details_columns ) {
        next if grep { $_ eq $column } @skip_fields;
        
        my $value;
        if ( $local_resource->can($column) && not_empty_string($local_resource->$column) ) {
            $value = $local_resource->$column;
        }
        else {
            $value = $resource->$column;
        }

        next if is_empty_string( $value );

        $value = encode_entities( $value );
        
        $output .= "<$column>$value</$column>\n";
        
    }
        
    ##
    ## Resource type - linked table
    ##
        
    my $value = defined( $local_resource->resource_type )
                ? $local_resource->resource_type->type
                : $resource->resource_type->type;

    $output .= "<resource_type>" . encode_entities( $value ) . "</resource_type>\n";
    
    ##
    ## Services - linked table
    ##
    
    $output .= "<services>\n";
    
    foreach my $service ( $local_resource->services ) {
        $output .= "<service>" . encode_entities( $service->name) . "</service>\n";
    }
    
    $output .= "</services>\n";
    
    $output .= "</resource>\n"
    
    return $output;
}


sub get_timestamp {
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();

    $year += 1900;
    $mon  += 1;

    return sprintf( "%04i%02i%02i%02i%02i%02i", $year, $mon, $mday, $hour, $min, $sec );
}




1;