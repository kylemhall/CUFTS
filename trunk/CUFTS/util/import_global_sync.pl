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

use CUFTS::Resources;
use CUFTS::ResourcesLoader;

use XML::Parser::Lite::Tree;
use Data::Dumper;

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
        
    `tar xzf ${infile} -C ${tmp_dir}`;

    -e "${tmp_dir}/update.xml" or
        die("Unable to extract import file.");

    my $resources_tree = parse_resource_file( *INPUT_RESOURCE );

    foreach my $node ( ref($resources_tree->{xml}) eq 'ARRAY' ? @{$resources_tree->{xml}} : ( $resources_tree->{xml} ) ) {

        my $resource_node = $node->{resource};
        next if !defined($resource_node);
        
        my $key = $resource_node->{key};
        if ( is_empty_string($key) ) {
            die( "Unable to locate resource key in resource XML: " . Dumper($resource_node) );
        }
        
        my $resource = CUFTS::DB::Resources->search( 'key' => $key )->first;
        if ( !defined($resource) ) {

            $resource = create_resource( $resource_node );
            if ( !defined($resource) ) {
                die("Unable to create resource");
            }

        }
        
        print "Starting title load for: ", $resource->name, "\n";

        my $module = $resource->module;
        $module = CUFTS::Resources::__module_name($module);
        
        # This is very hackish.. Replace all the custom load methods with the ones from CUFTS::Resources

        no strict 'refs';
        *{"${module}::title_list_column_delimiter"} = *CUFTS::Resources::title_list_column_delimiter;
        *{"${module}::title_list_field_map"} = *CUFTS::Resources::title_list_field_map;
        *{"${module}::title_list_skip_lines_count"} = *CUFTS::Resources::title_list_skip_lines_count;
        *{"${module}::title_list_skip_blank_lines"} = *CUFTS::Resources::title_list_skip_blank_lines;
        *{"${module}::title_list_extra_requires"} = *CUFTS::Resources::title_list_extra_requires;


        *{"${module}::preprocess_file"} = *CUFTS::Resources::preprocess_file;
        *{"${module}::title_list_get_field_headings"} = *CUFTS::Resources::title_list_get_field_headings;
        *{"${module}::skip_record"} = *CUFTS::Resources::skip_record;
        *{"${module}::title_list_skip_lines"} = *CUFTS::Resources::title_list_skip_lines;
        *{"${module}::title_list_read_row"} = *CUFTS::Resources::title_list_read_row;
        *{"${module}::title_list_parse_row"} = *CUFTS::Resources::title_list_parse_row;
        *{"${module}::title_list_split_row"} = *CUFTS::Resources::title_list_split_row;
        *{"${module}::title_list_skip_comment_line"} = *CUFTS::Resources::title_list_skip_comment_line;
        *{"${module}::clean_data"} = *CUFTS::Resources::clean_data;

        my $results = $module->load_global_title_list($resource, "${tmp_dir}/$key");

        warn(Dumper($results));

        CUFTS::Resources->email_changes( $resource, $results );

    }

    CUFTS::DB::DBI->dbi_commit();

}


sub create_resource {
    my ( $resource_node ) = @_;
    
    # Try to find a resource type
    
    my $resource_type = CUFTS::DB::ResourceTypes->search( 'type' => $resource_node->{resource_type} )->first;
    if ( !defined($resource_type) ) {
        die("Unable to find resource type: " . $resource_node->{resource_type});
    }

    # Create base resource record

    my $resource_hash = {
        name          => $resource_node->{name},
        module        => $resource_node->{module},
        resource_type => $resource_type->id,
    };

    my $resource = CUFTS::DB::Resources->create( $resource_hash );
    if ( !defined($resource) ) {
        die("Unable to create resource record.");
    }

    # Update new resource record with other fields (including details fields)
     
    foreach my $field ( keys %$resource_node ) {
        next if grep { $field eq $_ } ( 'services', 'resource_type', 'module', 'name' );
        
        $resource->$field( $resource_node->{$field} );
    }
    
    foreach my $service ( ref($resource_node->{services}) eq 'ARRAY' ? @{$resource_node->{services}} : ( $resource_node->{services} ) ) {
        
        # Get service record for id
        
        my $service_record = CUFTS::DB::Services->search( 'name' => $service->{service} )->first;
        if ( !defined($service_record) ) {
            die("Unable to find matching service name: " . $service->{service});
        }
        
        $resource->add_to_services( { service => $service_record->id } );
        
    }
    
    $resource->update;
    
    return $resource;
}


sub get_timestamp {
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();

    $year += 1900;
    $mon  += 1;

    return sprintf( "%04i%02i%02i%02i%02i%02i", $year, $mon, $mday, $hour, $min, $sec );
}

sub parse_resource_file {
    my ( $INPUT ) = @_;
  
    open INPUT_RESOURCE, "${tmp_dir}/update.xml" or
        die("Unable to open resource input file");
    
    my $xml;
    while ( my $line = <$INPUT> ) {
        $xml .= $line;
    }
   
    close INPUT_RESOURCE;
    
    my $tree = XML::Parser::Lite::Tree::instance()->parse($xml);
    $tree = flatten_tree( $tree->{children}->[0] );
    
    return $tree;
    
}


sub flatten_tree {
    my ( $tree ) = @_;
    
    my $data;

    my $name = $tree->{name};
    my $content;
    
    if ( exists($tree->{children}) && ref($tree->{children}) && scalar( @{$tree->{children}} ) > 1 ) {

        foreach my $child ( @{$tree->{children}} ) {

            my $result = flatten_tree( $child );
            next if !defined($result);

            foreach my $key ( keys(%$result) ) {

                if ( ref($data->{$name}) eq 'ARRAY' ) {
                    push @{$data->{$name}}, $result;
                }
                else {
                
                    if ( !exists($data->{$name}->{$key}) ) {
                        $data->{$name}->{$key} = $result->{$key};
                    }
                    else {
                        if ( ref($data->{$name}->{$key}) ne 'ARRAY' ) {
                            $data->{$name} = [ { $key =>$data->{$name}->{$key} } ];
                        }
                        push @{$data->{$name}}, $result;
                    }
                }
            }
            
        }
        
    }
    else {
        $content = $tree->{children}->[0]->{content};
        return undef if !defined($content);
        $data->{$name} = $content;
    }
    
    return $data;
    
}



1;