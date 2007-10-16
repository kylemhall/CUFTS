## CUFTS::Schema::ERMMain
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
__PACKAGE__->add_columns(
    'id' => {
      'data_type' => 'integer',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_nullable' => 0,
      'size' => '11',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'key' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'site' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 0,
      'size' => '10',
    },
    'license' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'vendor' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'publisher' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'resource_type' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'resource_medium' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'file_type' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '255',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'description_brief' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'description_full' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'update_frequency' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'coverage' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'embargo_period' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'simultaneous_users' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'public_list' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0,
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'public' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'public_message' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'active_alert' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'pick_and_choose' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'marc_available' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'marc_history' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'marc_alert' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'requirements' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'maintenance' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'issn' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
  
    },
    'isbn' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
  
    },
    'title_list_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'help_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'status_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'resolver_enabled' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0,
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'refworks_compatible' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0,
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'refworks_info_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'user_documentation' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'subscription_type' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'subscription_status' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'print_included' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0,
      'default_can_view' => [ 'staff' ],
    },
    'subscription_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'subscription_ownership' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'subscription_ownership_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'misc_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'cost' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
    },
    'invoice_amount' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
    },
    'currency' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '3',
      'default_can_view' => [ 'staff' ],
    },
    'pricing_model' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10',
      'default_can_view' => [ 'staff' ],
    },
    'pricing_model_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000',
      'default_can_view' => [ 'staff' ],
    },
    'gst' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'pst' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'pst_amount' => {
        'data_type' => 'varchar',
        'size'      => 1024,
        'default_value' => undef,
        'is_nullable' => 1,
    },
    'gst_amount' => {
        'data_type' => 'varchar',
        'size'      => 1024,
        'default_value' => undef,
        'is_nullable' => 1,
    },
    'payment_status' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'contract_start' => {
      'data_type' => 'date',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'contract_end' => {
      'data_type' => 'date',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0,
      'default_can_view' => [ 'staff' ],
    },
    'original_term' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'auto_renew' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'renewal_notification' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10'
    },
    'notification_email' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'notice_to_cancel' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10'
    },
    'requires_review' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'review_by' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'review_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'local_bib' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'local_vendor' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
    },
    'local_acquisitions' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
    },
    'local_fund' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
  
    },
    'journal_auth' => {
        'data_type' => 'integer',
        'default_value' => undef,
        'is_nullable' => 1,
        'size' => '10',
    },
    'consortia' => {
      'data_type' => 'integer',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '10',
      'default_can_view' => [ 'patron', 'staff' ],
    },
    'consortia_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'date_cost_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'subscription' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'price_cap' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'license_start_date' => {
      'data_type' => 'date',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'stats_available' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'stats_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'stats_frequency' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'stats_delivery' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'stats_counter' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'stats_user' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'stats_password' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'stats_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'counter_stats' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'open_access' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024',
      'default_can_view' => [ 'staff' ],
    },
    'admin_subscription_no' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'admin_user' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'admin_password' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'admin_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'support_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'access_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'public_account_needed' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'public_user' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'public_password' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'training_user' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'training_password' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'marc_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'ip_authentication' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'referrer_authentication' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'referrer_url' => {
      'data_type' => 'varchar',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '1024'
    },
    'openurl_compliant' => {
      'data_type' => 'boolean',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => 0
    },
    'access_notes' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
    'breaches' => {
      'data_type' => 'text',
      'default_value' => undef,
      'is_nullable' => 1,
      'size' => '64000'
    },
);
__PACKAGE__->mk_group_accessors('column' => qw/ result_name sort_name rank / );

__PACKAGE__->set_primary_key( 'id' );

# Check the ResultSet for more predefined complex searches

__PACKAGE__->resultset_class('CUFTS::ResultSet::ERMMain');

__PACKAGE__->belongs_to( 'license' => 'CUFTS::Schema::ERMLicense', undef, { join_type => 'left outer' } );

__PACKAGE__->has_many( 'names'         => 'CUFTS::Schema::ERMNames',        'erm_main' );

__PACKAGE__->has_many( 'subjects_main'      => 'CUFTS::Schema::ERMSubjectsMain',     'erm_main' );
__PACKAGE__->has_many( 'content_types_main' => 'CUFTS::Schema::ERMContentTypesMain', 'erm_main' );

__PACKAGE__->many_to_many( 'content_types' => 'content_types_main', 'content_type' );
__PACKAGE__->many_to_many( 'subjects'      => 'subjects_main',      'subject'      );

__PACKAGE__->might_have( 'consortia'       => 'CUFTS::Schema::ERMConsortia'       );
__PACKAGE__->might_have( 'pricing_model'   => 'CUFTS::Schema::ERMPricingModels'   );
__PACKAGE__->might_have( 'resource_medium' => 'CUFTS::Schema::ERMResourceMediums' );
__PACKAGE__->might_have( 'resource_type'   => 'CUFTS::Schema::ERMResourceTypes'   );


1;

