package CUFTS::Resolver::C::Test;

use strict;
use base 'Catalyst::Base';

use CUFTS::Util::Simple;
use URI;

# default - test screen view listing all sites and
# templates with fields to be sent to the resolver.

sub default : Private {
    my ( $self, $c ) = @_;

    my @sites = CUFTS::DB::Sites->retrieve_all();
    $c->stash->{sites}    = \@sites;
    $c->stash->{template} = 'test.tt';

    return;
}

# do - process a test request, turn it into a URL to
# send to the resolver and redirect to that URL

sub do : Local {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    my $url    = $c->stash->{real_base};

    # add site key ("BVAS", "ONN") to the path if in query
    if ( !is_empty_string( $params->{'_site'} ) ) {
        $url .= 'site/' . $params->{'_site'};
    }

    $url .= '/resolve/openurl';

    # add a template name to the path if in query
    if ( !is_empty_string( $params->{'_template'} ) ) {
        $url .= '/' . $params->{'_template'};
    }

    # remove "internal" params from hash before setting
    # query for the URI object
    foreach my $param ( keys %{$params} ) {
        delete $params->{$param} if $param =~ /^_/;    # _site, _template
    }

    my $uri = URI->new($url);
    $uri->query_form($params);

    return $c->redirect($uri);
}

=back

=head1 NAME

CUFTS::Resolver::C::Test - Catalyst component

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
