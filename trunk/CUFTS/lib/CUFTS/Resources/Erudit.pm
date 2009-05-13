## CUFTS::Resources::Erudit
##
## Copyright Todd Holbrook - Simon Fraser University (2003-11-04)
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

package CUFTS::Resources::Erudit;

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
            title
            issn
            e_issn
            journal_url
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
        'TITLE'			=> 'title',
        'ISSN PRINT'	=> 'issn',
        'ISSN DIGITAL'	=> 'e_issn',
        'JOURNAL URL'	=> 'journal_url',
        'YEAR FIRST'	=> 'ft_start_date',
        'YEAR LAST'		=> 'ft_end_date',
        'VOLUME FIRST'	=> 'vol_ft_start',
        'VOLUME LAST'	=> 'vol_ft_end',
        'ISSUE FIRST'	=> 'iss_ft_start',
        'ISSUE LAST'	=> 'iss_ft_end'
    };
}

sub title_list_split_row {
    my ( $class, $row ) = @_;

    my @fields = split /\|/, $row;

    return \@fields;
}

sub clean_data {
    my ( $class, $record ) = @_;
    
    return $class->SUPER::clean_data($record);
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
        )
    ];
}

sub local_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::local_resource_details },
        qw(
            auth_name
        )
    ];
}

## help_template - path to the help template for this resource relative to the
## general templates directory
##

sub help_template {
    return 'help/Wilson';
}

## resource_details_help - A hash ref containing the hoverover help for each of the
## local resource details
##

sub resource_details_help {
    return {
        'resource_identifier' =>
            'This is a code that Wilson uses to uniquely identify '
            . "each database. \n\nExample: BAIN is the resource identifier for "
            . 'Biological and Agricultural Index Plus',

        'auth_name' =>
            'If there is a need to disambiguate overlapping TCP/IP ranges for sites '
            . 'that may be members of multiple customer accounts in the authentication database, use '
            . 'if no other automatic login method is enabled, can be used to supply the '
            . "login username, in conjunction with the authorize password field below.\n\n"
            . 'Caution: values appear as plain text in browser address bar.'
    };
}

## -------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->spage  )
             && is_empty_string( $request->atitle );
             
    return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->volume );
    
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

        my $url = 'http://vnweb.hwwilsonweb.com/hww/jumpstart.jhtml?';

        # if username provided, use it in the url
        if ( not_empty_string( $resource->auth_name ) ) {
            $url .= 'CustID=' . $resource->auth_name . '&';
        }

        $url .= 'genre=article&sid=HWW:' . $resource->resource_identifier;
        $url .= not_empty_string( $record->issn )
                ? '&issn='  . dashed_issn( $record->issn )
                : '&title=' . uri_escape( $record->title );

        if ( $request->spage ) {
            $url .= '&volume=' . $request->volume
                  . '&issue='  . $request->issue
                  . '&spage='  . $request->spage;
        }
        else {
            $url .= '&atitle=' . uri_escape( $request->atitle );
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

        my $url = 'http://vnweb.hwwilsonweb.com/hww/jumpstart.jhtml?';

        # if username provided, use it in the url
        if ( not_empty_string( $resource->auth_name) ) {
            $url .= 'CustID=' . $resource->auth_name . '&';
        }

        $url .= 'genre=journal&sid=HWW:' . $resource->resource_identifier;

        $url .= not_empty_string( $record->issn )
                ? '&issn='  . dashed_issn( $record->issn )
                : '&title=' . uri_escape( $record->title );

        $url .= '&volume=' . $request->volume;
        if ( not_empty_string( $request->issue ) ) {
            $url .= '&issue='  . $request->issue if $request->issue;
        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

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

    my @results;

    foreach my $record (@$records) {

	my $url = 'http://vnweb.hwwilsonweb.com/hww/Journals/searchAction.jhtml?';

        # if username provided, use it in the url
        if ( not_empty_string( $resource->auth_name) ) {
            $url .= 'CustID=' . $resource->auth_name . '&';
        }

	$url .= 'sid=HWW:' . $resource->resource_identifier;
	$url .= not_empty_string( $record->issn )
		? '&issn='  . dashed_issn( $record->issn )
		: '&title=' . uri_escape( $record->title );

	my $result = new CUFTS::Result($url);
	$result->record($record);

	push @results, $result;
    }

    return \@results;
}

1;
