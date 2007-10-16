package CUFTS::CRDB::Controller::Account;

use strict;
use warnings;
use base 'Catalyst::Controller';

#use CUFTS::CJDB::Authentication::LDAP;
use CUFTS::Util::Simple;

=head1 NAME

CUFTS::CRDB::Controller::Account - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for account management, login, logout, etc..

=head1 METHODS

=cut


=head2 index 

=cut


sub logout : Chained('/site') PathPart('logout') Args(0) {
    my ($self, $c) = @_;

    $c->logout();

    return $c->response->redirect( $c->req->params->{return_to} || $c->uri_for_site('/') );
}


sub login : Chained('/site') PathPart('login') Args(0) {
    my ($self, $c) = @_;

    $c->form( {
        required => ['key', 'password', 'login'],
        optional => [ 'return_to' ],
        filters  => ['trim'],
    } );

    if (defined($c->form->{valid}->{key})) {
        my $key      = $c->form->{valid}->{key};
        my $password = $c->form->{valid}->{password};
        my $site_id  = $c->site->id;
        my $account;

        if ( not_empty_string($c->site->cjdb_authentication_module) ) {
            # Get our internal record, then check external system for password

            $account = $c->model('CJDB::Accounts')->search( { site => $site_id, key => $key } )->first();
            if ( defined($account) ) {
                my $module = 'CUFTS::CJDB::Authentication::' . $c->site->cjdb_authentication_module;
                eval {
                    $module->authenticate($c->site, $key, $password);
                };
                if ($@) {
                    # External validation error.
                    warn($@);
                    $account = undef;
                    $c->stash->{error} = ['The password or account was not recognized. Please check that you have entered the correct login name and password. If you are still having problems, please contact your administrator.'];
                }
                else {
                
                    # Preauthenticated realm does not need a password
                
                    if ( !$c->authenticate({ key => $key, site => $site_id }, 'preauthenticated') ) {
                        $c->stash->{error} = ['The password or account was not recognized. Please check that you have entered the correct login name and password. If you are still having problems, please contact your administrator.'];
                    }
                }
                
                
            }
        }
        else {

            # Use internal authentication

            if ( !$c->authenticate({ key => $key, password => $password, site => $site_id }, 'internal') ) {
                $c->stash->{error} = ['The password or account was not recognized. Please check that you have entered the correct login name and password. If you are still having problems, please contact your administrator.'];
            }

        }
        
        if ( defined($c->user) ) {
            if ( $c->user->active ) {
                return $c->response->redirect( $c->req->params->{return_to} || $c->uri_for_site('/') );
                return $c->restore_saved_action();
#                return $c->response->redirect( $c->uri_for_site( $c->controller('Browse')->action_for('browse_index') ) );
            }
            else {
                $c->stash->{error} = ['This account has been disabled by library administrators.'];
            }
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

        $c->form({required => ['key', 'name', 'password', 'create'],
                  optional => ['email', 'password2'],
                  filters => ['trim']});

        my $site = $c->site;
        unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {

            my $key       = $c->form->{valid}->{key};
            my $password  = $c->form->{valid}->{password};
            my $password2 = $c->form->{valid}->{password2};
            my $crypted_pass;
            my $level;

            my @accounts = CJDB::DB::Accounts->search('site' => $site->id, 'key' => $key);
            if (scalar(@accounts)) {
                push @{$c->stash->{error}}, "The user id '$key' already exists.";
                return;
            }

            if ( not_empty_string($site->cjdb_authentication_module) ) {
                my $module = 'CUFTS::CJDB::Authentication::' . $site->cjdb_authentication_module;
                eval {
                    $level = $module->authenticate($site, $key, $password);
                };
                if ($@) {
                    # External validation error.
                    warn($@);
                    push @{$c->stash->{error}}, "Unable to authenticate user against external service.";
                    return;
                }
            }    
            else {
                # Use internal authentication

                if ($password ne $password2) {
                    push @{$c->stash->{error}}, "Passwords do not match.";
                    return;
                }

                $crypted_pass = crypt($password, $key);

            }
            
            my $account = CJDB::DB::Accounts->create({
                site      => $site->id,
                name      => $c->form->{valid}->{name},
                email     => $c->form->{valid}->{email},
                key       => $key,
                password  => $crypted_pass,
                active    => 'true',
                level     => $level || 0,
                
            });


            if (!defined($account)) {
                push @{$c->stash->{error}}, "Error creating account.";
                return;
            }

            $c->session->{ $c->stash->{current_site}->id }->{current_account_id} = $account->id;
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

            my ($password, $password2) = ($c->form->{valid}->{password}, $c->form->{valid}->{password2});

            if (defined($password) || defined($password2)) {
                if ($password eq $password2) {
                    $c->stash->{current_account}->password(crypt($password, $c->stash->{current_account}->key));
                } else {
                    push @{$c->stash->{error}}, "Passwords do not match.";
                    return;
                }
            }

            $c->stash->{current_account}->name($c->form->{valid}->{name});
            $c->stash->{current_account}->email($c->form->{valid}->{email});
            $c->stash->{current_account}->update;           
            
            CJDB::DB::DBI->dbi_commit();

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


sub index : Private {
    my ( $self, $c ) = @_;

    $c->response->body('Matched CUFTS::CRDB::Controller::Account in Account.');
}


=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
