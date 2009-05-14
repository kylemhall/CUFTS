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

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0 unless defined( $request->issue ) && $request->issue =~ /^\d+$/;
    return 0 unless defined( $request->year )  && $request->year  =~ /^\d{4}$/;

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

    my @results;

    foreach my $record (@$records) {
        next if is_empty_string( $record->journal_url );

        my $url = $record->journal_url;
        $url .= '/'  . $request->year;
        $url .= '/v' . $request->volume;
        $url .= '/n' . $request->issue;
        $url .= '/index.html';

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
        next if is_empty_string( $record->journal_url );

        my $result = new CUFTS::Result( $record->journal_url );
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}


1;
