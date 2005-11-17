package CUFTS::Resolver;

use strict;

use Catalyst qw/Static::Simple/;
use lib '../lib';
use CUFTS::Config;

our $VERSION = '2.00.00';

CUFTS::Resolver->config(
    name       => 'CUFTS::Resolver',
    regex_base => '',
    strip_base => 'site/',
);

CUFTS::Resolver->setup;

sub prepare_path {
    my $c = shift;

    $c->NEXT::prepare_path(@_);

    my $path = $c->req->path;

    # Get site and set site key for loading from database later.
    # Database load isn't done here because the request might be
    # for static objects that don't need database setup.

    my $strip_base = $c->config->{strip_base};

    if ( $path =~ s{^ ${strip_base} (\w+) / }{}oxsm ) {
        my $site_key = $1;
        $c->stash->{current_site_key}  = $site_key;
        $c->stash->{site_template_dir} = "root/sites/${site_key}";

        # Stringify c->req->base - otherwise it's a URI object
        $c->stash->{real_base} = $c->config->{url_base}
            || q{} . $c->req->base;
            
        $c->req->base->path( $c->req->base->path . "${strip_base}${site_key}" );
        $c->req->path($path);

        $c->stash->{url_base} =
            $c->config->{url_base}
            ? ( $c->config->{url_base} . "${strip_base}${site_key}" )
            : $c->req->base;

    }
    else {
        $c->stash->{url_base} =
            $c->config->{url_base}
            ? $c->config->{url_base}
            : q{} . $c->req->base;

        $c->stash->{real_base} = $c->stash->{url_base};
    }

    return 1;
}

sub begin : Private {
    my ( $self, $c ) = @_;

    # Set up basic template vars
    $c->stash->{image_dir} = $c->stash->{url_base} . '/static/images/';
    $c->stash->{css_dir}   = $c->stash->{url_base} . '/static/css/';
    $c->stash->{js_dir}    = $c->stash->{url_base} . '/static/js/';

    return 1;
}

##
## end - Forward requests to the TT view for rendering
##

sub end : Private {
    my ( $self, $c ) = @_;

    return 1 if $c->response->status =~ /^3\d\d$/;
    return 1 if $c->response->body;

    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=iso-8859-1');
    }

    return $c->forward('CUFTS::Resolver::V::TT');
}

##
## redirect - Helper method for redirecting while keeping the URL base correct.
##

sub redirect {
    my ( $c, $location ) = @_;

    if ( $location !~ /^http:/ ) {
        $location =~ m#^/#
            or die("Attempting to redirect to relative location: $location");

        if ( $c->stash->{url_base} ) {
            $location = $c->stash->{url_base} . $location;
        }
    }

    return $c->res->redirect($location);
}

sub default : Private {
    my ( $self, $c ) = @_;
    $c->res->output('Congratulations, CUFTS::Resolver is on Catalyst!');

    return;
}

=back

=head1 NAME

CUFTS::Resolver - Catalyst based application

=head1 SYNOPSIS

    script/cufts_resolver_server.pl

=head1 DESCRIPTION

Catalyst based application.

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
