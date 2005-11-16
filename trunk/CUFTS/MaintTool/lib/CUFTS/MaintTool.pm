package CUFTS::MaintTool;

use strict;
use Catalyst qw/Session::FastMmap Static::Simple FormValidator CUFTS::MaintTool::FillInForm/;
use lib '../lib';
use CUFTS::Config;

use Data::Dumper;


our $VERSION = '2.00.00';

CUFTS::MaintTool->config( 
	name     => 'CUFTS::MaintTool',
#	url_base => 'http://proxy2.lib.sfu.ca:8033/CUFTS/maint',
	url_base => 'http://localhost:3000',
	default_display_per_page => 50,
);


CUFTS::MaintTool->config->{session} = {
	expires => 36000,
	rewrite => 0,
	storage => '/tmp/CUFTS_sessions',
};

CUFTS::MaintTool->setup;

##
## begin - Handle logins and set up account/site records in the stash
##

sub begin : Private {
	my ($self, $c) = @_;

	# Set up basic template vars
	
	$c->stash->{url_base}  = $c->config->{url_base};

	# For a live setup, change these so that Catalyst isn't handling them.

	$c->stash->{image_dir} = $c->stash->{url_base} . '/static/images/';
	$c->stash->{css_dir}   = $c->stash->{url_base} . '/static/css/';
	$c->stash->{js_dir}    = $c->stash->{url_base} . '/static/js/';

	# don't force login on static content
	return 1 if ($c->req->{path} =~ /^static/); 

	# Set up current user and site info in the stash
			
	if (defined($c->session->{current_account_id})) {
		$c->stash->{current_account} = CUFTS::DB::Accounts->retrieve($c->session->{current_account_id});

		defined($c->session->{current_site_id}) and
			$c->stash->{current_site} = CUFTS::DB::Sites->retrieve($c->session->{current_site_id});
		
	} elsif ($c->req->action ne 'login') {
		# If we have no current user then show the login screen
		
		$c->req->action(undef);
		return $c->redirect('/login');
	}
}

##
## end - Forward requests to the TT view for rendering
##

sub end : Private {
    my ($self, $c) = @_;

    return 1 if $c->response->status =~ /^3\d\d$/;
    return 1 if $c->response->body;

    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=iso-8859-1');
    }

    $c->forward('CUFTS::MaintTool::V::TT');
}


##
## login - Show the login screen
##

sub login : Global {
	my ($self, $c) = @_;

	$c->form({'required' => ['login_key', 'login_password', 'submit'], 'filters' => ['trim']});

	if (defined($c->form->{valid}->{login_key})) {
		my ($key, $password) = ($c->form->{valid}->{login_key}, $c->form->{valid}->{login_password});

		my $crypted_pass = crypt($password, $key);
		my @accounts = CUFTS::DB::Accounts->search('key' => $key, 'password' => $crypted_pass);
		
		if (scalar(@accounts) == 1) {
			$c->session->{current_account_id} = $accounts[0]->id;
			
			my @sites = $accounts[0]->sites;
			if (scalar(@sites) == 1) {
				$c->session->{current_site_id} = $sites[0]->id;
			}
			
			$c->redirect('/main');
		} else {
			$c->stash->{errors} = ['The password or account was not recognized. Please check that you have entered the correct login name and password. If you are still having problems, please contact your CUFTS administrator.'];
		}
	} 
	
	$c->stash->{header_image} = 'login.jpg';
	$c->stash->{template} = 'login.tt';
}


##
## logout - Remove the user session and forward to the login screen
## 

sub logout : Global {
	my ($self, $c) = @_;
	
	$c->session->{current_account_id} = undef;
	$c->session->{current_site_id} = undef;

	$c->redirect('/login');
}
	
	

##
## main - Display the main screen
##

sub main : Global {
	my ($self, $c) = @_;
	
	$c->stash->{template} = 'main.tt';
	$c->stash->{header_image} = 'home.jpg';
}



sub redirect {
	my ($c, $location) = @_;
	$location =~ m#^/# or
		die("Attempting to redirect to relative location: $location");

	if ($c->config->{url_base}) {
		$location = $c->config->{url_base} . $location;
	}
	
	$c->res->redirect($location);
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

