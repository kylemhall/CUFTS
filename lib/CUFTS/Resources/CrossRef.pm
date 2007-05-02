## CUFTS::Resources::CrossRef
##
## Copyright Todd Holbrook - Simon Fraser University (2004)
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

package CUFTS::Resources::CrossRef;

use base qw(CUFTS::Resources);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;
use CUFTS::DB::SearchCache;

use LWP::UserAgent;
use HTTP::Request::Common;

use strict;

sub has_title_list { return 0; }

sub local_resource_details       { return [ 'auth_name', 'auth_passwd' ] }
sub global_resource_details      { return [ 'auth_name', 'auth_passwd' ] }
sub overridable_resource_details { return [ 'auth_name', 'auth_passwd' ] }

sub help_template { return undef }

sub resource_details_help {
    return {
        auth_name   => 'Login name provided by CrossRef.',
        auth_passwd => 'Password provided by CrossRef.',
    };
}

sub get_records {
    my ( $class, $resource, $site, $request ) = @_;

    if ( is_empty_string( $resource->auth_name ) ) {
        CUFTS::Exception::App->throw('No auth_name defined for CrossRef lookups.');
    }
    if ( is_empty_string( $resource->auth_passwd ) ) {
        CUFTS::Exception::App->throw('No auth_passwd defined for CrossRef lookups.');
    }

    my $year = '';
    if ( defined( $request->date ) && $request->date =~ /^(\d{4})/ ) {
        $year = $1;
    }

    my ( $qdata, $qtype, $cache_query );

    if (   not_empty_string( $request->issn )
        || not_empty_string( $request->title ) )
    {
        $cache_query = $qdata = join(
            '|',
            (   'q',
                $request->issn   || '',
                $request->title  || '',
                $request->aulast || '',
                $request->volume || '',
                $request->issue  || '',
                $request->spage  || '',
                $year,
                $request->doi || '',
            )
        );

        $qdata = join(
            '|',
            (   $request->issn   || '',
                $request->title  || '',
                $request->aulast || '',
                $request->volume || '',
                $request->issue  || '',
                $request->spage  || '',
                $year,
                '',
                time,
                $request->doi || '',
            )
        );
        $qtype = 'q';

    }
    elsif ( not_empty_string( $request->doi ) ) {

        $qdata       = $request->doi;
        $qtype       = 'd';
        $cache_query = 'd|' . $request->doi;

    }
    else {
        return undef;
    }

    # Check the cache

    my $cache_data = CUFTS::DB::SearchCache->search(
        type    => 'crossref',
        'query' => $cache_query
    )->first;

    if ( !defined($cache_data) ) {

        # Lookup meta-data

        my $start_time = time;

        my $ua = LWP::UserAgent->new( 'timeout' => 20 );
        my $response = $ua->request(
            POST 'http://doi.crossref.org/servlet/query',
            [   'type'   => $qtype,
                'usr'    => $resource->auth_name,
                'pwd'    => $resource->auth_passwd,
                'area'   => 'live',
                'format' => 'piped',
                'qdata'  => $qdata,
            ]
        );

        $response->is_success or return undef;

        my $returned_data = trim_string( $response->content );

        print STDERR "CrossRef returned ("
            . ( time - $start_time )
            . "s): $returned_data\n";

        $cache_data = CUFTS::DB::SearchCache->create(
            {   type   => 'crossref',
                query  => $cache_query,
                result => $returned_data,
            }
        );
        CUFTS::DB::SearchCache->dbi_commit;
    }

    my ($issn,  $title,      $aulast,        $volume,
        $issue, $start_page, $crossref_year, $type,
        $key,   $doi,
        )
        = split /\|/, $cache_data->result;

    $doi =~ s/\n.+$//msx;  # Remove everything after the first DOI
    
    is_empty_string( $request->doi ) && not_empty_string($doi)
        and $request->doi($doi);

    is_empty_string( $request->aulast ) && not_empty_string($aulast)
        and $request->aulast($aulast);

    is_empty_string( $request->title ) && not_empty_string($title)
        and $request->title($title);

    if ( is_empty_string( $request->issn ) && not_empty_string($issn) ) {
        $issn =~ /^([\dxX]{8})/
            and $request->issn($1);
    }

    is_empty_string( $request->volume ) && not_empty_string($volume)
        and $request->volume($volume);

    is_empty_string( $request->issue ) && not_empty_string($issue)
        and $request->issue($issue);

    is_empty_string( $request->spage ) && not_empty_string($start_page)
        and $request->spage($start_page);

    return undef;
}

sub can_getMetadata {
    my ( $class, $request ) = @_;

    not_empty_string( $request->issn ) || not_empty_string( $request->eissn )
        and return 1;

    not_empty_string( $request->title )
        and return 1;

    not_empty_string( $request->doi )
        and return 1;

    return 0;
}

1;
