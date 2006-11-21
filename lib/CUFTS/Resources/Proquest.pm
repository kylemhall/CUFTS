## CUFTS::Resources::Proquest
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

package CUFTS::Resources::Proquest;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use URI::Escape qw(uri_escape);

use strict;

my $base_url = 'http://openurl.proquest.com/in?';

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
            db_identifier
        )
    ];
}

sub title_list_skip_lines_count { return 3 }

sub title_list_get_field_headings {
    my ( $class, $IN, $no_map ) = @_;
    my @headings;

    my $headings_array = $class->title_list_parse_row($IN);
    return undef if !defined($headings_array) || ref($headings_array) ne 'ARRAY';

    my @real_headings;
    foreach my $heading (@$headings_array) {
        if    ( $heading =~ /^Title/i )                { $heading = 'title'               }
        elsif ( $heading =~ /^ISSN/i )                 { $heading = 'issn'                }
        elsif ( $heading =~ /^Full\s+Text\s+First/i )  { $heading = 'ft_start_date'       }
        elsif ( $heading =~ /^Full\s+Text\s+Last/i )   { $heading = 'ft_end_date'         }
        elsif ( $heading =~ /^Page\s+Image\s+First/i ) { $heading = '___image_start_date' }
        elsif ( $heading =~ /^Page\s+Image\s+Last/i )  { $heading = '___image_end_date'   }
        elsif ( $heading =~ /^Citation\s+First/i )     { $heading = 'cit_start_date'      }
        elsif ( $heading =~ /^Citation\s+Last/i )      { $heading = 'cit_end_date'        }
        elsif ( $heading =~ /^Embargo\s+Days/i )       { $heading = 'embargo_days'        }
        elsif ( $heading =~ /PM\s*ID/ )                { $heading = 'db_identifier'       }
        else { $heading = "___$heading" }

        push @real_headings, $heading;
    }

    return \@real_headings;
}

sub clean_data {
    my ( $class, $record ) = @_;

    my @errors;

    defined( $record->{'ft_start_date'} )
        and $record->{'ft_start_date'} =~ s#(\d{2})/(\d{2})/(\d{4})#$3$1$2#;
    defined( $record->{'ft_end_date'} )
        and $record->{'ft_end_date'} =~ s#(\d{2})/(\d{2})/(\d{4})#$3$1$2#;

    if ( defined( $record->{'___image_start_date'} ) ) {
        $record->{'___image_start_date'} =~ s#(\d{2})/(\d{2})/(\d{4})#$3$1$2#;
        if ( !defined( $record->{'ft_start_date'} )
            || $record->{'___image_start_date'} < $record->{'ft_start_date'} )
        {
            $record->{'ft_start_date'} = $record->{'___image_start_date'};
        }
    }
    if ( defined( $record->{'___image_end_date'} ) ) {
        $record->{'___image_end_date'} =~ s#(\d{2})/(\d{2})/(\d{4})#$3$1$2#;
        if ( !defined( $record->{'ft_end_date'} ) ) {
            $record->{'ft_end_date'} = $record->{'___image_end_date'};
        }
        elsif (
            ( $record->{'ft_end_date'} !~ /current/i )
            && ( ( $record->{'___image_end_date'} =~ /current/i )
                || ( $record->{'___image_end_date'} > $record->{'ft_end_date'} ) )
            )
        {
            $record->{'ft_end_date'} = $record->{'___image_end_date'};
        }
    }

    defined( $record->{'cit_start_date'} )
        and $record->{'cit_start_date'} =~ s#(\d{2})/(\d{2})/(\d{4})#$3-$1-$2#;
    defined( $record->{'cit_end_date'} )
        and $record->{'cit_end_date'} =~ s#(\d{2})/(\d{2})/(\d{4})#$3-$1-$2#;

    if ( defined( $record->{'embargo_days'} ) ) {
        if ( $record->{'embargo_days'} =~ /ft=(\d+)/ ) {
            $record->{'embargo_days'} = $1;
        }
        elsif ( $record->{'embargo_days'} =~ /img=(\d+)/ ) {
            $record->{'embargo_days'} = $1;
        }
        elsif ( $record->{'embargo_days'} =~ /tg=(\d+)/ ) {
            $record->{'embargo_days'} = $1;
        }
        else {
            delete( $record->{'embargo_days'} );
        }
    }

    if ( defined( $record->{'ft_end_date'} ) && $record->{'ft_end_date'} =~ /current/i ) {
        delete( $record->{'ft_end_date'} );
    }
        
    if ( defined( $record->{'cit_end_date'} ) && $record->{'cit_end_date'} =~ /current/i ) {
        delete( $record->{'cit_end_date'} );
    }

    if ( defined( $record->{'ft_start_date'} ) ) {
        substr( $record->{'ft_start_date'}, 4, 0 ) = '-';
        substr( $record->{'ft_start_date'}, 7, 0 ) = '-';
    }

    if ( defined( $record->{'ft_end_date'} ) ) {
        substr( $record->{'ft_end_date'}, 4, 0 ) = '-';
        substr( $record->{'ft_end_date'}, 7, 0 ) = '-';
    }

    $record->{'title'} =~ s/\s*\(.+?\)\s*$//g;

    push @errors, @{ $class->SUPER::clean_data($record) };

    return \@errors;
}

sub overridable_resource_details {
    return undef;
}

sub help_template {
    return 'help/Proquest';
}

sub resource_details_help {
    return {};
}

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->spage );
    return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->volume );
    return $class->SUPER::can_getTOC($request);
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

        my %params = ( 'service' => 'pq' );

        if ( not_empty_string( $record->issn ) ) {
            $params{issn} = $record->issn;
        }
        else {
            $params{title} = uri_escape( $record->title );
        }

        ##
        ## Hack for Wall Street Journal - it doesn't have vol/iss indexed and 
        ## does not return results if you include them in the search.
        ##

        if ( $record->issn ne '00999660' ) {
            if ( not_empty_string( $request->volume ) ) {
                $params{volume} = $request->volume;
            }
            if ( not_empty_string( $request->issue ) ) {
                $params{issue} = $request->issue;
            }
        }

        if ( !exists( $params{volume} ) && !exists( $params{issue} ) ) {
            if ( not_empty_string( $request->day) ) {
                $params{date} = $request->date;
            }
            elsif ( not_empty_string( $request->year ) ) {
                $params{date} = $request->year;
            }
        }

        $params{spage} = $request->spage;

        if ( not_empty_string( $request->atitle ) ) {
            $params{atitle} = uri_escape( $request->atitle );
        }

        my $url = $base_url;
        $url .= join '&', map { $_ . '=' . $params{$_} } keys %params;

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
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

        my %params = ( 'service' => 'pq' );

        if ( not_empty_string( $record->issn ) ) {
            $params{issn} = $record->issn;
        }
        else {
            $params{title} = uri_escape( $record->title );
        }

        ##
        ## Hack for Wall Street Journal - it doesn't have vol/iss indexed and 
        ## does not return results if you include them in the search.
        ##

        if ( $record->issn ne '00999660' ) {
            if ( not_empty_string( $request->volume ) ) {
                $params{volume} = $request->volume;
            }
            if ( not_empty_string( $request->issue ) ) {
                $params{issue} = $request->issue;
            }
        }

        if ( !exists( $params{volume} ) && !exists( $params{issue} ) ) {
            if ( not_empty_string( $request->day) ) {
                $params{date} = $request->date;
            }
            elsif ( not_empty_string( $request->year ) ) {
                $params{date} = $request->year;
            }
        }

        if ( not_empty_string( $request->atitle ) ) {
            $params{atitle} = uri_escape( $request->atitle );
        }

        my $url = $base_url;
        $url .= join '&', map { $_ . '=' . $params{$_} } keys %params;

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
        my $url;
        if ( not_empty_string( $record->db_identifier ) ) {
            $url = 'http://openurl.proquest.com/openurl?url_ver=Z39.88-2004&res_dat=xri:pqd&rft_val_fmt=info:ofi/fmt:kev:mtx:journal&genre=issue&rft_dat=xri:pqd:PMID=';
            $url .= $record->db_identifier;
        }
        elsif ( not_empty_string( $record->issn ) ) {
            $url = 'http://gateway.proquest.com/openurl?ctx_ver=Z39.88-2003&res_id=xri:pqd&rft_val_fmt=ori:fmt:kev:mtx:journal&svc_id=xri:pqil:context=title&issn=';
            $url .= $record->issn;
        }
        else {
            $url = 'http://gateway.proquest.com/openurl?ctx_ver=Z39.88-2003&res_id=xri:pqd&rft_val_fmt=ori:fmt:kev:mtx:journal&svc_id=xri:pqil:context=title&title=';
            $url .= uri_escape( $record->title );
        }

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;
