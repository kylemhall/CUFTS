package CUFTS::CJDB::C::Resources::Browse;

use strict;
use base 'Catalyst::Base';
use CUFTS::Util::Simple;

use Data::Dumper;
use JSON::XS;

use CUFTS::DB::LocalResources;

sub auto : Private {
    my ( $self, $c ) = @_;
    
    my @resource_type_options   = CUFTS::DB::ERMResourceTypes->search(   site => $c->stash->{current_site}->id, { order_by => 'resource_type' }   );
    my @resource_medium_options = CUFTS::DB::ERMResourceMediums->search( site => $c->stash->{current_site}->id, { order_by => 'resource_medium' } );
    my @subject_options         = CUFTS::DB::ERMSubjects->search(        site => $c->stash->{current_site}->id, { order_by => 'subject' }         );
    my @content_type_options    = CUFTS::DB::ERMContentTypes->search(    site => $c->stash->{current_site}->id, { order_by => 'content_type' }    );
    
    $c->stash->{resource_types}    = \@resource_type_options;
    $c->stash->{resource_mediums}  = \@resource_medium_options;
    $c->stash->{subject_options}   = \@subject_options;
    $c->stash->{content_types}     = \@content_type_options;
}

sub default : Private {
    my ( $self, $c ) = @_;

    if ( scalar( keys( %{$c->session->{resources_browse_facets}} ) ) ) {
        $c->stash->{records} = CUFTS::DB::ERMMain->facet_search( $c->stash->{current_site}->id, $c->session->{resources_browse_facets} );
        $c->stash->{facets}   = $c->session->{resources_browse_facets};
    }

    $c->stash->{template} = 'resources/browse.tt';
}


sub add_facet : Local {
    my ( $self, $c, $type, $display, $data ) = @_;

    $c->session->{resources_browse_facets}->{$type}->{display} = $display;
    $c->session->{resources_browse_facets}->{$type}->{data}    = $data;

    $c->redirect('/resources/');
}

sub set_facets : Local {
    my ( $self, $c, @facets ) = @_;
    
    $c->session->{resources_browse_facets} = {};
    while ( my ( $type, $display, $data ) = splice( @facets, 0, 3 ) ) {
        $c->session->{resources_browse_facets}->{$type}->{display} = $display;
        $c->session->{resources_browse_facets}->{$type}->{data}    = $data;
    }
    
    $c->redirect('/resources/');
}

sub count_facets : Local {
    my ( $self, $c, @facets ) = @_;

    my $facets = {};
    while ( my ( $type, $display, $data ) = splice( @facets, 0, 3 ) ) {
        $facets->{$type}->{display} = $display;
        $facets->{$type}->{data}    = $data;
    }

    # Add caching in server session?

    my $count = CUFTS::DB::ERMMain->facet_count( $c->stash->{current_site}->id, $facets );
    $c->res->body( '<span class="resources-facet-count">' . $count . '</span>' );
}

sub facets : Local {
    my ( $self, $c, @facets ) = @_;

    my $facets = {};
    while ( my ( $type, $display, $data ) = splice( @facets, 0, 3 ) ) {
        $facets->{$type}->{display} = $display;
        $facets->{$type}->{data}    = $data;
    }

    $c->stash->{records}  = CUFTS::DB::ERMMain->facet_search( $c->stash->{current_site}->id, $facets, 1 );
    $c->stash->{facets}   = $facets;
    $c->stash->{template} = 'resources/browse.tt';
}

sub remove_facet : Local {
    my ( $self, $c, $type ) = @_;

    delete $c->session->{resources_browse_facets}->{$type};
    $c->redirect('/resources/');
}

sub ajax_facets : Local {
    my ( $self, $c, @facets ) = @_;

    my $facets = {};
    while ( my ( $type, $display, $data ) = splice( @facets, 0, 3 ) ) {
        $facets->{$type}->{display} = $display;
        $facets->{$type}->{data}    = $data;
    }

    $c->res->body( to_json( CUFTS::DB::ERMMain->facet_search( $c->stash->{current_site}->id, $facets, 1 ) ) );
}

1;
