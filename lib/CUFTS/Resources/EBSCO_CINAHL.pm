## CUFTS::Resources::EBSCO::CINAHL
##
## Copyright Michelle Gauthier - Simon Fraser University (2003)
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

# PURPOSE:  for EBSCO hosted databases created by other sources

package CUFTS::Resources::EBSCO_CINAHL;

use base qw(CUFTS::Resources::EBSCO_Generic);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use strict;

sub title_list_fields {
    return [
        qw(
            id
            title
            issn
            ft_start_date
            ft_end_date
            cit_start_date
            cit_end_date
            embargo_months
            publisher
        )
    ];
}

sub title_list_field_map {
    return {
        'Publication Name'            => 'title',
        'ISSN'                        => 'issn',
        'Publisher'                   => 'publisher',
        'Full Text Delay (in months)' => 'embargo_months',
    };
}

sub clean_data {
    my ( $class, $record ) = @_;

    if ( defined( $record->{'___Full Text'} ) ) {

        if ( $record->{'___Full Text'} =~ m{^ \s* (\d{2}) / (\d{2}) / (\d{4}) }xsm ) {
            $record->{ft_start_date} = "$3/$1/$2";
        }
        elsif ( $record->{'___Full Text'} =~ m{^ \s* (\d{4}) }xsm ) {
            $record->{ft_start_date} = $1;
        }

    }

    if ( defined( $record->{'___Full Text'} ) ) {
    
        if ( $record->{'___Full Text'} =~ m{ to \s+ (\d{2}) / (\d{2}) / (\d{4}) \s* $}xsm ) {
            $record->{ft_end_date} = "$3/$1/$2";
        }
        elsif ( $record->{'___Full Text'} =~ m{ to \s+ (\d{4}) }xsm ) {
            $record->{ft_end_date} = $1;
        }

    }
    
    if ( defined( $record->{'___Searchable Cited References'} ) ) {
    
        if ( $record->{'___Searchable Cited References'} =~ m{^ \s* (\d{2}) / (\d{2}) / (\d{4}) }xsm ) {
            $record->{cit_start_date} = "$3/$1/$2";
        }
        elsif ( $record->{'___Searchable Cited References'} =~ m{^ \s* (\d{4}) }xsm ) {
            $record->{cit_start_date} = $1;
        }

    }
    
    if ( defined( $record->{'___Searchable Cited References'} ) ) {
    
        if ( $record->{'___Searchable Cited References'} =~ m{ to \s+ (\d{2}) / (\d{2}) / (\d{4}) }xsm ) {
            $record->{cit_end_date} = "$3/$1/$2";
        }
        elsif ( $record->{'___Searchable Cited References'} =~ m{ to \s+ (\d{4}) }xsm ) {
            $record->{cit_end_date} = $1;
        }

    }
    

    if ( defined( $record->{embargo_months} ) ) {
        $record->{embargo_months} = int( $record->{embargo_months} + 0.99 );
    }

    $record->{title}     = trim_string($record->{title},     '"');
    $record->{publisher} = trim_string($record->{publisher}, '"');

    return $class->SUPER::clean_data($record);

}

1;
