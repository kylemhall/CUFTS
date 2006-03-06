package CUFTS::Resolver::C::Resolve;

use strict;
use base 'Catalyst::Base';

use CUFTS::Util::Simple;
use CUFTS::Resolve;
use CUFTS::Request;

sub auto : Private {
    my ( $self, $c ) = @_;

    # FUTURE: Consider adding load of site specific resolver?
    my $resolver = new CUFTS::Resolve();

    my $sites = $resolver->get_sites( undef, $c->stash->{current_site_key} );

    $c->stash->{sites}    = $sites;
    $c->stash->{resolver} = $resolver;

    return 1;  # Continue processing
}

sub openurl : Local {
    my ( $self, $c, $template ) = @_;

    my $params   = $c->req->params;
    my $resolver = $c->stash->{resolver};
    my $sites    = $c->stash->{sites};

    # parse request as an OpenURL (could be 0.1 or 1.0)
    my $request = CUFTS::Request->parse_openurl($params);

    # if we didn't get the sites from the URL earlier, try the request.
    if ( !scalar( @{$sites} ) ) {
        @{$sites} = $resolver->get_sites($request);
    }

    use Time::HiRes ();

    # resolve the request
    my $start = [Time::HiRes::gettimeofday];
    my $results = $resolver->resolve( $sites, $request );
    warn(Time::HiRes::tv_interval($start));

    $c->stash->{results}  = $results;
    $c->stash->{request}  = $request;
    $c->stash->{template} = $template ? "${template}.tt" : 'main.tt';

    return;
}

=back

=head1 NAME

CUFTS::Resolver::C::Resolve - Catalyst component

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
