## CUFTS::Resources::Muse
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
##
## Modified 2004-04-19 by Michelle Gauthier:
##      (1) replaced 'urlbase' title list field with journal_url to reflect changes in JakeFilter module.
##      (2) deleted sub title_list_field_map since default field map inherited from base serves same purpose.
##

package CUFTS::Resources::Muse;

use base qw(CUFTS::Resources::Base::Journals);

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
            ft_end_date
            vol_ft_start
            vol_ft_end
            iss_ft_start
            iss_ft_end
            journal_url
            db_identifier
            publisher
        )
    ];
}

sub title_list_get_field_headings {
    return [
        qw(
            title
            db_identifier
            journal_url
            publisher
            e_issn
            issn
            ___preliminary_issue
            ___start
            ___end
        )
    ];
}

sub title_list_field_map {
    return {
        'title'         => 'title',
        'issn'          => 'issn',
        'e_issn'        => 'e_issn',
        'journal_url'   => 'journal_url',
        'db_identifier' => 'db_identifier',
        'publisher'     => 'publisher',
        'ft_start_date' => 'ft_start_date',
        'ft_end_date'   => 'ft_end_date',
    };
}

sub clean_data {
    my ( $class, $record ) = @_;

    # Some ISSNs are dirty and have extra spaces in them for some reason

    if ( defined( $record->{issn} ) ) {
        $record->{issn} =~ s/[^0-9xX]//g;
    }
    
    if ( defined( $record->{e_issn} ) ) {
        $record->{e_issn} =~ s/[^0-9xX]//g;
    }

    if ( defined( $record->{'___start'} )
        && $record->{'___start'} =~ / vol\. \s* (\d+) /xsmi )
    {
        $record->{vol_ft_start} = $1;
    }
    
    if ( defined( $record->{'___start'} )
        && $record->{'___start'} =~ / (?: no\. | issue ) \s* (\d+) /xsmi )
    {
        $record->{iss_ft_start} = $1;
    }
    
    if ( defined( $record->{'___end'} )
        && $record->{'___end'} =~ / vol\. \s* (\d+) /xsmi )
    {
        $record->{vol_ft_end} = $1;
    }
    
    if ( defined( $record->{'___end'} )
        && $record->{'___end'} =~ / (?: issue | no\. ) \s* (\d+) /xsmi )
    {
        $record->{iss_ft_end} = $1;
    }
    
    if ( defined( $record->{'___start'} )
        && $record->{'___start'} =~ / \( (.+) \s+ (\d{4}) .* \) /xsm )
    {
        my $month = $1;
        $record->{ft_start_date} = $2;
        if ( my $new_month = get_month($month) ) {
            $record->{ft_start_date} .= "-${new_month}";

        }
    }
    elsif ( defined( $record->{'___start'} )
        && $record->{'___start'} =~ / \( (\d{4}) .* \) /xsm )
    {
        $record->{ft_start_date} = $1;
    }
    elsif ( defined( $record->{'___start'} )
        && $record->{'___start'} =~ / ( (?: 19|20 ) \d{2} ) /xsm )
    {
        $record->{ft_start_date} = $1;
    }

    if ( defined( $record->{'___end'} )
        && $record->{'___end'} =~ / \( (.+) \s+ .* (\d{4}) \) /xsm )
    {
        my $month = $1;
        $record->{ft_end_date} = $2;
        if ( my $new_month = get_month($month) ) {
            $record->{'ft_end_date'} .= "-${new_month}";

        }
    }
    elsif ( defined( $record->{'___end'} )
        && $record->{'___end'} =~ / \( .* (\d{4}) \) /xsm )
    {
        $record->{ft_end_date} = $1;
    }
    elsif ( defined( $record->{'___end'} )
        && $record->{'___end'} =~ / ( (?: 19|20 ) \d{2} ) /xsm )
    {
        $record->{ft_end_date} = $1;
    }

    sub get_month {
        my $month = shift;

        if ( $month =~ /^\s*jan/i )    { return '01' }
        if ( $month =~ /^\s*feb/i )    { return '02' }
        if ( $month =~ /^\s*mar/i )    { return '03' }
        if ( $month =~ /^\s*apr/i )    { return '04' }
        if ( $month =~ /^\s*may/i )    { return '05' }
        if ( $month =~ /^\s*jun/i )    { return '06' }
        if ( $month =~ /^\s*jul/i )    { return '07' }
        if ( $month =~ /^\s*aug/i )    { return '08' }
        if ( $month =~ /^\s*sep/i )    { return '09' }
        if ( $month =~ /^\s*oct/i )    { return '10' }
        if ( $month =~ /^\s*nov/i )    { return '11' }
        if ( $month =~ /^\s*dec/i )    { return '12' }
        if ( $month =~ /^\s*spring/i ) { return '01' }
        if ( $month =~ /^\s*summer/i ) { return '03' }
        if ( $month =~ /^\s*fall/i )   { return '06' }
        if ( $month =~ /^\s*winter/i ) { return '09' }
    }

    return $class->SUPER::clean_data($record);
}

# ----------------------------------------------------------------------------------------------

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0
        if is_empty_string( $request->issue  )
        || is_empty_string( $request->volume );

    return $class->SUPER::can_getTOC($request);
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
        next if is_empty_string( $record->journal_url   );
        next if is_empty_string( $record->db_identifier );

        my $url = $record->journal_url;
        $url .= '/toc/'
            . $record->db_identifier
            . $request->volume . '.'
            . $request->issue . '.html';

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
