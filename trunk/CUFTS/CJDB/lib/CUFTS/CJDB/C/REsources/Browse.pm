package CUFTS::CJDB::C::Resources::Browse;

use strict;
use base 'Catalyst::Base';
use CUFTS::Util::Simple;

use Data::Dumper;

use CUFTS::DB::LocalResources;

sub default : Private {
    my ( $self, $c ) = @_;

    my $records;
    if ( scalar( keys( %{$c->session->{resources_browse_facets}} ) ) ) {
        $records = CUFTS::DB::ERMMain->facet_search( $c->stash->{current_site}->id, $c->session->{resources_browse_facets} );
    }
    my @resource_type_options   = CUFTS::DB::ERMResourceTypes->search(   site => $c->stash->{current_site}->id, { order_by => 'resource_type' }   );
    my @resource_medium_options = CUFTS::DB::ERMResourceMediums->search( site => $c->stash->{current_site}->id, { order_by => 'resource_medium' } );
    my @subject_options         = CUFTS::DB::ERMSubjects->search(        site => $c->stash->{current_site}->id, { order_by => 'subject' }         );
    
    $c->stash->{resource_types}   = \@resource_type_options;
    $c->stash->{resource_mediums} = \@resource_medium_options;
    $c->stash->{subject_options}  = \@subject_options;

    $c->stash->{records}  = $records;
    $c->stash->{facets}   = $c->session->{resources_browse_facets};
    $c->stash->{template} = 'resources/browse.tt';
}


sub add_facet : Local {
    my ( $self, $c, $type, $display, $data ) = @_;

    $c->session->{resources_browse_facets}->{$type}->{display} = $display;
    $c->session->{resources_browse_facets}->{$type}->{data}    = $data;

    $c->redirect('/resources/');
}

sub remove_facet : Local {
    my ( $self, $c, $type ) = @_;

    delete $c->session->{resources_browse_facets}->{$type};

    warn(Dumper($c->session->{resources_browse_facets}));
    
    $c->redirect('/resources/');
}

1;
