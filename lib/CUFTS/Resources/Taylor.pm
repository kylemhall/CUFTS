## CUFTS::Resources::Taylor
##
## Copyright Todd Holbrook - Simon Fraser University
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

package CUFTS::Resources::Taylor;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;
use URI::Escape qw(uri_escape);

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
            iss_ft_start
            iss_ft_end
        )
    ];
}

## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
    return {
        'Journal title'       => 'title',
        'Paperback ISSN'      => 'issn',
        'Electronic ISSN'     => 'e_issn',
        'Earliest Cover Date' => 'ft_start_date',
        'Latest Cover Date'   => 'ft_end_date',
        'Earliest Volume'     => 'vol_ft_start',
        'Earliest Issue'      => 'iss_ft_start',
        'Latest Volume'       => 'vol_ft_end',
        'Latest Issue'        => 'iss_ft_end',
        'URL'                 => 'journal_url',
    };
}

sub clean_data {
    my ( $class, $record ) = @_;
    
    my $year = (localtime())[5] + 1900;
    
    if ( defined($record->{ft_end_date}) && $record->{ft_end_date} >= ($year - 1) ) {
        delete $record->{ft_end_date};
        delete $record->{vol_ft_end};
        delete $record->{iss_ft_end};
    }

    return $class->SUPER::clean_data($record);
}

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->spage );

    return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0
        if is_empty_string( $request->issue )
        && is_empty_string( $request->volume );

    return $class->SUPER::can_getTOC($request);
}

# --------------------------------------------------------------------------------------------

## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##

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

    my @results;

    foreach my $record (@$records) {

        my $url = 'http://www.informaworld.com/openurl?genre=article';

        if ( not_empty_string( $request->doi ) ) {
            $url .= '&doi=' . uri_escape( $request->doi );
        }
        else {

            $url .= '&issn=' . dashed_issn( $record->issn );
            $url .= '&spage=' . $request->spage;

            if ( not_empty_string( $request->volume ) ) {
                $url .= '&volume=' . $request->volume;
            }
            if ( not_empty_string( $request->issue ) ) {
                $url .= '&issue=' . $request->issue;
            }

        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
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

    my @results;

    foreach my $record (@$records) {

        my $url = 'http://www.informaworld.com/openurl?genre=article';

        $url .= '&issn=' . dashed_issn( $record->issn );

        if ( not_empty_string( $request->volume ) ) {
            $url .= '&volume=' . $request->volume;
        }
        if ( not_empty_string( $request->issue ) ) {
            $url .= '&issue=' . $request->issue;
        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;
