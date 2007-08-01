package CJDB::Schema::Accounts;

use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('cjdb_accounts');
__PACKAGE__->add_columns( qw(
    id

    name
    key
    password
    email
    level

    site

    active

    created
    modified
));                                                                                                        

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(
    map_user_role => 'CJDB::Schema::AccountsRoles' => 'account'
);
__PACKAGE__->many_to_many( roles => 'map_user_role', 'role');

1;