## CUFTS::Resources::Gale3_III
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

package CUFTS::Resources::Gale_III;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use URI::Escape qw(uri_escape);

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
            embargo_days
        )
    ];
}

## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
    return {
        'Journal Name'   => 'title',
        'ISSN'           => 'issn',
        'Embargo (Days)' => 'embargo_days',
    };
}

sub overridable_resource_details {
        my ($class) = @_;

        my $details = $class->SUPER::overridable_resource_details();
        push @$details, 'url_base';

        return $details;
}

sub local_resource_details {
    my ($class) = @_;

    my $details = $class->SUPER::overridable_resource_details();
    push @$details, 'url_base';

    return $details;
}

sub skip_record {
    my ( $class, $record ) = @_;

    return is_empty_string( $record->{title} )
           || $record->{title} =~ /^\s*"?--/;
}



sub clean_data {
    my ( $class, $record ) = @_;

    my ( $ft_start_date, $ft_end_date ) = ( '0', '0' );

    if ( defined( $record->{'___Index Start'} )
        && $record->{'___Index Start'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        $record->{cit_start_date} = substr( $temp_date, 0, 4 ) . '-' . substr( $temp_date, 4, 2 );
    }
    elsif ( defined( $record->{'___Index Start'} )
        && $record->{'___Index Start'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $record->{cit_start_date} = sprintf( "%04i-%02i", $2, $1);
    }

    if ( defined( $record->{'___Index End'} )
        && $record->{'___Index End'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        $record->{cit_end_date} = substr( $temp_date, 0, 4 ) . '-' . substr( $temp_date, 4, 2 );
    }
    elsif ( defined( $record->{'___Index End'} )
        && $record->{'___Index End'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $record->{cit_end_date} = sprintf( "%04i-%02i", $2, $1);
    }

    # Gale can't seem to keep their columns consistent, so try an alternative

    if ( !exists($record->{'___Full-text Start'}) ) {
       $record->{'___Full-text Start'} = $record->{'___Full-Text Start'}
    }
    if ( !exists($record->{'___Full-text End'}) ) {
       $record->{'___Full-text End'} = $record->{'___Full-Text End'}
    }

    if ( defined( $record->{'___Full-text Start'} )
        && $record->{'___Full-text Start'} =~ /(\w{3})-(\d{2})/ )
    {
        $ft_start_date = get_date( $1, $2 );
    }
    elsif ( defined( $record->{'___Full-text Start'} )
        && $record->{'___Full-text Start'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $ft_start_date = sprintf( "%04i%02i", $2, $1);
    }

    if ( defined( $record->{'___Full-text End'} )
        && $record->{'___Full-text End'} =~ /(\w{3})-(\d{2})/ )
    {
        $ft_end_date = get_date( $1, $2 );
    }
    elsif ( defined( $record->{'___Full-text End'} )
        && $record->{'___Full-text End'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        $ft_end_date = sprintf( "%04i%02i", $2, $1);
    }

    # Check the Image dates to see if they are better than the fulltext ones

    if ( defined( $record->{'___Image Start'} )
        && $record->{'___Image Start'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        if ( int($temp_date) < int($ft_start_date) ) {
            $ft_start_date = $temp_date;
        }
    }
    elsif ( defined( $record->{'___Image Start'} )
        && $record->{'___Image Start'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        my $temp_date = sprintf( "%04i%02i", $2, $1);
        if ( int($temp_date) < int($ft_start_date) ) {
            $ft_start_date = $temp_date;
        }
    }

    if ( defined( $record->{'___Image End'} )
        && $record->{'___Image Start'} =~ /(\w{3})-(\d{2})/ )
    {
        my $temp_date = get_date( $1, $2 );
        if ( int($temp_date) > int($ft_end_date) ) {
            $ft_end_date = $temp_date;
        }
    }
    elsif ( defined( $record->{'___Image End'} )
        && $record->{'___Image End'} =~ /(\d{1,2})\/(\d{4})/ )
    {
        my $temp_date = sprintf( "%04i%02i", $2, $1);
        if ( int($temp_date) < int($ft_end_date) ) {
            $ft_end_date = $temp_date;
        }
    }

    if ( defined($ft_start_date) && $ft_start_date ne '0' ) {
        $record->{ft_start_date} = substr( $ft_start_date, 0, 4 ) . '-' . substr( $ft_start_date, 4, 2 );
    }
    if ( defined($ft_end_date) && $ft_end_date ne '0' ) {
        $record->{ft_end_date} = substr( $ft_end_date, 0, 4 ) . '-' . substr( $ft_end_date, 4, 2 );
    }

    $record->{title} =~ s/\s*\(.+?\)\s*$//g;

    return $class->SUPER::clean_data($record);

    sub get_date {
        my ( $month, $year ) = @_;

        if    ( $month =~ /^Jan/i ) { $month = 1 }
        elsif ( $month =~ /^Feb/i ) { $month = 2 }
        elsif ( $month =~ /^Mar/i ) { $month = 3 }
        elsif ( $month =~ /^Apr/i ) { $month = 4 }
        elsif ( $month =~ /^May/i ) { $month = 5 }
        elsif ( $month =~ /^Jun/i ) { $month = 6 }
        elsif ( $month =~ /^Jul/i ) { $month = 7 }
        elsif ( $month =~ /^Aug/i ) { $month = 8 }
        elsif ( $month =~ /^Sep/i ) { $month = 9 }
        elsif ( $month =~ /^Oct/i ) { $month = 10 }
        elsif ( $month =~ /^Nov/i ) { $month = 11 }
        elsif ( $month =~ /^Dec/i ) { $month = 12 }
        else {
            CUFTS::Exception::App->throw(
                "Unable to find month match in fulltext date: $month");
        }

        if ( int($year) > 20 ) {
            $year = "19$year";
        }
        else {
            $year = "20$year";
        }

        return sprintf( "%04i%02i", $year, $month );
    }
}

sub global_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::global_resource_details },
        qw(
            url_base
        )
    ];
}

sub local_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::local_resource_details },
        qw(
            proxy_suffix
        )
    ];
}

sub resource_details_help {
    return { $_[0]->SUPER::resource_details_help,
        'url_base' =>
            "Base URL for faking searches.\nExample:\nhttp://infotrac.galegroup.com/itw/infomark/1/1/1/purl=rc11_CPI_0_",
    };
}

sub overridable_resource_details {
    return undef;
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
        
        my $url = $resource->url_base;
        $url =~ s/rc11/rc18/;  # Makes link go to journal page rather than results list

        my $title = $record->title;
        $title =~ tr/ /+/;
        $title = uri_escape($title);
        $url .= "_jn+%22$title%22";

        $url .= __add_proxy_suffix($url, $resource->proxy_suffix);

        my $result = new CUFTS::Result($url);
        $result->record($record);
        push @results, $result;
    }

    return \@results;
}

# Fakes a search like this:
# http://infotrac.galegroup.com/itw/infomark/1/1/1/purl=rc11_LT_0_sn_0891-6330_AND_vo_16_AND_iu_4

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

    defined( $resource->url_base )
        or CUFTS::Exception::App->throw('No url_base defined for resource: ' . $resource->name);

    my @results;
    foreach my $record (@$records) {
        next if is_empty_string( $request->volume )
             && is_empty_string( $request->issue  );

        my $url = $resource->url_base;

        if ( is_empty_string($record->issn) ) {
            my $title = $record->title;
            $title =~ tr/ /+/;
            $title = uri_escape($title);
            $url .= "ke_jn+%22$title%22";
        }
        else {
            my $issn = $record->issn;
            substr( $issn, 4, 0 ) = '-';
            $url .= "ke_sn+$issn";
        }

        if ( not_empty_string($request->volume) ) {
            $url .= '+AND+vo+' . $request->volume;
        }

        if ( not_empty_string($request->issue) ) {
            $url .= '+AND+iu+' . $request->issue;
        }

        $url .= __add_proxy_suffix($url, $resource->proxy_suffix);

        my $result = new CUFTS::Result($url);
        $result->record($record);
        push @results, $result;
    }

    return \@results;
}

# Fakes a search like this:
# http://infotrac.galegroup.com/itw/infomark/1/1/1/purl=rc11_LT_0_sn_0891-6330_AND_vo_16_AND_iu_4

sub build_linkFulltext {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkTOC');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkTOC');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkTOC');

    defined( $resource->url_base )
        or CUFTS::Exception::App->throw('No url_base defined for resource: ' . $resource->name);

    my @results;
    foreach my $record (@$records) {
        next if is_empty_string( $request->volume )
             && is_empty_string( $request->issue  );

        my $url = $resource->url_base;
        next if is_empty_string( $request->url_base );
        
        if ( is_empty_string($record->issn) ) {
            my $title = $record->title;
            $title =~ tr/ /+/;
            $title = uri_escape($title);
            $url .= "ke_jn+%22$title%22";
        }
        else {
            my $issn = $record->issn;
            substr( $issn, 4, 0 ) = '-';
            $url .= "ke_sn+$issn";
        }

        if ( not_empty_string($request->volume) ) {
            $url .= '+AND+vo+' . $request->volume;
        }
    
        if ( not_empty_string($request->issue) ) {
            $url .= '+AND+iu+' . $request->issue;
        }

        if ( not_empty_string($request->spage) ) {
            $url .= '+AND+sp+' . $request->spage;
        }

#        if ( not_empty_string($request->atitle) ) { 
#            $url .= '+AND+ti+' . $request->atitle;
#        }

        $url .= __add_proxy_suffix($url, $resource->proxy_suffix);
        
        my $result = new CUFTS::Result($url);
        $result->record($record);
        push @results, $result;
    }

    return \@results;
}

sub __add_proxy_suffix {
    my ( $url, $suffix ) = @_;
    
    if ( not_empty_string( $suffix ) ) {
        # if the URL has a "?" in it already, then convert a leading ? from the suffix into a &

        if ( $url =~ /\?/ ) {  
            $suffix =~ s/^\?/&/;
        }
        return $suffix;
    }

    return '';
}

1;
