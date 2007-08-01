package CJDB::Schema::AccountsRoles;

use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);

__PACKAGE__->table('cjdb_accounts_roles');

__PACKAGE__->add_columns( qw(
    account
    role
));

__PACKAGE__->set_primary_key( qw/account role/ );

__PACKAGE__->belongs_to('role', 'CJDB::Schema::Roles', { 'foreign.id' => 'self.role'});

1;
