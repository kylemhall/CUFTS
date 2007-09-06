package CUFTS::CRDB::Controller::Browse;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON::XS qw(to_json);

=head1 NAME

CUFTS::CRDB::Controller::Browse - Catalyst Controller for browsing ERM resources

=head1 DESCRIPTION

Catalyst Controller

=head1 METHODS

=cut

sub base : Chained('/site') PathPart('browse') CaptureArgs(0) {
    my ( $self, $c ) = @_;
}

sub options : Chained('base') PathPart('') CaptureArgs(0) {
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

        $c->stash->{"${type}_json"}  = to_json( $c->stash->{$type} );
        $c->stash->{"${field}_lookup"} = $c->stash->{$type};  # Alias for looking up when we have the "field" name rather than the type name.
    }
}

=head2 browse_index 

=cut

sub browse_index : Chained('options') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    $c->save_current_action();

    $c->stash->{template} = 'browse.tt';
}

=head2 facets 

=cut


sub facets : Chained('options') PathPart('facets') Args {
    my ( $self, $c, @facets ) = @_;

    $c->save_current_action();

    my $facets = {};
    while ( my ( $type, $data ) = splice( @facets, 0, 2 ) ) {
        $facets->{$type} = $data;
    }
    
    my $search = { %{$facets} };
    $search->{public_list} = 't';

    my @records = $c->model('ERMMain')->facet_search( $c->site->id, $search )->all();
    if ( exists( $facets->{subject} ) ) {
        # Rank sort for subjects
        @records = sort { $a->rank cmp $b->rank or $a->sort_name cmp $b->sort_name } @records;
    }
    else {
        # Default to title sort
        @records = sort { $a->sort_name cmp $b->sort_name } @records;
    }

    $c->stash->{records}  = \@records;
    $c->stash->{facets}   = $facets;
    $c->stash->{template} = 'browse.tt';
}

=head2 results

Returns the results of a facet search in JSON.  Facets are specified as part of the URL.

=cut

sub json_facets : Chained('base') PathPart('json_facets') Args {
    my ( $self, $c, @facets ) = @_;

    my $facets = {};
    while ( my ( $type, $data ) = splice( @facets, 0, 2 ) ) {
        $facets->{$type} = $data;
    }

    my $search = { %{$facets} };
    $search->{public_list} = 't';

    my @records = $c->model('ERMMain')->facet_search( $c->site->id, $search )->all();
    if ( exists( $facets->{subject} ) ) {
        # Rank sort for subjects
#        @records = sort { $a->rank cmp $b->rank or $a->sort_name cmp $b->sort_name } @records;
    }
    else {
        # Default to title sort
#        @records = sort { $a->sort_name cmp $b->sort_name } @records;
    }
    
    $c->stash->{json}->{records} = \@records;

    $c->stash->{current_view}  = 'JSON';
}

=head2 count_facets

Returns a JSON object containing the number of records in a facet search.  This is used
to display estimated results when choosing facetes, and may be used to pre-count facets choices.
Caching per site is used to avoid hitting the database constantly.  Cache keys look like:

site_id [facet_type facet_data]...

=cut

sub count_facets : Chained('base') PathPart('count_facets') Args {
    my ( $self, $c, @facets ) = @_;

    my %facets;
    while ( my ( $type, $data ) = splice( @facets, 0, 2 ) ) {
        $facets{$type} = $data;
    }

    my $cache_key = $c->site->id . ' ' . join( ' ', map { $_ . ' ' . $facets{$_} } sort keys %facets );

    # Add caching in server session?
    my $count = $c->cache->get( $cache_key ); 
    if ( !defined($count) ) {

        my $search = { %facets };
        $search->{public_list} = 't';

        $count = $c->model('ERMMain')->facet_search( $c->site->id, $search )->count();
        $c->cache->set( $cache_key, $count );
    }

    $c->stash->{json}->{count} = $count;

    $c->stash->{current_view}  = 'JSON';
}



=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
