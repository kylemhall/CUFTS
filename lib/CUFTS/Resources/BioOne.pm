## CUFTS::Resources::BioOne
##
## Copyright Michelle Gauthier - Simon Fraser University (2004-01-14)
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

package CUFTS::Resources::BioOne;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use strict;

my $url_base = 'http://www.bioone.org/bioone/?request=';

## title_list_fields - Controls what fields get displayed and loaded from
## title lists.

sub title_list_extra_requires {
    require Text::CSV;
}

sub title_list_fields {
    return [
        qw(
            id
            title
            issn
            ft_start_date
            vol_ft_start
            journal_url
            publisher
        )
    ];
}

## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
    return {
        'title'         => 'title',
        'issn'          => 'issn',
        'ft_start_date' => 'ft_start_date',
        'vol_ft_start'  => 'vol_ft_start',
        'journal_url'   => 'journal_url',
        'publisher'     => 'publisher',
    };
}

sub title_list_split_row {
    my ( $class, $row ) = @_;

    my $csv = Text::CSV->new();
    $csv->parse($row)
        or CUFTS::Exception::App->throw( 'Error parsing CSV line: ' . $csv->error_input() );

    my @fields = $csv->fields;
    return \@fields;
}

sub title_list_get_field_headings {
    return [
        qw(
            issn
            vol_ft_start
            ft_start_date
            title
            publisher
            journal_url
        )
    ];
}

sub clean_data {
    my ( $class, $request ) = @_;

    $request->{'title'} =~ s/^"//;
    $request->{'title'} =~ s/"$//;

    $request->{'publisher'} =~ s/^"//;
    $request->{'publisher'} =~ s/"$//;

    return $class->SUPER::clean_data($request);
}

## -------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0
        if is_empty_string( $request->volume )
        || is_empty_string( $request->spage  );

    return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0
        if is_empty_string( $request->volume )
        || is_empty_string( $request->issue  );

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
        next if is_empty_string( $record->issn );

        my $url = $url_base . 'get-document&issn=';
        $url .= substr( $record->issn, 0, 4 ) . '-' . substr( $record->issn, 4, 4 );
        $url .= '&volume=' . sprintf( "%03u", $request->volume );
        $url .= '&page=' . $request->spage;

        # Note: issue is not required

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
        or CUFTS::Exception::App->throw('No resource defined in build_linkTOC');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkTOC');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkTOC');

    my @results;

    foreach my $record (@$records) {
        next if is_empty_string( $record->issn );

        my $url = $url_base . 'get-toc&issn=';
        $url .= substr( $record->issn, 0, 4 ) . '-' . substr( $record->issn, 4, 4 );
        $url .= '&volume=' . sprintf( "%03u", $request->volume );
        $url .= '&issue=' . sprintf( "%02u",  $request->issue );

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

        next if is_empty_string( $record->issn );

        my $url = $url_base . 'get-journals-list&issn=';
        $url .= substr( $record->issn, 0, 4 ) . '-' . substr( $record->issn, 4, 4 );

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub build_linkDatabase {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkDatabase');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkDatabase');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkDatabase');
        
    my @results;

    foreach my $record (@$records) {

        my $url = $url_base . 'search-simple';

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;