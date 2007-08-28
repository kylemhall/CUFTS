## CUFTS::Resources::Wiley
##
## Copyright Todd Holbrook - Simon Fraser University (2005)
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

package CUFTS::Resources::Wiley;

use base qw(CUFTS::Resources::GenericJournalDOI);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

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
            vol_ft_start
            iss_ft_start
            ft_end_date
            vol_ft_end
            iss_ft_end
            journal_url
        )
    ];
}


sub title_list_field_map {
    return {
        'TITLE'       => 'title',
        'TITLE '      => 'title',
        'PRINT ISSN'  => 'issn',
        'ONLINE ISSN' => 'e_issn',
        'URL ON WIS'  => 'journal_url',
        'CEASED JOURNALS -- LAST VOL/ISS/YEAR PUBLISHED' => '___end',
        'PDF ON WIS STARTS WITH VOL/ISS/YEAR'            => '___start',
    };
}

sub skip_record {
    my ( $class, $record ) = @_;

    return 1 if !defined( $record->{issn} );
    return 1 if $record->{issn} =~ /:99/;
    return 1 if !defined( $record->{ft_start_date} );

    return 0;
}

sub clean_data {
    my ( $class, $record ) = @_;

    if ( $record->{'issn'} =~ /:99/ ) {
        return ['Skipping due to non-fulltext backfile entry'];
    }

    if ( !defined( $record->{'___start'} ) ) {
        return ['Skipping due to missing holdings data'];
    }

    $record->{title} = trim_string( $record->{title}, '"' );

    if ( $record->{e_issn} !~ / \d{4} - \d{3}[\dxX] /xsm ) {
        delete $record->{e_issn};
    }

    my ( $start_vol, $start_iss, $start_year ) = split /\s*\/\s*/, $record->{'___start'};

    if ( defined($start_vol) && $start_vol =~ / (\d+) \s* -? /xsm ) {
        $record->{vol_ft_start} = $1;
    }

    if ( defined($start_iss) && $start_iss =~ / (\d+) \s* -? /xs, ) {
        $record->{iss_ft_start} = $1;
    }

    if ( defined($start_year) && $start_year =~ / (\d{4}) /xsm ) {
        $record->{ft_start_date} = $1;
    }

    if ( defined( $record->{'___end'} ) ) {
        my ( $end_vol, $end_iss, $end_year ) = split /\s*\/\s*/, $record->{'___end'};
        
        if ( defined($end_vol) && $end_vol =~ / -? \s* (\d+) /xsm ) {
            $record->{vol_ft_end} = $1;
        }
    
        if ( defined($end_iss) && $end_iss =~ / -? \s* (\d+) /xsm ) {
            $record->{iss_ft_end} = $1;
        }
    
        if ( defined($end_year) && $end_year =~ / (\d{4}) /xsm ) {
            $record->{ft_end_date} = $1;
        }
    }

    return $class->SUPER::clean_data($record);
}

1;
