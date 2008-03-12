package CUFTS::CRDB::Controller::Browse;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON::XS qw(encode_json);
use CUFTS::Util::Simple;

=head1 NAME

CUFTS::CRDB::Controller::Browse - Catalyst Controller for browsing ERM resources

=head1 DESCRIPTION

Catalyst Controller

=head1 METHODS

=cut

sub base : Chained('/site') PathPart('browse') CaptureArgs(0) {}

sub facet_options : Chained('/facet_options') PathPart('browse') CaptureArgs(0) {}

=head2 browse_index 

=cut

sub browse_index : Chained('facet_options') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    $c->save_current_action();

    $c->stash->{template} = 'browse.tt';
}


=head2 facet_form

Translate form parameters into a facet search path and redirect so the standard search handler runs.

=cut

sub facet_form : Chained('base') PathPart('facet_form') Args(0) {
    my ( $self, $c ) = @_;
    
    my $action = 'html_facets';
    
    my @search_facets;
    foreach my $param ( keys %{ $c->req->params } ) {
        my $values = $c->req->params->{$param};

        # Special case to allow specifying JSON format as a parameter
        if ( $param eq 'format' && $values eq 'json' ) {
            $action = 'json_facets';
            next;
        }

        if ( ref($values) ne 'ARRAY' ) {
            $values = [ $values ];
        }
        foreach my $value ( @$values ) {
            push @search_facets, $param, $value;
        }
    }

    return $c->redirect( $c->uri_for_site( $c->action_for('html_facets'), @search_facets, {} ) );
}

=head2 _facet_search

Builds the facet search from a list of facets and returns a result set.

=cut

sub _facet_search  {
    my ( $self, $c, $facet_list ) = @_;

    my $facets = {};
    while ( my ( $type, $data ) = splice( @$facet_list, 0, 2 ) ) {
        $facets->{$type} = $data;
    }
    
    my $search = { %{$facets} };
    $search->{public_list} = 't';

    $c->stash->{facets} = $facets;

    return $c->model('ERMMain')->facet_search( $c->site->id, $search );
}



=head2 json_facets

Returns the results of a facet search in JSON.  Facets are specified as part of the URL.

=cut

sub html_facets : Chained('facet_options') PathPart('facets') Args {
    my ( $self, $c, @facets ) = @_;

    my $rs = $self->_facet_search( $c, \@facets );
    my @records = $rs->all();

    if ( exists( $c->stash->{facets}->{subject} ) ) {
        # Rank sort for subjects
        @records = sort { int($a->rank) <=> int($b->rank) or $a->sort_name cmp $b->sort_name } @records;
        # Put zeros at the end
        my $unranked = 0;
        foreach my $record ( @records ) {
            last if $record->rank != 0;
            $unranked++;
        }
        push @records, splice @records, 0, $unranked;
        
        # Put the subject into the stash in case we need the subject description
        $c->stash->{subject_description} = $c->model('CUFTS::ERMSubjects')->find( $c->stash->{facets}->{subject} )->description;

    }
    else {
        # Default to title sort
        @records = sort { $a->sort_name cmp $b->sort_name } @records;
    }

    $c->save_current_action();

    $c->stash->{template} = 'browse.tt';
    $c->stash->{records}  = \@records;
}


=head2 json_facets

Returns the results of a facet search in JSON.  Facets are specified as part of the URL.

=cut

sub json_facets : Chained('facet_options') PathPart('facets/json') Args {
    my ( $self, $c, @facets ) = @_;

    my $rs = $self->_facet_search( $c, \@facets );

    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');  # Get a hash so the JSON view can convert
    my @records = $rs->all();

    if ( exists( $c->stash->{facets}->{subject} ) ) {
        # Rank sort for subjects
        @records = sort { int($a->{rank}) <=> int($b->{rank}) or $a->{sort_name} cmp $b->{sort_name} } @records;
    }
    else {
        # Default to title sort
        @records = sort { $a->{sort_name} cmp $b->{sort_name} } @records;
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

    my $rs = $self->_facet_search( $c, \@facets );
 
    # Flatten the facets hash to produce a cache key
    my $cache_key = $c->site->id . ' ' . join( ' ', map { $_ . ' ' . $c->stash->{facets}->{$_} } sort keys %{$c->stash->{facets}} );

    # Add caching in server session?
    my $count = $c->cache->get( $cache_key ); 
    if ( !defined($count) ) {
        $count = $rs->count();
        $c->cache->set( $cache_key, $count );
    }

    $c->stash->{json}->{count} = $count;
    $c->stash->{current_view}  = 'JSON';
}

=head2 subject_description

Changes the subject description for a whole subject, applied to the ERMSubjects record.  For subjects descriptions
specific to a resource see CUFTS::CRDB::Controller::Resources::subject_description

=cut

sub subject_description : Chained('base') PathPart('subject_description') Args(0) {
    my ( $self, $c ) = @_;

    $c->form({
        required => [ qw( subject_id ) ], 
        optional => [ qw( change subject_description ) ] 
    });
    
    unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {

        my $subject_id  = $c->form->{valid}->{subject_id};

        my $subject  = $c->model('CUFTS::ERMSubjects')->find( $subject_id )
            or die("Unable to find subject record.");

        if ( $c->form->{valid}->{change} ) {

            # Try to change the description
            
            my $description = $c->form->{valid}->{subject_description};
            $description = trim_string( $description );
            $description = undef if is_empty_string( $description );

            $subject->description( $description );
            $subject->update();

        }

        $c->stash->{json}->{subject_description} = $subject->description;

    }

    $c->stash->{current_view} = 'JSON';
}


=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
