## CUFTS::Resources::MetaPress
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
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

package CUFTS::Resources::MetaPress;

use base qw(CUFTS::Resources::Base::DOI CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use Unicode::String qw(utf8);

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
            e_issn

            ft_start_date
            ft_end_date
            vol_ft_start
            vol_ft_end

            publisher
        )
    ];
}

## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
    return {
        'Journal'                => 'title',
        'Print ISSN'             => 'issn',
        'Online ISSN'            => 'e_issn',
        'Oldest Cover Date'      => 'ft_start_date',
        'Most Recent Cover Date' => 'ft_end_date',
        'Oldest Volume'          => 'vol_ft_start',
        'Most Recent Volume'     => 'vol_ft_end',
        'Publisher'              => 'publisher',
    };
}

sub global_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::global_resource_details },
        qw(
            url_base
        )
    ];
}

sub clean_data {
    my ( $class, $record ) = @_;
    my @errors;

    $class->SUPER::clean_data($record);

    if (defined( $record->{'___Notes'} )
        && (   $record->{'___Notes'} =~ /^Database/
            || $record->{'___Notes'} =~ /^No\sissues/ )
        )
    {
        return ['Skipping due to no holdings at Metapress'];
    }

    if ( defined( $record->{ft_start_date} ) ) {
        $record->{ft_start_date} = parse_date( $record->{ft_start_date} );
    }
    if ( defined( $record->{ft_end_date} ) ) {
        $record->{ft_end_date} = parse_date( $record->{ft_end_date} );

        # Drop end dates if they're this or last year

        if ( $record->{ft_end_date} =~ /^(\d{4})/ ) {
            my $year = (localtime())[5] + 1900 - 1;
            if ( $1 >= $year ) {
                delete $record->{ft_end_date};
            }
        }
    }

    foreach my $field ( qw( vol_ft_start vol_ft_end iss_ft_start iss_ft_end ) ) {
        if ( defined($record->{$field}) && $record->{$field} eq '-1' ) {
            delete $record->{$field};
        }
    }


    if ( defined( $record->{title} ) ) {
        $record->{title} =~ s/\([^\)]+?\)$//;
        $record->{title} = utf8( $record->{title} )->latin1;
    }

    if ( defined( $record->{'publisher'} ) ) {
        $record->{'publisher'} = ( utf8( $record->{'publisher'} ) )->latin1;
    }

    sub parse_date {
        my ($date) = @_;
        if ( my ( $month, $day, $year ) = $date =~ /(\w+)\s+(\d+)\s+(\d{4})/ )
        {
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
            return sprintf( "%04i-%02i-%02i", $year, $month, $day );
        }
        return undef;
    }
}

## --------------------------------------------------------------------------------------------

## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##

sub build_linkJournal {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkJournal');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkJournal');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkJournal');
        
    if ( is_empty_string( $resource->url_base ) ) {
        CUFTS::Exception::App->throw('No url_base set for resource');
    }

    my @results;

    foreach my $record (@$records) {

        next if is_empty_string( $record->issn   ) 
             && is_empty_string( $record->e_issn );

        my $url = $resource->url_base;
        $url .= '?genre=journal';
        if ( not_empty_string( $record->e_issn ) ) {
            $url .= '&eissn=' . $record->e_issn;
        }
        else {
            $url .= '&issn=' . $record->issn;
        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->issue  )
             && is_empty_string( $request->volume );
    
    return $class->SUPER::can_getTOC($request);
}

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->issue )
             || is_empty_string( $request->spage );

    return $class->SUPER::can_getTOC($request);
}

sub build_linkTOC {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkJournal');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkJournal');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkJournal');

    if ( is_empty_string( $resource->url_base ) ) {
        CUFTS::Exception::App->throw('No url_base set for resource');
    }

    my @results;

    foreach my $record (@$records) {

        next if is_empty_string( $record->issn   ) 
             && is_empty_string( $record->e_issn );

        my $url = $resource->url_base;
        $url .= '?genre=journal';
        if ( not_empty_string( $record->e_issn ) ) {
            $url .= '&eissn=' . $record->e_issn;
        }
        else {
            $url .= '&issn=' . $record->issn;
        }

        if ( not_empty_string( $request->issue ) ) {
            $url .= '&issue=' . $request->issue;
        }
        if ( not_empty_string( $request->volume ) ) {
            $url .= '&volume=' . $request->volume;
        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub build_linkFulltext {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkFulltext');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkFulltext');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkFulltext');

    if ( is_empty_string( $resource->url_base ) ) {
        CUFTS::Exception::App->throw('No url_base set for resource');
    }

    my @results;
    foreach my $record (@$records) {

        next if is_empty_string( $record->issn   ) 
             && is_empty_string( $record->e_issn );

        my $url = $resource->url_base;
        $url .= '?genre=article';
        if ( not_empty_string( $record->e_issn ) ) {
            $url .= '&eissn=' . $record->e_issn;
        }
        else {
            $url .= '&issn=' . $record->issn;
        }

        if ( not_empty_string( $request->volume ) ) {
            $url .= '&volume=' . $request->volume;
        }

        if ( not_empty_string( $request->issue ) ) {
            my $issue = $request->issue;
            $issue =~ s/^([0-9]+).*$/$1/;
            $url .= '&issue=' . $issue;
        }

        $url .= '&spage=' . $request->spage;

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;
