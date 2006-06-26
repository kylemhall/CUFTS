## CUFTS::Resources::Extenza
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

package CUFTS::Resources::Extenza;

use base qw(CUFTS::Resources::GenericJournalDOI);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use strict;

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

sub overridable_resource_details {
    return undef;
}

sub title_list_field_map {
    return {
        'TITLE'         => 'title',
        'ISSN'          => 'issn',
        'EISSN'         => 'e_issn',
        'URL'           => 'journal_url',
        'FIRST ONLINE YEAR'   => 'ft_start_date',
        'FIRST ONLINE VOLUME' => 'vol_ft_start',
        'FIRST ONLINE ISSUE'  => 'iss_ft_start',
        'LAST ONLINE YEAR'    => 'ft_end_date',
        'LAST ONLINE VOLUME'  => 'vol_ft_end',
        'LAST ONLINE ISSUE'   => 'iss_ft_end'
    };
}

sub clean_data {
    my ( $class, $record ) = @_;

    $record->{title}       = trim_string($record->{title},       '"');
    $record->{journal_url} = trim_string($record->{journal_url}, '"');

    $record->{title} =~ s/\s+\(.+?\)$//;

    foreach my $field ( qw( vol_ft_start vol_ft_end iss_ft_start iss_ft_end ) ) {
        next if !defined($record->{$field});
        
        if ( $record->{$field} !~ /^\d+$/ ) {
            delete $record->{$field};
        }
        
    }

    return $class->SUPER::clean_data($record);
}

sub can_getTOC {
    return 0;
}

1;
