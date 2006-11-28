package CUFTS::MaintTool;

use strict;
use Catalyst qw/Static::Simple Session Session::Store::FastMmap Session::State::Cookie FormValidator CUFTS::MaintTool::FillInForm/;
use lib '../lib';

use CUFTS::ResourcesLoader;

use CUFTS::Config;

our $VERSION = '2.00.00';

CUFTS::MaintTool->config(
    name                     => 'CUFTS::MaintTool',
    default_display_per_page => 50,
);

CUFTS::MaintTool->config->{session} = {
    expires => 36000,
    rewrite => 0,
    storage => '/tmp/CUFTS_MaintTool_sessions',
};

CUFTS::MaintTool->setup;

##
## begin - Handle logins and set up account/site records in the stash
##

sub begin : Private {
    my ( $self, $c ) = @_;

    # Set up basic template vars

    my $url_base = $c->config->{url_base} || (q{} . $c->req->base);
    $url_base =~ s{/$}{};    # Remove trailing slash
    $c->stash->{url_base}  = $url_base;
    $c->stash->{image_dir} = "${url_base}/static/images/";
    $c->stash->{css_dir}   = "${url_base}/static/css/";
    $c->stash->{js_dir}    = "${url_base}/static/js/";

    # Don't force login on static content
    return 1 if ( $c->req->{path} =~ /^static/ );
    return 1 if ( $c->req->{path} =~ /^public/ );

    # Set up current user and site info in the stash

    if ( my $account_id = $c->session->{current_account_id} ) {
        $c->stash->{current_account} = CUFTS::DB::Accounts->retrieve($account_id);

        if ( my $site_id = $c->session->{current_site_id} ) {
            $c->stash->{current_site} = CUFTS::DB::Sites->retrieve($site_id);
        }
    }
    elsif ( $c->req->action ne 'login' ) {

        # If we have no current user then show the login screen

        $c->req->action(undef);
        return $c->redirect('/login');
    }
    
    return 1;
}

##
## end - Forward requests to the TT view for rendering
##

sub end : Private {
    my ( $self, $c ) = @_;

    if ( scalar @{ $c->error } ) {
        warn("Rolling back database changes due to error flag.");
        CUFTS::DB::DBI->dbi_rollback();
        
        $c->stash(
            template      => 'fatal_error.tt',
            fatal_errors  => $c->error,
        );
        $c->forward('CUFTS::MaintTool::V::TT');

        warn( join("\n",  @{ $c->error }) );

        $c->{error} = [];
        
    }

    return 1 if $c->response->status =~ /^3\d\d$/;
    return 1 if $c->response->body;

    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=iso-8859-1');
    }

    if ( defined($c->stash->{current_account}) ) {
        $c->response->headers->header( 'Cache-Control' => 'no-cache' );
        $c->response->headers->header( 'Pragma' => 'no-cache' );
        $c->response->headers->expires( time );
    }

    $c->forward('CUFTS::MaintTool::V::TT');
}


##
## login - Show the login screen and 
##

sub login : Global {
    my ( $self, $c ) = @_;

    $c->form(
        {   'required' => [ 'login_key', 'login_password', 'submit' ],
            'filters'  => ['trim']
        }
    );

    # Clear stash and session

    $c->session->{current_account_id} = undef;
    $c->session->{current_site_id}    = undef;
    $c->stash->{current_account}      = undef;
    $c->stash->{current_site}         = undef;

    # If there's a form submission, try to log in, checking the password

    if ( defined( $c->form->{valid}->{login_key} ) ) {
        my $key      = $c->form->{valid}->{login_key};
        my $password = $c->form->{valid}->{login_password};

        my $crypted_pass = crypt( $password, $key );
        my @accounts = CUFTS::DB::Accounts->search(
            key      => $key,
            password => $crypted_pass
        );

        # If we have a matching record, stuff the id in the session
        # and redirect to main, otherwise show an error and the form again

        if ( scalar(@accounts) == 1 ) {
            $c->session->{current_account_id} = $accounts[0]->id;

            my @sites = $accounts[0]->sites;
            if ( scalar(@sites) == 1 ) {
                $c->session->{current_site_id} = $sites[0]->id;
            }

            return $c->redirect('/main');
        }
        else {
            $c->stash->{errors} = [
                'The password or account was not recognized. Please check that you have entered the correct login name and password. If you are still having problems, please contact your CUFTS administrator.'
            ];
        }
    }

    $c->stash->{header_image} = 'login.jpg';
    $c->stash->{template}     = 'login.tt';
}

##
## logout - Remove the user session and forward to the login screen
##

sub logout : Global {
    my ( $self, $c ) = @_;
    $c->redirect('/login');
}

##
## main - Display the main screen
##

sub main : Global {
    my ( $self, $c ) = @_;

    $c->stash->{template}     = 'main.tt';
    $c->stash->{header_image} = 'home.jpg';
}

##
## default - Redirect to the login screen
##

sub default : Private {
    my ( $self, $c ) = @_;
    $c->redirect('/login');
}

##
## redirect - helper for redirecting.  Prepends the url_base if
##            it's missing and there's no "http.."
##

sub redirect {
    my ( $c, $location ) = @_;
    $location =~ m#^/#
        or die("Attempting to redirect to relative location: $location");

    if ( $c->stash->{url_base} ) {
        $location = $c->stash->{url_base} . $location;
    }

    $c->response->headers->header( 'Cache-Control' => 'no-cache' );
    
    return $c->res->redirect($location);
}

=head1 NAME

CUFTS::MaintTool

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

The maintenance tool for CUFTS

=head1 AUTHOR

Todd Holbrook - tholbroo@sfu.ca

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;

