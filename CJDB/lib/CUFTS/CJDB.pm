package CUFTS::CJDB;

use strict;
use Catalyst qw/Session::FastMmap Static::Simple FormValidator FillInForm -Debug/;
use lib '../lib';
use CUFTS::Config;
use CUFTS::CJDB::Util;

our $VERSION = '2.00.00';

CUFTS::CJDB->config(
    name     => 'CUFTS::CJDB',
    url_base => 'http://localhost:3000/',

    #	url_base => 'http://proxy2.lib.sfu.ca:3000/CJDB',
    regex_base           => '',
    default_max_columns  => 20,
    default_min_per_page => 50,
    root                 => '/usr/local/devel/CUFTS/CJDB/root/',
);

CUFTS::CJDB->config->{session} = {
    expires => 36000,
    rewrite => 0,
    storage => '/tmp/CJDB_sessions',
};

CUFTS::CJDB->setup;

sub prepare_path {
    my $c = shift;

    $c->NEXT::prepare_path(@_);

    my $path = $c->req->path;

    # Get site and set site key for loading from database later.
    # Database load isn't done here because the request might be
    # for static objects that don't need database setup.

    my $regex_base = $c->config->{regex_base};
    if ( $path =~ s{^ ${regex_base} (\w+) / }{}oxsm ) {
        my $site_key = $1;
        $c->stash->{current_site_key}  = $site_key;
        $c->stash->{site_template_dir} = "root/sites/${site_key}";
        $c->req->base->path( $c->req->base->path . "${regex_base}${site_key}" );
        $c->req->path($path);
        $c->stash->{url_base} = defined($c->config->{url_base})
                                ? ($c->config->{url_base} . $site_key)
                                : $c->req->base;
    }
    else {
        die("Site not found in URL");
    }
}

##
## begin - Handle logins and set up account/site records in the stash
##

sub begin : Private {
    my ( $self, $c ) = @_;

    # Skip setting up stash information for static items

    return 1 if ( $c->req->{path} =~ /^static/ );

    # Get the site from the database based on the site key
    # set in prepare_path()

    $c->stash->{current_site} = CUFTS::DB::Sites->search( key => $c->stash->{current_site_key} )->first;
    if (!defined($c->stash->{current_site})) {
        die( "Unable to find site matching key: " . $c->stash->{current_site_key} );
    }

    # Set up basic template vars

    $c->stash->{image_dir} = $c->stash->{url_base} . '/static/images/';
    $c->stash->{css_dir}   = $c->stash->{url_base} . '/static/css/';
    $c->stash->{js_dir}    = $c->stash->{url_base} . '/static/js/';
    $c->stash->{self_url}  = $c->req->{base} . $c->req->{path};

    # Get the current user for the stash if they have logged in

    if ( defined( $c->session->{current_account_id} ) ) {
        $c->stash->{current_account} = CJDB::DB::Accounts->retrieve( 
            $c->session->{current_account_id} 
        );
    }

    # Store previous action/arguments/parameters data

    unless ( $c->req->action =~ /^account/ ) {
        $c->session->{prev_action}    = $c->req->action;
        $c->session->{prev_arguments} = $c->req->arguments;
        $c->session->{prev_params}    = $c->req->params;
    }
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

    $c->forward('CUFTS::CJDB::V::TT');
}

sub browse : Local {
    my ( $self, $c ) = @_;

    $c->forward('/browse/browse');
}

sub default : Private {
    my ( $self, $c ) = @_;

    $c->redirect('/browse');
}

sub redirect {
    my ( $c, $location ) = @_;
    $location =~ m#^/#
        or die("Attempting to redirect to relative location: $location");

    if ( $c->stash->{url_base} ) {
        $location = $c->stash->{url_base} . $location;
    }

    $c->res->redirect($location);
}

##
## Define base level actions here and forward to controllers when necessary.
## This keeps everything as Local actions which makes handing the user back
## to the screen they were on for login/logout possible.
##

sub journal : Local {
    my ( $self, $c, $journal_id ) = @_;

    $c->forward( '/journal/view', [$journal_id] );
}

=head1 NAME

CUFTS::CJDB - Catalyst based application

=head1 SYNOPSIS

    script/cufts_cjdb_server.pl

=head1 DESCRIPTION

Catalyst based application.

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
