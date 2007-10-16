package CUFTS::CRDB::Controller::Resource::Field;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME

CUFTS::CRDB::Controller::Resource::Field - Catalyst Controller for working with an individual fields in a resource.  This is generally for AJAX updates.

=head1 DESCRIPTION

Catalyst Controller

=head1 METHODS

=cut

my %handler_map = (
    consortia           => 'consortia',
    content_types       => 'content_types',
    coverage            => 'string',
    description_full    => 'text',
    embargo             => 'string',
    help_url            => 'url',
    open_access         => 'string',
    public_password     => 'string',
    public_user         => 'string',
    publisher           => 'string',
    refworks_compatible => 'boolean',
    refworks_info_url   => 'url',
    resolver_enabled    => 'boolean',
    resource_medium     => 'resource_medium',
    resource_type       => 'resource_type',
    subjects            => 'subjects',
    subscription_status => 'string',
    title_list_url      => 'url',
    update_frequency    => 'string',
    user_documentation  => 'text',
    vendor              => 'string',
);

sub base : Chained('/resource/load_resource') PathPart('field') CaptureArgs(0) {
    my ( $self, $c ) = @_;
    
    $c->assert_user_roles('edit_erm_records');
}

sub edit : Chained('base') PathPart('edit') Args(1) {
    my ( $self, $c, $field ) = @_;

    # Dispatch to appropriate field handler

    my $handler = $handler_map{$field};
    
    die("Unable to find handler for field: $field") if !defined( $handler );
    
    $handler = "edit_field_${handler}";
    
    return $self->$handler( $c, $field );
}

sub edit_field_string {
    my ( $self, $c, $field ) = @_;
}


=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
