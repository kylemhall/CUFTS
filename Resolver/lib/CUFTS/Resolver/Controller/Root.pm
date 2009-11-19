package CUFTS::Resolver::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub default : Private {
    my ( $self, $c ) = @_;
    $c->redirect('test');
    return;
}

sub base : Chained('/') PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;

    # Set up basic template vars
    $c->stash->{image_dir} = '/static/images/';
    $c->stash->{css_dir}   = '/static/css/';
    $c->stash->{js_dir}    = '/static/js/';
}

sub site : Chained('base') PathPart('site') CaptureArgs(1) {
    my ($self, $c, $site_key) = @_;
    
    my $site = CUFTS::DB::Sites->search( { key => $site_key } )->first;
    if ( !defined($site) ) {
        die("Unrecognized site key: $site_key");
    }
    $c->site( $site );
    
    $c->stash->{extra_js} = [];
    
    return 1;
}

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    if ( !$c->response->content_type ) {
        $c->response->content_type('text/html; charset=iso-8859-1');
    }
}

=back

=head1 NAME

CUFTS::Resolver::C::Root - Catalyst component

=head1 SYNOPSIS

See L<CUFTS::Resolver>

=head1 DESCRIPTION

Catalyst component.

=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
