## CUFTS::DB::ERMMain
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

package CUFTS::DB::ERMMain;

use strict;
use base 'CUFTS::DB::DBI';

use Data::Dumper;

__PACKAGE__->table('erm_main');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
    id
    key
    site
    license

    vendor
    publisher
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

    cost_base
    cost_base_notes
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
    review_notes
    local_bib
    local_vendor
    local_acquisitions
    consortia
    consortia_note
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
    breaches
));                                                                                                        

__PACKAGE__->columns( Essential => __PACKAGE__->columns );
__PACKAGE__->columns( TEMP => qw( result_name rank ) );
__PACKAGE__->has_a('consortia', 'CUFTS::DB::ERMConsortia');
__PACKAGE__->has_a('cost_base', 'CUFTS::DB::ERMCostBases');
__PACKAGE__->has_a('resource_medium', 'CUFTS::DB::ERMResourceMediums');
__PACKAGE__->has_a('resource_type', 'CUFTS::DB::ERMResourceTypes');
__PACKAGE__->has_many('subjects', ['CUFTS::DB::ERMSubjectsMain' => 'subject'], 'erm_main');
__PACKAGE__->has_many('content_types', ['CUFTS::DB::ERMContentTypesMain' => 'content_type'], 'erm_main');
__PACKAGE__->has_many('names',    ['CUFTS::DB::ERMNames' => 'name'],           'erm_main');

__PACKAGE__->sequence('erm_main_id_seq');

sub main_name {
    my ( $self, $new_name ) = @_;
    
    my $name_record = CUFTS::DB::ERMNames->search({
        erm_main => $self->id,
        main     => 1,
    })->first;

    if ( defined($new_name) ) {

        if ( defined($name_record) ) {
            if ( $name_record->name ne $new_name ) {
                $name_record->name( $new_name );
                $name_record->search_name( CUFTS::DB::ERMNames->strip_name( $new_name ) );
                $name_record->update;
            }
        }
        else {
            $name_record = CUFTS::DB::ERMNames->create({
                name        => $new_name,
                search_name => CUFTS::DB::ERMNames->strip_name($new_name),
                erm_main    => $self->id,
                main        => 1,
            });
        }
    }

    return defined($name_record) ? $name_record->name : undef;
}

sub name {
    my ( $self ) = @_;
    
    if ( defined($self->result_name) ) {
        return $self->result_name;
    }

    return $self->main_name;
}


sub facet_search {
    my ( $class, $site, $fields, $offset, $limit ) = @_;

    my $config = {
        joins  => '',
        order  => [ 'sort_name' ],    # Default order by resource name
        extra_columns => {
            'sort_name'   => 'erm_names.search_name',
            'result_name' => 'erm_names.name',
        },
        replace_columns => {
        },
        search => {
            site => $site,
        },
    };
    
    my $sql = qq{
        SELECT *
        FROM (
            SELECT DISTINCT ON (erm_names.erm_main) %COLUMNS%
            FROM erm_main
            JOIN erm_names ON (erm_names.erm_main = erm_main.id)
            %JOINS%
            %WHERE%
            ORDER BY erm_names.erm_main, erm_names.main DESC
        ) AS erm_results
        ORDER BY %ORDER%
    };

    foreach my $field ( keys %$fields ) {

        my $handler = "_facet_search_$field";
        if ( $class->can($handler) ) {
            $class->$handler( $field, $fields->{$field}->{data}, $config, \$sql );
        }
        else {
            # default
            $config->{search}->{$field} = $fields->{$field}->{data};
        }

    }
    
    my $SQLAbstract = SQL::Abstract->new;
    my ( $where, @bind ) = $SQLAbstract->where( $config->{search} );

    # Untaint $where
    $where =~ /(.*)/s or die;
    $where = $1;
    
    # Build column list
    
    my @columns;
    foreach my $column ( __PACKAGE__->columns ) {
        if ( exists($config->{replace_columns}->{$column} ) ) {
            push @columns, $config->{replace_columns}->{$column};
        }
        else {
            push @columns, "erm_main.${column}";
        }
    }

    foreach my $column ( keys %{ $config->{extra_columns} } ) {
        my $string = $config->{extra_columns}->{$column} . ' AS ' . $column;
        push @columns, $string;
    }

    $sql =~ s/%WHERE%/$where/e;
    $sql =~ s/%JOINS%/$config->{'joins'}/e;
    $sql =~ s/%ORDER%/join( ', ', @{ $config->{'order'} } )/e;
    $sql =~ s/%COLUMNS%/join( ', ', @columns )/e;

    warn($sql);

    my $sth = $class->db_Main()->prepare( $sql, {pg_server_prepare => 1} );
    my @results = $class->sth_to_objects( $sth, \@bind );
    return \@results;
}

sub _facet_search_name {
    my ( $class, $field, $data, $config, $sql ) = @_;
    $data = lc($data);
    $config->{search}->{search_name} = { '~' => "^$data" };
}

sub _facet_search_subject {
    my ( $class, $field, $data, $config, $sql ) = @_;

    $config->{joins} .= ' JOIN erm_subjects_main ON ( erm_subjects_main.erm_main = erm_main.id )';
    
    unshift( @{ $config->{order} }, 'rank DESC' );
    $config->{extra_columns}->{rank} = 'erm_subjects_main.rank';
    $config->{replace_columns}->{description_brief} = 'COALESCE( erm_subjects_main.description, erm_main.description_brief ) AS description_brief';
    $config->{search}->{'erm_subjects_main.subject'} = $data;
}

1;
