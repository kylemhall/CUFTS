package CUFTS::CJDB::C::Account;

use strict;
use base 'Catalyst::Base';

sub logout : Local {
	my ($self, $c) = @_;

	delete $c->session->{current_account_id};
	delete $c->stash->{current_account};

	$c->req->params($c->session->{prev_params});
	return $c->forward('/' . $c->session->{prev_action}, $c->session->{prev_arguments});
}


sub login : Local {
	my ($self, $c) = @_;

	$c->form({'required' => ['key', 'password', 'login'], 'filters' => ['trim']});

	if (defined($c->form->{valid}->{key})) {
		my ($key, $password) = ($c->form->{valid}->{key}, $c->form->{valid}->{password});

		my $crypted_pass = crypt($password, $key);
		my @accounts = CJDB::DB::Accounts->search('site' => $c->stash->{current_site}->id, 'key' => $key, 'password' => $crypted_pass);
		
		if (scalar(@accounts) == 1) {
			$c->stash->{current_account} = $accounts[0];
			$c->session->{current_account_id} = $accounts[0]->id;
			
			$c->req->params($c->session->{prev_params});
			return $c->forward('/' . $c->session->{prev_action}, $c->session->{prev_arguments});
		} else {
			$c->stash->{error} = ['The password or account was not recognized. Please check that you have entered the correct login name and password. If you are still having problems, please contact your administrator.'];
		}
	} 
	
	$c->stash->{template} = 'login.tt';
}

sub create : Local {
	my ($self, $c) = @_;

	if (defined($c->req->params->{cancel})) {
		$c->req->params($c->session->{prev_params});
		return $c->forward('/' . $c->session->{prev_action}, $c->session->{prev_arguments});
	}

	$c->stash->{template} = 'account_create.tt';

	if (defined($c->req->params->{key})) {

		$c->form({required => ['key', 'name', 'password', 'password2', 'create'],
		          optional => ['email'],
		          filters => ['trim']});

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {

			my ($key, $password, $password2) = ($c->form->{valid}->{key}, $c->form->{valid}->{password}, $c->form->{valid}->{password2});

			my @accounts = CJDB::DB::Accounts->search('site' => $c->stash->{current_site}->id, 'key' => $key);
			if (scalar(@accounts)) {
				push @{$c->stash->{error}}, "The user id '$key' already exists.";
				return;
			}

			if ($password ne $password2) {
				push @{$c->stash->{error}}, "Passwords do not match.";
				return;
			}

			my $crypted_pass = crypt($password, $key);
			
			my $account = CJDB::DB::Accounts->create({
				'site'      => $c->stash->{current_site}->id,
				'name'      => $c->form->{valid}->{name},
				'email'     => $c->form->{valid}->{email},
				'key'       => $key,
				'password'  => $crypted_pass,
				'active'    => 'true',
				'level'     => 0,
				
			});


			if (!defined($account)) {
				push @{$c->stash->{error}}, "Error creating account.";
				return;
			}

			$c->session->{current_account_id} = $account->id;
			$c->stash->{current_account} = $account;
			
			CJDB::DB::DBI->dbi_commit();

			$c->req->params($c->session->{prev_params});
			return $c->forward('/' . $c->session->{prev_action}, $c->session->{prev_arguments});
		}
	} 
}


sub manage : Local {
	my ($self, $c) = @_;

	# If the user logged out on this page, go back to /browse

	defined($c->stash->{current_account}) or
		return $c->redirect('/browse');

	if (defined($c->req->params->{cancel})) {
		$c->req->params($c->session->{prev_params});
		return $c->forward('/' . $c->session->{prev_action}, $c->session->{prev_arguments});
	}

	$c->stash->{template} = 'account_manage.tt';

	if (defined($c->req->params->{save})) {

		$c->form({required => ['name', 'email', 'save'],
		          optional => ['password', 'password2'],
		          filters => ['trim']});

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {

			warn('1');

			my ($password, $password2) = ($c->form->{valid}->{password}, $c->form->{valid}->{password2});

			if (defined($password) || defined($password2)) {
				if ($password eq $password2) {
					$c->stash->{current_account}->password(crypt($password, $c->stash->{current_account}->key));
				} else {
					push @{$c->stash->{error}}, "Passwords do not match.";
					return;
				}
			}

			warn('2');

			$c->stash->{current_account}->name($c->form->{valid}->{name});
			$c->stash->{current_account}->email($c->form->{valid}->{email});
			$c->stash->{current_account}->update;			
			
			CJDB::DB::DBI->dbi_commit();

			warn('3');

			$c->req->params($c->session->{prev_params});
			return $c->forward('/' . $c->session->{prev_action}, $c->session->{prev_arguments});
		}
	} 
}


sub tags : Local {
	my ($self, $c) = @_;

	
	$c->stash->{tags} = CJDB::DB::Tags->get_mytags_list($c->stash->{current_account});
	$c->stash->{template} = 'mytags.tt';
}

1;
