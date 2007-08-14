package CUFTS::MaintTool::V::JSON;

use strict;
use base 'Catalyst::View::JSON';

__PACKAGE__->config( {
    expose_stash    => 'json'
} );

=head1 NAME

CUFTS::MaintTool::V::JSON - Catalyst JSON View

=head1 SYNOPSIS

See L<CUFTS::MaintTool>

=head1 DESCRIPTION

Catalyst JSON View.

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
