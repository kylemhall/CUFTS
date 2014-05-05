package CUFTS::Resolver::Model::CUFTS;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'CUFTS::Schema',
);

=head1 NAME

CUFTS::Resolver::Model::CUFTS - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<CUFTS::Resolver>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<CUFTS::Schema>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.61

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;