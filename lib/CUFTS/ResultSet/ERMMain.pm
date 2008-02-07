package CUFTS::ResultSet::ERMMain;

use strict;
use base 'DBIx::Class::ResultSet';

use Set::Object;

use Data::Dumper;

my @fast_search_columns = qw( 
    id
    key
    vendor
    description_brief
    url
    access
    license.id
);

sub facet_search {
    my ( $self, $site, $fields, $no_objects, $offset, $limit ) = @_;

    my $config = {
        joins  => { 'names' => undef, 'license' => undef },
        order  => [ 'sort_name' ],    # Default order by resource name
        extra_columns => {
            'distinct_erm_main'  => 'names.erm_main',
            'main_erm_main_name' => 'names.main',
            'sort_name'          => 'names.search_name',
            'result_name'        => 'names.name',
        },
        replace_columns => {
        },
        search => {
            'me.site' => $site,
        },
    };


    # Dispatch to handle special setup for certain fields.  Default to normal field 
    # search if there is no matching "_facet_search..." handler.
    
    foreach my $field ( keys %$fields ) {

        my $handler = "_facet_search_${field}";
        if ( $self->can($handler) ) {
            $self->$handler( $field, $fields->{$field}, $config );
        }
        else {
            # default
            
            $config->{search}->{ "me.${field}" } = $fields->{$field};
        }
        
    }


    # Build select and as lists to pass as search attributes.  This pulls
    # from the column list merged with any "replace_columns" config setting

    my ( @select_columns, @as_columns );
    foreach my $column ( @fast_search_columns ) {
        push @as_columns, $column;

        if ( exists( $config->{replace_columns}->{$column} ) ) {
            push @select_columns, $config->{replace_columns}->{$column};
        }
        else {
            push @select_columns, ( $column =~ /\./ ? $column : "me.${column}" );
        }

    }


    # Build +select and +as lists to pass as search attributes
    
    my ( @extra_select_columns, @extra_as_columns );
    foreach my $as_column ( keys %{ $config->{extra_columns} } ) {
        push @extra_as_columns, $as_column;
        push @extra_select_columns, $config->{extra_columns}->{$as_column};
    }

    push @select_columns, 'license.allows_downloads';
    push @as_columns,     'license.allows_downloads';
    
    
    # Build join list from HASH ref.  Flatten with value 1

    my @joins = map { defined( $config->{joins}->{$_} ) ? { $_ => $config->{joins}->{$_} } : $_ } keys %{ $config->{joins} };
    
    # Do the search and return a result set

    my %search_attrs = (
        'select'   => \@select_columns,
        'as'       => \@as_columns,
        'distinct' => 'names.erm_main',
        'join'     => \@joins,
        '+as'      => \@extra_as_columns,
        '+select'  => \@extra_select_columns,
        'order_by' => 'names.erm_main, names.main DESC',
    );

    return $self->search(
        $config->{search},
        \%search_attrs,
    );

}

sub _facet_search_subject {
    my ( $class, $field, $data, $config ) = @_;

    $config->{joins}->{subjects_main} ||= undef;
    
    $config->{extra_columns}->{rank} = 'subjects_main.rank';

    $config->{replace_columns}->{description_brief} = { 'COALESCE' => 'subjects_main.description, me.description_brief' };

    $config->{search}->{'subjects_main.subject'} = $data;
}

sub _facet_search_name {
    my ( $self, $field, $data, $config ) = @_;

    $data = CUFTS::Schema::ERMNames->strip_name( $data );
    $config->{search}->{'names.search_name'} = { '~' => "^$data" };
}


sub _facet_search_content_type {
    my ( $class, $field, $data, $config ) = @_;

    $config->{joins}->{content_types_main} ||= undef;
    
    $config->{search}->{'content_types_main.content_type'} = $data;
}


sub _facet_search_keyword {
    my ( $class, $field, $data, $config ) = @_;

    $config->{joins}->{subjects_main} = 'subject';

    $config->{search}->{'-nest'} = [
            'subject.subject'      => { '~*' => $data },
            'me.description_brief' => { '~*' => $data },
            'me.description_full'  => { '~*' => $data },
            'me.key'               => { '~*' => $data },
            'me.vendor'            => { '~*' => $data },
            'me.publisher'         => { '~*' => $data },
            'names.search_name'    => { '~'  => CUFTS::Schema::ERMNames->strip_name( $data ) },
    ];
        
}


##
## Restricted column information
##

sub restricted_columns {
    my ( $class, $site, $account ) = @_;
    
    my $account_type = $class->get_account_type( $account );
    
    if ( $account_type eq 'patron' ) {
        return grep { grep { $_ eq 'patron' } @{ $class->result_source->column_info($_)->{default_can_view} } } $class->result_source->columns;
    }
    elsif ( $account_type eq 'staff' ) {
        return grep { grep { $_ eq 'staff' } @{ $class->result_source->column_info($_)->{default_can_view} } } $class->result_source->columns;
    }
    else {
        die("Unrecognized account type: ${account_type}");
    }
    
}

sub get_account_type {
    my ( $class, $account ) = @_;   # CJDB::Schema::Account
    
    # Lowest level access if there is not account

    return 'patron' if !defined($account);

    return $account->get_account_type();
}

1;