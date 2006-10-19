## CUFTS::Resources::Blackwell
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

package CUFTS::Resources::Blackwell;

use base qw(CUFTS::Resources::GenericJournalDOI);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;
use Date::Calc qw(Delta_Days Today);

use strict;

## title_list_fields - Controls what fields get displayed and loaded from
## title lists.

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

            embargo_months
            embargo_days

            journal_url
        )
    ];
}

## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
    return {
        'Print ISSN'   => 'issn',
        'Online ISSN'  => 'e_issn',
        'Publication'  => 'title',
        'URL'          => 'journal_url',
    };
}

## global_resource_details - Controls which details are displayed on the global
## resource pages
##

sub global_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::global_resource_details },
        qw(
            resource_identifier
            database_url
            url_base
        )
    ];
}

## local_resource_details - Controls which details are displayed on the local
## resource pages
##

sub local_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::local_resource_details },
        qw(
            resource_identifier
            database_url
            url_base
            auth_name
            auth_passwd
        )
    ];
}

## overridable_resource_details - Controls which of the *global* resource details
## are displayed on the *local* resource pages to possibly be overridden
##

sub overridable_resource_details {
    my ($class) = @_;
    return [
        @{ $class->SUPER::overridable_resource_details },
        qw(
            resource_identifier
            database_url
            url_base
            auth_name
            auth_passwd
            )
    ];
}

sub title_list_skip_lines_count { return 1; }

sub clean_data {
    my ( $class, $record ) = @_;
    
    if ( $record->{'___First Online Issue'} =~ / Vol\. \s+ ([^,]+), \s+ No\. \s+ ([^,]+), (.+) /xsm ) {
        my ( $vol, $no, $date ) = ( $1, $2, $3 );

        # Parse out vol varients: 1   1-2   1&2   s1
        $record->{vol_ft_start}  = parse_vol_iss($vol, 0);
        $record->{iss_ft_start}  = parse_vol_iss($no,  0);
        $record->{ft_start_date} = parse_date($date, 0); 

    }
    elsif ( $record->{'___First Online Issue'} ne 'Online early issue' ) {
        warn("Unable to parse holding line: " . $record->{'___First Online Issue'} );
    }

    if ( $record->{'___Last Online Issue'} =~ / Vol\. \s+ ([^,]+), \s+ No\. \s+ ([^,]+), (.+) /xsm ) {
        my ( $vol, $no, $date ) = ( $1, $2, $3 );

        # Parse out vol varients: 1   1-2   1&2   s1
        $record->{vol_ft_end}  = parse_vol_iss($vol, 1);
        $record->{iss_ft_end}  = parse_vol_iss($no,  1);
        $record->{ft_end_date} = parse_date($date, 1);
        if ( !defined($record->{ft_end_date}) ) {
            delete $record->{vol_ft_end};
            delete $record->{iss_ft_end};
        }

    }
    elsif ( $record->{'___Last Online Issue'} ne 'Online early issue' ) {
        warn("Unable to parse holding line: " . $record->{'___Last Online Issue'} );
    }

    return $record;
}


sub parse_vol_iss {
    my ( $string, $end ) = @_;

    # Parse out varients: 1   1-2   1&2   s1
    
    $string =~ tr/a-zA-Z//;
    my @vals = split /[^\d]/, $string;
    
    return $end ? $vals[$#vals] : $vals[0];
}
    

sub parse_date {
    my ( $string, $end ) = @_;
    
    if ( $string =~ /^ \s* (.*) \s+ (\d{4}) /xsm ) {
        my ( $month, $year ) = ( $1, $2 );
        
        my @months = split /[^a-z]+/, lc($month);
        $month = $end ? $months[$#months] : $months[0];
        my $numeric_month;

        if ( !defined($month) ) {
            $month = ''
        };

        if    ( $month =~ /^\s*jan/i )     { $numeric_month =  '01' }
        elsif ( $month =~ /^\s*feb/i )     { $numeric_month =  '02' }
        elsif ( $month =~ /^\s*mar/i )     { $numeric_month =  '03' }
        elsif ( $month =~ /^\s*a[pv]r/i )  { $numeric_month =  '04' }
        elsif ( $month =~ /^\s*may/i )     { $numeric_month =  '05' }
        elsif ( $month =~ /^\s*jun/i )     { $numeric_month =  '06' }
        elsif ( $month =~ /^\s*jul/i )     { $numeric_month =  '07' }
        elsif ( $month =~ /^\s*aug/i )     { $numeric_month =  '08' }
        elsif ( $month =~ /^\s*sep/i )     { $numeric_month =  '09' }
        elsif ( $month =~ /^\s*oct/i )     { $numeric_month =  '10' }
        elsif ( $month =~ /^\s*nov/i )     { $numeric_month =  '11' }
        elsif ( $month =~ /^\s*dec/i )     { $numeric_month =  '12' }
        else {
            $numeric_month = $end ? 12 : 1;
        }
        my $day = $end ? ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 )[$numeric_month - 1] : '01';

        my $date = "$year-$numeric_month-$day";
        if ( !$end ) {
            return $date;

        }
        
        if ( Delta_Days( $year, $numeric_month, $day, Today() ) > 180 ) {
            return $date
        }
        else {
            return undef;
        }
    }
    else {
        warn("Unable to parse date from: $string");
        return undef;
    }
    
}

1;
