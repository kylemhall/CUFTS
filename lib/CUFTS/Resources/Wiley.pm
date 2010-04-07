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
use Data::Dumper;

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
        'title'         => 'title',
        'issn'          => 'issn',
        'e_issn'        => 'e_issn',
        'journal_url'   => 'journal_url',
        'Backfile Start Year'   => 'ft_start_date',
        'Backfile Start Volume' => 'vol_ft_start',
        'Backfile Start Issue'  => 'iss_ft_start',
        'Collection Start year / Start year for Current Sub'    => '___start',
        'Collection Start Volume / Start Vol for current Sub'   => '___vol_start',
    };
}

sub skip_record {
    my ( $class, $record ) = @_;

    return 1 if !defined( $record->{issn} );
    return 1 if $record->{issn} =~ /:99/;

    return 0;
}

sub clean_data {
    my ( $class, $record ) = @_;

    if ( defined($record->{issn}) && $record->{issn} =~ /:99/ ) {
        return ['Skipping due to non-fulltext backfile entry'];
    }

    if ( !defined( $record->{'___start'} ) ) {
        return ['Skipping due to missing holdings data'];
    }

    $record->{title} = trim_string( $record->{title}, '"' );
    $record->{title} =~ s/\(.*\)$//; 

    if ( defined($record->{e_issn}) && $record->{e_issn} !~ / \d{4} - \d{3}[\dxX] /xsm ) {
        delete $record->{e_issn};
    }

    if ( !defined($record->{ft_start_date}) && !defined($record->{vol_ft_start}) ) {
        $record->{ft_start_date} = $record->{'___start'};
        $record->{vol_ft_start} = $record->{'___vol_start'};
    }

    return $class->SUPER::clean_data($record);
}

1;
