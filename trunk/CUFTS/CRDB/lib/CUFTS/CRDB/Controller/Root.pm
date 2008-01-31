package CUFTS::CRDB::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON::XS qw(encode_json);

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

CUFTS::CRDB::Controller::Root - Root Controller for CUFTS::CRDB

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 site

Uses chained paths to get the site key from the URL.

=cut

sub site : Chained('/') PathPart('') CaptureArgs(1) {
    my ($self, $c, $site_key) = @_;
    
    my $site = $c->model('CUFTS::Sites')->search( { key => $site_key } )->first;
    if ( !defined($site) ) {
        die("Unrecognized site key: $site_key");
    }
    
    # TODO: Add support for sandbox
    
    # Set up site specific CSS file if it exists
    
    my $site_css =   '/sites/' . $site->id . '/static/css/active/crdb.css';
                  
    if ( -e ($c->config->{root} . $site_css) ) {
        $c->stash->{site_css_file} = $c->uri_for( $site_css );
    }
    
    $c->stash->{additional_template_paths} = [ $c->config->{root} . '/sites/' . $site->id . '/active' ];    
    $c->stash->{extra_js} = [];
    $c->site( $site );
    
    return 1;
}

sub facet_options : Chained('site') PathPart('') CaptureArgs(0) {

    my ( $self, $c ) = @_;
    
    my @load_options = (
        [ 'resource_types',   'resource_type',   'CUFTS::ERMResourceTypes' ],
        [ 'resource_mediums', 'resource_medium', 'CUFTS::ERMResourceMediums' ],
        [ 'subjects',         'subject',         'CUFTS::ERMSubjects' ],
        [ 'content_types',    'content_type',    'CUFTS::ERMContentTypes' ],
    );
    
    foreach my $load_option ( @load_options ) {
        my ( $type, $field, $model ) = @$load_option;

        $c->stash->{$type} = $c->cache->get( $c->site->id . " $type" );
        $c->stash->{"${type}_order"} = $c->cache->get( $c->site->id . " ${type}_order" );
        
        unless ( $c->stash->{$type} && $c->stash->{"${type}_order"} ) {

            my @records = $c->model($model)->search( site => $c->site->id, { order_by => $field } )->all;

            $c->stash->{$type}           = { map { $_->id => $_->$field } @records };
            $c->stash->{"${type}_order"} = [ map { $_->id } @records ];

            $c->cache->set( $c->site->id . " $type" , $c->stash->{$type} );
            $c->cache->set( $c->site->id . " ${type}_order" , $c->stash->{"${type}_order"} );

        }

        $c->stash->{"${type}_json"}    = encode_json( $c->stash->{$type} );
        $c->stash->{"${field}_lookup"} = $c->stash->{$type};  # Alias for looking up when we have the "field" name rather than the type name.
    }

}



=head2 default

=cut
sub app_root : Chained('facet_options') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'main.tt';
}


sub default : Private {
    my ( $self, $c ) = @_;
    $c->response->status(404);
    $c->detach();
#    $c->response->body( 'Not found' );
}


sub test : Global {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'test.tt';
}


sub exit : Global {
    my ( $self, $c ) = @_;
    
    exit();
}


=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') { }

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
