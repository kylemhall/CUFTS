package CUFTS::CJDB;

use strict;
use Catalyst qw/Static::Simple Session Session::Store::FastMmap Session::State::Cookie FormValidator FillInForm/;
use lib '../lib';
use CUFTS::Config;
use CUFTS::CJDB::Util;
use CUFTS::Util::Simple;

#use CUFTS::DB::LocalResources;
use CUFTS::Resolve;


our $VERSION = '2.00.00';

CUFTS::CJDB->config(
    name                 => 'CUFTS::CJDB',
    regex_base           => '',
    default_max_columns  => 20,
    default_min_per_page => 50,
);

CUFTS::CJDB->config->{session} = {
    expires => 36000,
    rewrite => 0,
    storage => '/tmp/CUFTS_CJDB_sessions',
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
    if ( $path =~ m{^ ${regex_base} static / }oxsm ) {
        $c->stash->{url_base} = defined($c->config->{url_base})
                                ? $c->config->{url_base}
                                : $c->req->base;
    }
    elsif ( $path =~ s{^ ${regex_base} (\w+) / (active|sandbox)? /? }{}oxsm ) {
        my $site_key      = $c->stash->{current_site_key} = $1;
        my $template_type = $c->stash->{template_type}    = $2 || 'active';
        
        # Get the site from the database based on the site key
        
        $c->stash->{current_site} = CUFTS::DB::Sites->search( key => $site_key )->first;
        if (!defined($c->stash->{current_site})) {
            die( "Unable to find site matching key: $site_key" );
        }
        
        $c->stash->{site_template_dir} = '/sites/' . $c->stash->{current_site}->id . "/${template_type}";
        
        $c->req->base->path( $c->req->base->path . "${regex_base}${site_key}" );
        $c->req->path($path);
        $c->stash->{url_base} = defined($c->config->{url_base})
                                ? ($c->config->{url_base} . $site_key)
                                : $c->req->base;
                                
        if ( $template_type ne 'active' ) {
            $c->stash->{url_base} .= '/' . $template_type;
        }
    }
    else {
        die("Site not found in URL");
    }

    $c->stash->{url_base} =~ s{/$}{};  # Remove trailing slash
}

##
## begin - Handle logins and set up account/site records in the stash
##

sub begin : Private {
    my ( $self, $c ) = @_;

    # Skip setting up stash information for static items

    return 1 if ( $c->req->{path} =~ /^static/ );

    # Set up basic template vars

    $c->stash->{image_dir} = $c->stash->{url_base} . '/static/images/';
    $c->stash->{css_dir}   = $c->stash->{url_base} . '/static/css/';
    $c->stash->{js_dir}    = $c->stash->{url_base} . '/static/js/';
    $c->stash->{self_url}  = $c->req->{base} . $c->req->{path};

    # Set up site specific CSS file if it exists
    
    my $site_css = '/sites/' . $c->stash->{current_site}->id 
                   . '/static/css/' . $c->stash->{template_type} 
                   . '/cjdb.css';
                  
    if ( -e ($c->config->{root} . $site_css) ) {
        $c->stash->{site_css_file} = $c->stash->{url_base} . $site_css;
    }

    # Get the current user for the stash if they have logged in

    if ( defined( $c->session->{ $c->stash->{current_site}->id }->{current_account_id} ) ) {
        $c->stash->{current_account} = CJDB::DB::Accounts->retrieve( 
            $c->session->{ $c->stash->{current_site}->id }->{current_account_id} 
        );
    }

    # Store previous action/arguments/parameters data

    if ( $c->req->action !~ /^account/ && $c->req->action !~ /ajax/ ) {
        $c->session->{prev_action}    = $c->req->action;
        $c->session->{prev_arguments} = $c->req->arguments;
        $c->session->{prev_params}    = $c->req->params;
    }
}


sub auto : Private {
    my ($self, $c) = @_;
    
    # Build and store information about CUFTS resources such
    # as whether they are active, display names, any notes, etc.

    my $site_id = $c->stash->{current_site}->id;

    if ( !($c->stash->{resources_display} = $c->session->{resources_display}->{$site_id}) ) {
        my %resources_display;
        my $resources_iter = CUFTS::DB::LocalResources->search( { 'site' => $site_id, 'active' => 't' } );

        while (my $resource = $resources_iter->next) {
            my $resource_id = $resource->id;
            my $global_resource = $resource->resource;

            $resources_display{$resource_id}->{cjdb_note} = $resource->cjdb_note;
            $resources_display{$resource_id}->{name} = not_empty_string($resource->name) 
                                                       ? $resource->name
                                                       : defined($global_resource)
                                                       ? $global_resource->name 
                                                       : '';
            if (!$c->stash->{current_site}->cjdb_display_db_name_only) {
                my $provider = not_empty_string($resource->provider) 
                               ? $resource->provider
                               : defined($global_resource)
                               ? $global_resource->provider 
                               : '';
                $resources_display{$resource_id}->{name} .= " - ${provider}";
            }
        }
        
        $c->stash->{resources_display}               = \%resources_display;
        $c->session->{resources_display}->{$site_id} = \%resources_display;
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
        CJDB::DB::DBI->dbi_rollback();
        CUFTS::DB::DBI->dbi_rollback();
    }

    return 1 if $c->response->status =~ /^3\d\d$/;
    return 1 if $c->response->body;

    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=iso-8859-1');
    }

    $c->response->headers->header( 'Cache-Control' => 'no-cache' );
    $c->response->headers->header( 'Pragma' => 'no-cache' );
    $c->response->headers->expires( time  );

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

    $c->response->headers->header( 'Cache-Control' => 'no-cache' );
    $c->response->headers->header( 'Pragma' => 'no-cache' );
    $c->response->headers->expires( time );

    $c->res->redirect($location);
}

##
## Define base level actions here and forward to controllers when necessary.
## This keeps everything as Local actions which makes handing the user back
## to the screen they were on for login/logout possible.
##

sub journal : Local {
    my ( $self, $c, $journals_auth_id ) = @_;

    $c->forward( '/journal/view', [$journals_auth_id] );
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
