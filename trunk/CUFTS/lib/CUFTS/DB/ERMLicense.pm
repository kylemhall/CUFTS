## CUFTS::DB::ERMLicense
##
## Copyright Todd Holbrook, Simon Fraser University (2007)
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

package CUFTS::DB::ERMLicense;

use strict;
use base 'CUFTS::DB::DBI';


__PACKAGE__->table('erm_license');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
    id
    key
    site
    
    additional_requirements
    allowable_downtime
    allows_archiving
    allows_commercial_use
    allows_coursepacks
    allows_distance_ed
    allows_downloads
    allows_emails
    allows_ereserves
    ereserves_notes
    allows_ill
    allows_prints
    allows_proxy_access
    allows_remote_access
    allows_walkins
    archiving_notes
    citation_requirements
    contact_address
    contact_email
    contact_fax
    contact_name
    contact_notes
    contact_phone
    contact_role
    coursepack_notes
    emails_notes
    full_on_campus_access
    full_on_campus_notes
    ill_notes
    online_terms
    own_data
    perpetual_access
    perpetual_access_notes
    requires_print
    requires_print_plus
    termination_requirements
    terms_notes
    user_restrictions

));                                                                                                        
__PACKAGE__->columns(Essential => __PACKAGE__->columns);

__PACKAGE__->sequence('erm_license_id_seq');

1;
