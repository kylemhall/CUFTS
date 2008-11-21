## CUFTS::Resources::Gale_II
##
## Copyright Michelle Gauthier - Simon Fraser University (2003)
##
## This file is part of CUFTS.
##
## CUFTS is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 2 of the License, or (at your option)
## any later version.
##
## CUFTS is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CUFTS; if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CUFTS::Resources::Gale_II;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;
use URI::Escape;

use strict;

## title_list_fields - Controls what fields get displayed and loaded from
## title lists.
##

sub title_list_fields {
    return [
        qw(
            id
            title
            issn
            ft_start_date
            ft_end_date
            cit_start_date
            cit_end_date
        )
    ];
}

## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
    return {
        'Journal Name'   => 'title',
        'ISSN'           => 'issn',
        'Embargo (Days)' => 'embargo_days',
    };
}

sub overridable_resource_details {
        my ($class) = @_;

        my $details = $class->SUPER::overridable_resource_details();
        push @$details, 'url_base';

        return $details;
}


sub clean_data {
    my ( $class, $record ) = @_;

    my ( $ft_start_date, $ft_end_date ) = ( '0', '0' );

    if ( defined( $record->{'___Index Start'} )
        && $record->{'___Index Start'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        $record->{cit_start_date} = substr( $temp_date, 0, 4 ) . '-' . substr( $temp_date, 4, 2 );
    }
    elsif ( defined( $record->{'___Index Start'} )
        && $record->{'___Index Start'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $record->{cit_start_date} = sprintf( "%04i-%02i", $2, $1);
    }

    if ( defined( $record->{'___Index End'} )
        && $record->{'___Index End'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        $record->{cit_end_date} = substr( $temp_date, 0, 4 ) . '-' . substr( $temp_date, 4, 2 );
    }
    elsif ( defined( $record->{'___Index End'} )
        && $record->{'___Index End'} =~ /(\d{1,2})\/(\d{4})/ )
    {   
        $record->{cit_end_date} = sprintf( "%04i-%02i", $2, $1);
    }

    # Gale can't seem to keep their columns consistent, so try an alternative

    if ( !exists($record->{'___Full-text Start'}) ) {
       $record->{'___Full-text Start'} = $record->{'___Full-Text Start'}
    }
    if ( !exists($record->{'___Full-text End'}) ) {
       $record->{'___Full-text End'} = $record->{'___Full-Text End'}
    }

    if ( defined( $record->{'___Full-text Start'} )
        && $record->{'___Full-text Start'} =~ /(\w{3})-(\d{2})/ )
    {
        $ft_start_date = get_date( $1, $2 );
    }
    elsif ( defined( $record->{'___Full-text Start'} )
        && $record->{'___Full-text Start'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $ft_start_date = sprintf( "%04i%02i", $2, $1);
    }

    if ( defined( $record->{'___Full-text End'} )
        && $record->{'___Full-text End'} =~ /(\w{3})-(\d{2})/ )
    {
        $ft_end_date = get_date( $1, $2 );
    }
    elsif ( defined( $record->{'___Full-text End'} )
        && $record->{'___Full-text End'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $ft_end_date = sprintf( "%04i%02i", $2, $1);
    }

    # Check the Image dates to see if they are better than the fulltext ones

    if ( defined( $record->{'___Image Start'} )
        && $record->{'___Image Start'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        if ( int($temp_date) < int($ft_start_date) ) {
            $ft_start_date = $temp_date;
        }
    }
    elsif ( defined( $record->{'___Image Start'} )
        && $record->{'___Image Start'} =~ /(\d{1,2})\/(\d{4})/ )
    {
	my $temp_date = sprintf( "%04i%02i", $2, $1);
	if ( int($temp_date) < int($ft_start_date) ) {
            $ft_start_date = $temp_date;
        }
    }

    if ( defined( $record->{'___Image End'} )
        && $record->{'___Image Start'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        if ( int($temp_date) > int($ft_end_date) ) {
            $ft_end_date = $temp_date;
        }
    }
    elsif ( defined( $record->{'___Image End'} )
        && $record->{'___Image End'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        my $temp_date = sprintf( "%04i%02i", $2, $1);
        if ( int($temp_date) < int($ft_end_date) ) {
            $ft_end_date = $temp_date;
        }
    }

    if ( defined($ft_start_date) && $ft_start_date ne '0' ) {
        $record->{ft_start_date} = substr( $ft_start_date, 0, 4 ) . '-' . substr( $ft_start_date, 4, 2 );
    }
    if ( defined($ft_end_date) && $ft_end_date ne '0' ) {
        $record->{ft_end_date} = substr( $ft_end_date, 0, 4 ) . '-' . substr( $ft_end_date, 4, 2 );
    }

    $record->{title} =~ s/\s*\(.+?\)\s*$//g;

    return $class->SUPER::clean_data($record);

    sub get_date {
        my ( $month, $year ) = @_;

        if    ( $month =~ /^Jan/i ) { $month = 1 }
        elsif ( $month =~ /^Feb/i ) { $month = 2 }
        elsif ( $month =~ /^Mar/i ) { $month = 3 }
        elsif ( $month =~ /^Apr/i ) { $month = 4 }
        elsif ( $month =~ /^May/i ) { $month = 5 }
        elsif ( $month =~ /^Jun/i ) { $month = 6 }
        elsif ( $month =~ /^Jul/i ) { $month = 7 }
        elsif ( $month =~ /^Aug/i ) { $month = 8 }
        elsif ( $month =~ /^Sep/i ) { $month = 9 }
        elsif ( $month =~ /^Oct/i ) { $month = 10 }
        elsif ( $month =~ /^Nov/i ) { $month = 11 }
        elsif ( $month =~ /^Dec/i ) { $month = 12 }
        else {
            CUFTS::Exception::App->throw(
                "Unable to find month match in fulltext date: $month");
        }

        if ( int($year) > 20 ) {
            $year = "19$year";
        }
        else {
            $year = "20$year";
        }

        return sprintf( "%04i%02i", $year, $month );
    }
}

## global_resource_details - Controls which details are displayed on the global
## resource pages
##

sub global_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::global_resource_details },
        qw(
            resource_identifier
            url_base
        )
    ];
}

## local_resource_details - Controls which details are displayed on the local
## resource pages
##

sub local_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::local_resource_details },
        qw(
            url_base
            auth_name
            proxy_suffix
        )
    ];
}

## resource_details_help - A hash ref containing the hoverover help for each of the
## local resource details
##

sub resource_details_help {
    my ($class) = @_;

    my $help_hash = $class->SUPER::resource_details_help;
    $help_hash->{'resource_identifier'} = 'Unique code defined by Gale for each database or resource.';
    $help_hash->{'url_base'}            = 'Base URL for linking to resource.';
    $help_hash->{'auth_name'}           = 'Location ID assigned by Gale. Used in construction of URL.';
    return $help_hash;
}

## -------------------------------------------------------------------------------------------

## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##

sub build_linkDatabase {
    my ( $class, $records, $resource, $site, $request ) = @_;

    my @results;

    foreach my $record (@$records) {

        my $url = $resource->url_base;
        if ( is_empty_string($url) ) { 
            $url = $resource->database_url;
        }
        if ( is_empty_string($url) ) {
            return [];
        }

        if ( $resource->auth_name ) {
            $url .= $resource->auth_name;
        }

        if ( $resource->resource_identifier ) {
            if ( $url =~ /IOURL/ ) {
                $url .= '?prod=' . $resource->resource_identifier;
            } else {
                $url .= '?db=' . $resource->resource_identifier;
            }
        }

        $url .= __add_proxy_suffix($url, $resource->proxy_suffix);
        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub build_linkJournal {
    my ( $class, $records, $resource, $site, $request ) = @_;

    my @results;

    foreach my $record (@$records) {

        my $url = $resource->url_base;
        if ( is_empty_string($url) ) { 
            $url = $resource->database_url;
        }
        if ( is_empty_string($url) ) {
            return [];
        }

        my $escaped_title = uri_escape($record->title);
        my $resource_identifier = $resource->resource_identifier;
        
        # Try first style of linking:
        # http://infotrac.galegroup.com.darius/itw/infomark/1/1/1/purl=rc18%5fSP09%5F0%5F%5Fjn+%22Computers+in+Libraries%22
        
        
        if ( $url =~ /purl=rc1/ ) {
            $url .= "\%22${escaped_title}\%22";
        }
        
        # Second link style
        # http://find.galegroup.com/itx/publicationSearch.do?dblist=&serQuery=Locale%28en%2C%2C%29%3AFQE%3D%28JX%2CNone%2C24%29%22{title}%22%24&inPS=true&type=getIssues&searchTerm=&prodId={resource_identifier}&currentPosition=0
        # may need an authname: &userGroupName=leth89164
        
        elsif ( $url =~ /\{title\}/ ) {
            $url =~ s/\{title\}/$escaped_title/e;
            $url =~ s/\{resource_identifier\}/$resource_identifier/e;
        }
        
        # Original, should have an example here.
        else {
            if ( $resource->resource_identifier ) {
                if ( $url =~ /IOURL/ ) {
                    $url .= '?prod=' . $resource_identifier;
                } else {
                    $url .= '?db=' . $resource_identifier;
                }
            }

            $url .= "&title=${escaped_title}";
        }
        
        if ( $resource->auth_name ) {
            $url .= $resource->auth_name;
        }
        
        $url .= __add_proxy_suffix($url, $resource->proxy_suffix);

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}


sub can_getFulltext {
    return 0;
}

sub can_getJournal {
    return 1;
}

sub __add_proxy_suffix {
    my ( $url, $suffix ) = @_;
    
    if ( not_empty_string( $suffix ) ) {
        # if the URL has a "?" in it already, then convert a leading ? from the suffix into a &

        if ( $url =~ /\?/ ) {  
            $suffix =~ s/^\?/&/;
        }
        return $suffix;
    }

    return '';
}


1;
