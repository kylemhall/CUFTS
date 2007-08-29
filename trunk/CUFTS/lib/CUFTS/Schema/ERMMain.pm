## CUFTS::DB::ERMMain
##
## Copyright Todd Holbrook, Simon Fraser University (2003)
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

package CUFTS::Schema::ERMMain;

use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);

__PACKAGE__->table('erm_main');
__PACKAGE__->add_columns( qw(
    id
    key
    site
    license

    vendor
    publisher
    url
    resource_type
    resource_medium
    file_type
    description_brief
    description_full
    update_frequency
    coverage
    embargo_period
    simultaneous_users
    public
    public_list
    public_message
    subscription_status
    active_alert
    pick_and_choose
    marc_available
    marc_history
    marc_alert
    requirements
    maintenance
    title_list_url
    help_url
    status_url
    resolver_enabled
    refworks_compatible
    refworks_info_url
    user_documentation
    subscription_type
    subscription_notes
    subscription_ownership
    subscription_ownership_notes
    misc_notes

    cost_base
    cost_base_notes
    cost
    gst
    pst
    payment_status
    contract_start
    contract_end
    original_term
    auto_renew
    renewal_notification
    notification_email
    notice_to_cancel
    requires_review
    review_by
    review_notes
    local_bib
    local_vendor
    local_acquisitions
    local_fund
    consortia
    consortia_notes
    date_cost_notes
    pricing_model
    subscription
    price_cap
    license_start_date

    stats_available
    stats_url
    stats_frequency
    stats_delivery
    stats_counter
    stats_user
    stats_password
    stats_notes
    counter_stats

    open_access
    admin_subscription_no
    admin_user
    admin_password
    admin_url
    support_url
    access_url
    public_account_needed
    public_user
    public_password
    training_user
    training_password
    marc_url
    ip_authentication
    referrer_authentication
    referrer_url
    openurl_compliant
    access_notes
    breaches)
);                                                                                                        

__PACKAGE__->set_primary_key( 'id' );

1;

