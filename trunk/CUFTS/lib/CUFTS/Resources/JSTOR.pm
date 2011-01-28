## CUFTS::Resources::JSTOR
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

package CUFTS::Resources::JSTOR;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;
use URI::Escape qw(uri_escape);
use Unicode::String qw(utf8);

use strict;


my $base_url = 'http://makealink.jstor.org/public-tools/GetURL?';

sub title_list_extra_requires {
    # require CUFTS::Util::CSVParse;
    require Text::CSV_XS;
    require HTML::Entities;
}

sub title_list_fields {
    return [
        qw(
            id
            title
            issn
            ft_start_date
            ft_end_date
            journal_url
            publisher
        )
    ];
}

sub title_list_field_map {
    return {
        'publication_title'     => 'title',
        'issn'                  => 'issn',
        'publication_url'       => 'journal_url',
        'publisher'             => 'publisher',
        'coverage_start_date'   => 'ft_start_date',
        'coverage_end_date'     => 'ft_end_date',
    };
}

sub clean_data {
    my ( $class, $record ) = @_;

    my %month_mapping = (
        '20' => '01',
        '21' => '01',
        '22' => '03',
        '23' => '06',
        '24' => '09',
        '25' => '01',
        '26' => '02',
        '27' => '06',
        '28' => '07',
        '29' => '09',
        '30' => '10',
        '31' => '01',
        '32' => '03',
        '33' => '06',
        '34' => '09',
    );

    if ( defined( $record->{ft_start_date} )
        && $record->{ft_start_date} =~ / (\d{4}) (\d{2})? (\d{2})? /xsm )
    {

        my ( $year, $month, $day ) = ( $1, $2, $3 );
        $record->{ft_start_date} = $year;

        if ( defined($month) ) {

            if ( $month > 12 ) {
                $month = $month_mapping{$month};
            }

            $record->{ft_start_date} .= "-${month}";

            if ( defined($day) ) {
                $record->{ft_start_date} .= "-$day";
            }

        }

    }

    if ( defined( $record->{ft_end_date} )
        && $record->{ft_end_date} =~ / (\d{4}) (\d{2})? (\d{2})? /xsm )
    {

        my ( $year, $month, $day ) = ( $1, $2, $3 );
        $record->{ft_end_date} = $year;

        if ( defined($month) ) {

            if ( $month > 12 ) {
                $month = int( $month_mapping{$month} ) + 3;
                $month > 12 and $month = 12;
                $month = sprintf( "%02i", $month );
            }

            $record->{ft_end_date} .= "-${month}";

            if ( defined($day) ) {
                $record->{ft_end_date} .= "-$day";
            }

        }

    }

    if ( $record->{___has_current_available} =~ /yes/ixsm ) {
        if ( $record->{___moving_wall} =~ / moving\s+wall: \s* (\d+) /ixsm ) {
            my $year = (localtime)[5] + 1900;
            $record->{ft_end_date} = $year - 1 - int($1);
        }
        elsif ( $record->{___moving_wall} =~ /(\d{4})/ ) {
            # Try for a year if it doesn't have a matchable "Moving Wall: ..."
            $record->{ft_end_date} = $1;
        }
        else {
            # Remove all fulltext info, it's probably a "bad" record
            delete $record->{ft_start_date};
            delete $record->{ft_end_date};
        }
    } 

    if ( $record->{issn} =~ /none/xsmi ) {
        delete $record->{issn};
    }

    $record->{title}     = HTML::Entities::decode_entities( $record->{title} );
    $record->{publisher} = HTML::Entities::decode_entities( $record->{publisher} );

    $record->{title}     = utf8( $record->{title}     )->latin1;
    $record->{publisher} = utf8( $record->{publisher} )->latin1;

    return $class->SUPER::clean_data($record);

}

# sub title_list_split_row {
#     my ( $class, $row ) = @_;
# 
#     my $csv = CUFTS::Util::CSVParse->new();
#     $csv->parse($row)
#         or CUFTS::Exception::App->throw('Error parsing CSV line: ' . $csv->error_input() );
# 
#     my @fields = $csv->fields;
#     return \@fields;
# }

sub title_list_split_row {
    my ( $class, $row ) = @_;
    
    my $csv = Text::CSV_XS->new({ binary => 1, escape_char => '\\' });
    $csv->parse($row)
        or CUFTS::Exception::App->throw('Error parsing CSV line: ' . $csv->error_input() );

    my @fields = $csv->fields;
    return \@fields;
}


# -----------------------------------------------------------------------

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->spage );
    return 0 if is_empty_string( $request->volume );
    return $class->SUPER::can_getFulltext($request);
}

sub build_linkFulltext {
    my ( $class, $records, $resource, $site, $request ) = @_;

    my @skip_issue_in_sici = qw( 00664162 1543592X );

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

        # Build a SICI for linking
        
        # http://links.jstor.org/sici?sici=0090-5364%28198603%2914%3A1%3C1%3AOTCOBE%3E2.0.CO%3B2-U
        # Abstract from Lynch, Clifford A. “The Integrity of Digital Information; Mechanics and Definitional Issues.” JASIS 45:10 (Dec. 1994) p. 737-44
        # 0002-8231(199412)45:10<737:TIODIM>2.3.TX;2-M
        # http://makealink.jstor.org/public-tools/GetURL?volume=54&issue=8&date=19701201&journal_title=00267902&page=562
        # http://links.jstor.org/sici?sici=00267902%281970%2954:8%3A8%3C562%3E2.3.TX
        
        my $sici = $record->issn;
        
        $sici .= '(' . $request->year . $request->month . ')';
        $sici .= $request->volume;
        if ( defined( $request->issue ) && !grep { $_ eq $record->issn } @skip_issue_in_sici ) {
            $sici .= ':' . $request->issue;
        }
        $sici .= '<' . $request->spage . '>';
        $sici .= '2.3.TX';  # ??

        my $url = 'http://links.jstor.org/sici?sici=' . uri_escape($sici);

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0;   # Turn off for now until I can figure out if it works with SICI style links

    return 0
        if is_empty_string( $request->volume )
        || is_empty_string( $request->issue  )
        || is_empty_string( $request->date   );

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
        next if is_empty_string( $record->issn );

        my @params;
        if ( not_empty_string($request->volume) ) {
            push @params, 'volume=' . $request->volume;
        }
        if ( not_empty_string($request->issue) ) {
            push @params, 'issue=' . $request->issue;
        }

        if (     is_empty_string( $request->volume ) 
             &&  is_empty_string( $request->issue  )
             && not_empty_string( $request->date   ) )
        {
            push @params, 'date=' . $request->date;
        }

        push @params, 'issn=' . $record->issn;

        my $url = $base_url;
        $url .= join '&', @params;

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
        
        my $url = $record->journal_url;
        if ( is_empty_string($url) ) {
            next if is_empty_string( $record->issn );
            $url = 'http://www.jstor.org/journals/' . $record->issn . '.html';
        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;
