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
use CUFTS::Util::Simple;

__PACKAGE__->table('erm_main');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
    id
    key
    site
    license

    vendor
    publisher
    url
    access
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
    proxy
    group_records
    subscription_status
    print_included
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
    issn
    isbn

    pricing_model
    pricing_model_notes
    cost
    invoice_amount
    currency
    gst
    pst
    gst_amount
    pst_amount
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
    journal_auth
    consortia
    consortia_notes
    date_cost_notes
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
__PACKAGE__->has_a('pricing_model', 'CUFTS::DB::ERMPricingModels');
__PACKAGE__->has_a('resource_medium', 'CUFTS::DB::ERMResourceMediums');
__PACKAGE__->has_a('resource_type', 'CUFTS::DB::ERMResourceTypes');
__PACKAGE__->has_many('subjects', ['CUFTS::DB::ERMSubjectsMain' => 'subject'], 'erm_main');
__PACKAGE__->has_many('subjectsmain' => 'CUFTS::DB::ERMSubjectsMain');
__PACKAGE__->has_many('content_types', ['CUFTS::DB::ERMContentTypesMain' => 'content_type'], 'erm_main');
__PACKAGE__->has_many( 'names' => 'CUFTS::DB::ERMNames'  );
__PACKAGE__->has_a( 'license', 'CUFTS::DB::ERMLicense' );
__PACKAGE__->has_many( 'costs' => 'CUFTS::DB::ERMCosts' );
__PACKAGE__->has_many( 'uses' => 'CUFTS::DB::ERMUses' );

__PACKAGE__->sequence('erm_main_id_seq');


my @fast_columns = qw(
    id
    url
    vendor
    description_brief
);

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
                $name_record->update;
            }
        }
        else {
            $name_record = CUFTS::DB::ERMNames->create({
                name        => $new_name,
                erm_main    => $self->id,
                main        => 1,
            });
        }
    }

    return defined($name_record) ? $name_record->name : undef;
}

sub retrieve_all_for_site {
    my ( $class, $site_id, $no_objects ) = @_;

    my $columns = join ', ', map { 'erm_main.' . $_ } ( $no_objects ? @fast_columns : __PACKAGE__->columns );
    my $sql = qq{
        SELECT *
        FROM (
            SELECT DISTINCT ON (erm_names.erm_main) $columns,
                erm_names.search_name AS sort_name,
                erm_names.name AS result_name
            FROM erm_main
            JOIN erm_names ON (erm_names.erm_main = erm_main.id)
            WHERE erm_main.site = ?
            ORDER BY erm_names.erm_main, erm_names.main DESC
        ) AS erm_results
        ORDER BY sort_name
    };

    my $sth = $class->db_Main()->prepare( $sql, {pg_server_prepare => 1} );
    if ( $no_objects ) {
        my $rv = $sth->execute( $site_id );
        return $sth->fetchall_arrayref({});
    }

    my @results = $class->sth_to_objects( $sth, [ $site_id ] );
    return \@results;
}

sub name {
    my ( $self ) = @_;
    
    if ( defined($self->result_name) ) {
        return $self->result_name;
    }

    return $self->main_name;
}


sub facet_search {
    my ( $class, $site, $fields, $no_objects, $offset, $limit ) = @_;

    my $config = {
        joins  => {},
        order  => [ 'sort_name' ],    # Default order by resource name
        extra_columns => {
            'sort_name'   => 'erm_names.search_name',
            'result_name' => 'erm_names.name',
        },
        replace_columns => {
        },
        search => {
            'erm_main.site' => $site,
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
            $class->$handler( $field, $fields->{$field}, $config, \$sql );
        }
        else {
            # default
            $config->{search}->{$field} = $fields->{$field};
        }

    }
    
    my $SQLAbstract = SQL::Abstract->new;
    my ( $where, @bind ) = $SQLAbstract->where( $config->{search} );

    # Untaint $where
    $where =~ /(.*)/s or die;
    $where = $1;
    
    # Build column list
    
    my @columns;
    foreach my $column ( $no_objects ? @fast_columns : __PACKAGE__->columns ) {
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
    $sql =~ s/%JOINS%/join( ' ', values( %{ $config->{joins} } ) )/e;
    $sql =~ s/%ORDER%/join( ', ', @{ $config->{order} } )/e;
    $sql =~ s/%COLUMNS%/join( ', ', @columns )/e;

#    warn($sql);
#    warn(Dumper(\@bind));

    my $sth = $class->db_Main()->prepare( $sql, {pg_server_prepare => 1} );
    if ( $no_objects ) {
        my $rv = $sth->execute( @bind );
        return $sth->fetchall_arrayref({});
    }

    my @results = $class->sth_to_objects( $sth, \@bind );
    return \@results;

}




sub facet_count {
    my ( $class, $site, $fields ) = @_;
    
    my $config = {
        joins  => {},
        order  => [ 'sort_name' ],    # Default order by resource name
        extra_columns => {
            'sort_name'   => 'erm_names.search_name',
            'result_name' => 'erm_names.name',
        },
        replace_columns => {
        },
        search => {
            'erm_main.site' => $site,
        },
    };
    
    my $sql = qq{
        SELECT count(*)
        FROM (
            SELECT DISTINCT ON (erm_names.erm_main) erm_main.id
            FROM erm_main
            JOIN erm_names ON (erm_names.erm_main = erm_main.id)
            %JOINS%
            %WHERE%
        ) AS erm_results
    };

    foreach my $field ( keys %$fields ) {

        my $handler = "_facet_search_$field";
        if ( $class->can($handler) ) {
            $class->$handler( $field, $fields->{$field}, $config, \$sql );
        }
        else {
            # default
            $config->{search}->{$field} = $fields->{$field};
        }

    }
    
    my $SQLAbstract = SQL::Abstract->new;
    my ( $where, @bind ) = $SQLAbstract->where( $config->{search} );

    # Untaint $where
    $where =~ /(.*)/s or die;
    $where = $1;
    
    $sql =~ s/%WHERE%/$where/e;
    $sql =~ s/%JOINS%/join( ' ', values( %{ $config->{joins} } ) )/e;

#    warn($sql);
#    warn(Dumper(\@bind));

    my $sth = $class->db_Main()->prepare( $sql, {pg_server_prepare => 1} );
    $sth->execute( @bind );
    return ( $sth->fetchrow_array )[0];
}


sub _facet_search_name {
    my ( $class, $field, $data, $config, $sql ) = @_;
    $data = lc($data);
    $config->{search}->{search_name} = { '~' => "^$data" };
}

sub _facet_search_subject {
    my ( $class, $field, $data, $config, $sql ) = @_;

    $config->{joins}->{subject} = ' JOIN erm_subjects_main ON ( erm_subjects_main.erm_main = erm_main.id )';
    
    unshift( @{ $config->{order} }, 'rank' );
    $config->{extra_columns}->{rank} = 'erm_subjects_main.rank';
    $config->{replace_columns}->{description_brief} = 'COALESCE( erm_subjects_main.description, erm_main.description_brief ) AS description_brief';
    $config->{search}->{'erm_subjects_main.subject'} = $data;
}

sub _facet_search_content_type {
    my ( $class, $field, $data, $config, $sql ) = @_;

    $config->{joins}->{content_type} = ' JOIN erm_content_types_main ON ( erm_content_types_main.erm_main = erm_main.id )';
    
    $config->{search}->{'erm_content_types_main.content_type'} = $data;
}

sub _facet_search_keyword {
my ( $class, $field, $data, $config, $sql ) = @_;

    if ( !exists( $config->{joins}->{subject} ) ) {
        $config->{joins}->{subject} = ' LEFT JOIN erm_subjects_main ON ( erm_subjects_main.erm_main = erm_main.id )';
    }
    $config->{joins}->{subject_name} = ' LEFT JOIN erm_subjects ON ( erm_subjects_main.subject = erm_subjects.id )';

    if ( !exists( $config->{joins}->{consortia} ) ) {
        $config->{joins}->{consortia} = ' LEFT JOIN erm_consortia ON ( erm_main.consortia = erm_consortia.id )';
    }

    $config->{search}->{'-nest'} = [
       'erm_subjects.subject'       => { '~*' => $data },
       'erm_consortia.consortia'    => { '~*' => $data },
       'erm_main.description_brief' => { '~*' => $data },
       'erm_main.description_full'  => { '~*' => $data },
       'erm_main.key'               => { '~*' => $data },
       'erm_main.vendor'            => { '~*' => $data },
       'erm_main.publisher'         => { '~*' => $data },
       'erm_names.search_name'      => { '~'  => lc($data) },
    ];
}


sub as_marc {
    my ( $self ) = @_;
    
    my $MARC = MARC::Record->new();

    if ( not_empty_string( $self->isbn ) ) {
        $MARC->append_fields( MARC::Field->new( '020', '', '', 'a' => $self->isbn ) );
    }

    if ( not_empty_string( $self->issn ) ) {
        $MARC->append_fields( MARC::Field->new( '022', '', '', 'a' => $self->issn ) );
    }

    if ( not_empty_string( $self->journal_auth ) ) {
        $MARC->append_fields( MARC::Field->new( '035', '', '', 'a' => $self->journal_auth ) );
    }

    $MARC->append_fields( MARC::Field->new( '245', '', '', 'a' => $self->main_name ) );
    $MARC->append_fields( MARC::Field->new( '930', '', '', 'a' => 'e' . $self->id ) );

    my @subfields;

    if ( not_empty_string( $self->local_fund ) ) {
        push @subfields, 'u', $self->local_fund;
    }

    if ( not_empty_string( $self->vendor ) ) {
        push @subfields, 'v', $self->vendor;
    }
    
    if ( scalar(@subfields) ) {
        $MARC->append_fields( MARC::Field->new( '960', '', '', @subfields ) );
    }

    @subfields = ();

    if ( not_empty_string( $self->currency ) ) {
        push @subfields, 'z', $self->currency;
    }

    if ( not_empty_string( $self->currency ) ) {
        push @subfields, 'c', $self->currency;
    }

    if ( not_empty_string( $self->local_vendor ) ) {
        push @subfields, 'i', $self->local_vendor;
    }

    if ( scalar(@subfields) ) {
        $MARC->append_fields( MARC::Field->new( '961', '', '', @subfields ) );
    }   
    
    return $MARC;
}

1;