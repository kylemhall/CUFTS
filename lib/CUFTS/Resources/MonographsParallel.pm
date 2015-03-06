## CUFTS::Resources::MonographsParallel
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

package CUFTS::Resources::MonographsParallel;

use base qw(CUFTS::Resources::Base::Monographs);
use CUFTS::Exceptions;
use CUFTS::Util::Simple;
use CUFTS::Result;

use strict;

sub services {
    return [ qw( holdings ) ];
}

sub local_resource_details {
    return [qw(url_base)];
}

sub get_records {
    my ( $class, $schema, $resource, $site, $request ) = @_;
    return [ { id => 'dummy record' } ];
}

sub search_getHoldings {
    return shift->get_records( @_ );
}

sub build_linkHoldings {
    my ( $class, $schema, $records, $resource, $site, $request ) = @_;

    my $url = 'http://api.lib.sfu.ca/';
    my $result = new CUFTS::Result(
        {
            url => $url,
            extra_data => {
                targets => [
                    {
                        'id'   => 'BVAS',
                        'name' => 'Simon Fraser University',
                        'url'  => 'http://api.lib.sfu.ca/holdings_search/search',
                    },
                    {
                        'id'   => 'ALU',
                        'name' => 'University of Alberta',
                        'url'  => 'http://api.lib.sfu.ca/holdings_search/search',
                    },
                ],
            },
        }
    );


    return [ $result ];
}

1;
