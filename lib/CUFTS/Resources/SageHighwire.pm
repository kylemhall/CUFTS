## CUFTS::Resources::SageHighwire.pm
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

package CUFTS::Resources::SageHighwire;

use base qw(CUFTS::Resources::Base::Journals);

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
            ft_end_date
            vol_ft_start
            vol_ft_end
            iss_ft_start
            iss_ft_end
            journal_url
            db_identifier
        )
    ];
}

sub title_list_field_map {
    return {
        'Title'                 => 'title',
        'ISSN'                  => 'issn',
        'E-ISSN'                => 'e_issn',
        'URL'                   => 'journal_url',
        'First Volume'          => 'vol_ft_start',
        'First Issue Number'    => 'iss_ft_start',
        'Latest Volume'         => 'vol_ft_end',
        'Latest Issue Number'   => 'iss_ft_end',
        'SAGE Pub Code'         => 'db_identifier',
    }
}

sub clean_data {
    my ( $class, $record ) = @_;
    
    $record->{ft_start_date} = sprintf( '%4i-%02i', $record->{'___First Year'}, $record->{'___First Month'} );
    $record->{ft_end_date}   = sprintf( '%4i-%02i', $record->{'___Latest Year'}, $record->{'___Latest Month'} );

    return $class->SUPER::clean_data($record);
}



## -------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0
        if     is_empty_string( $request->spage  ) 
            || is_empty_string( $request->volume )    
            || is_empty_string( $request->issue  );
       
    return $class->SUPER::can_getFulltext($request);
}


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
        my $dir = 'reprint';
        my $url = $record->journal_url . '/cgi/' . $dir . '/';

        $url .= $request->volume . '/'
              . $request->issue  . '/'
              . $request->spage;

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}


1;
