package CUFTS::CRDB::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

CUFTS::CRDB::Controller::Root - Root Controller for CUFTS::CRDB

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 site

Uses chained paths to get the site key from the URL.

=cut

sub site : Chained('/') PathPart('') CaptureArgs(1) {
    my ($self, $c, $site_key) = @_;
    
    my $site = $c->model('CUFTS::Sites')->search( { key => $site_key } )->first;
    if ( !defined($site) ) {
        die("Unrecognized site key: $site_key");
    }
    
    $c->stash->{additional_template_paths} = [ $c->config->{root} . '/sites/' . $site->id . '/active' ];    
    $c->site( $site );
    
    return 1;
}

=head2 default

=cut
sub app_root : Chained('site') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'main.tt';
}


sub default : Private {
    my ( $self, $c ) = @_;
    $c->response->status(404);
    $c->detach();
#    $c->response->body( 'Not found' );
}


sub test : Global {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'test.tt';
}


sub exit : Global {
    my ( $self, $c ) = @_;
    
    exit();
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') { }

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
