## CUFTS::Resources::ElsevierEurope
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

package CUFTS::Resources::ElsevierEurope;

use base qw(CUFTS::Resources::Base::DOI CUFTS::Resources::Base::Journals);

use CUFTS::Util::Simple;
use HTML::Entities;

use strict;

sub title_list_fields {
    return [
        qw(
            id
            title
            issn
            ft_start_date
            vol_ft_start
            iss_ft_start
            ft_end_date
            vol_ft_end
            iss_ft_end
            publisher
            current_months
        )
    ];
}

sub help_template {
    return 'help/Elsevier';
}

sub resource_details_help {
    return {};
}

sub title_list_field_map {
    return {
        'Publication Name'       => 'title',
        'ISSN'                   => 'issn',
        'Publisher'              => 'publisher',
        'Coverage Begins Volume' => 'vol_ft_start',
        'Coverage Begins Issue'  => 'iss_ft_start',
        'Coverage Ends Volume'   => 'vol_ft_end',
        'Coverage Ends Issue'    => 'iss_ft_end',
        'Coverage Begins Date'   => 'ft_start_date',
        'Coverage Ends Date'     => 'ft_end_date',
    };
}

sub title_list_extra_requires {
    require Text::CSV;
}

sub title_list_split_row {
    my ( $class, $row ) = @_;

    $row =~ s/;+\s*$//;
    $row =~ s/"{2,3}/"/g;

    $row =~ s/"?;"?/;/g;
    $row =~ s/Subscribed,"Journal/Subscribed","Journal/;

    my $csv = Text::CSV->new();
    $csv->parse($row)
        or CUFTS::Exception::App->throw(
        'Error parsing CSV line: ' . $csv->error_input() );

    my @fields = $csv->fields;
    return \@fields;
}

sub clean_data {
    my ( $class, $record ) = @_;

    if ( $record->{ft_start_date} =~ / (\d+) - (\w+) - (\d+) /xsm ) {
        my ( $day, $month, $year ) = ( $1, $2, $3 );
        $month = get_month( $month, 'start' );
        $record->{ft_start_date} = sprintf( "%04d-%02d-%02d", $year, $month, $day );
    }
    else {
        delete $record->{ft_start_date};
    }

    if ( $record->{ft_end_date} =~ / (\d+) - (\w+) - (\d+) /xsm ) {

        my ( $day, $month, $year ) = ( $1, $2, $3 );
        
        # Remove end periods if the year matches the current year

        my $current_year = (localtime)[5] + 1900;
        if ( int($year) >= $current_year ) {
            
            delete $record->{iss_ft_end};
            delete $record->{vol_ft_end};
            delete $record->{ft_end_date};
            
        }
        else {
            $month = get_month( $month, 'end' );
            $record->{ft_end_date} = sprintf( "%04d-%02d-%02d", $year, $month, $day );
        }

    }
    else {
        delete $record->{ft_end_date};
    }

    if ( $record->{vol_ft_start} =~ /^ (\d+) - /xsm ) {
        $record->{vol_ft_start} = $1;
    }
    if ( $record->{iss_ft_start} =~ /^ (\d+) - /xsm ) {
        $record->{iss_ft_start} = $1;
    }
    if ( $record->{vol_ft_end} =~ / - (\d+) $/xsm ) {
        $record->{vol_ft_end} = $1;
    }
    if ( $record->{iss_ft_end} =~ / - (\d+) $/xsm ) {
        $record->{iss_ft_end} = $1;
    }

    $record->{title} = HTML::Entities::decode_entities( $record->{title} );

    sub get_month {
        my ( $month, $period ) = @_;

        if    ( $month =~ /^Jan/i ) { return 1 }
        elsif ( $month =~ /^Feb/i ) { return 2 }
        elsif ( $month =~ /^Mar/i ) { return 3 }
        elsif ( $month =~ /^Apr/i ) { return 4 }
        elsif ( $month =~ /^May/i ) { return 5 }
        elsif ( $month =~ /^Jun/i ) { return 6 }
        elsif ( $month =~ /^Jul/i ) { return 7 }
        elsif ( $month =~ /^Aug/i ) { return 8 }
        elsif ( $month =~ /^Sep/i ) { return 9 }
        elsif ( $month =~ /^Oct/i ) { return 10 }
        elsif ( $month =~ /^Nov/i ) { return 11 }
        elsif ( $month =~ /^Dec/i ) { return 12 }
        elsif ( $month =~ /^Spr/i ) { return $period eq 'start' ? 1 : 6 }
        elsif ( $month =~ /^Sum/i ) { return $period eq 'start' ? 3 : 9 }
        elsif ( $month =~ /^Fal/i ) { return $period eq 'start' ? 6 : 12 }
        elsif ( $month =~ /^Aut/i ) { return $period eq 'start' ? 6 : 12 }
        elsif ( $month =~ /^Win/i ) { return $period eq 'start' ? 9 : 12 }
        else {
            CUFTS::Exception::App->throw("Unable to find month match in fulltext date: $month");
        }
    }

    return $class->SUPER::clean_data($record);
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

        my $result = new CUFTS::Result;
        $result->url('http://www.sciencedirect.com/science/journal/' . $record->issn );
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;