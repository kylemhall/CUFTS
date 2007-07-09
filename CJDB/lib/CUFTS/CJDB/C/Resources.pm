package CUFTS::CJDB::C::Resources;

use strict;
use base 'Catalyst::Base';
use CUFTS::Util::Simple;

use Data::Dumper;
use JSON::XS;
use CUFTS::DB::LocalResources;

sub default : Private {
    my ( $self, $c ) = @_;

    $c->redirect('/resources/browse/');
}

sub resource : Local {
    my ( $self, $c, $id ) = @_;

    $c->stash->{erm} = CUFTS::DB::ERMMain->retrieve($id);
    $c->stash->{template} = 'resources/resource.tt';
}

sub ajax_resource : Local {
    my ( $self, $c, $id ) = @_;

    
    my $erm_obj = CUFTS::DB::ERMMain->retrieve( $id );
    my $erm_hash = {
        subjects => [],
        content_types => [],
    };
    
    foreach my $column ( $erm_obj->columns() ) {
        $erm_hash->{$column} = $erm_obj->$column();
    }
    foreach my $column ( qw( consortia cost_base resource_medium resource_type ) ) {
        if ( defined( $erm_hash->{$column} ) ) {
            $erm_hash->{$column} = $erm_obj->$column()->$column();
        }
    }

    my @subjects = $erm_obj->subjects;
    foreach my $subject ( @subjects ) {
        push @{ $erm_hash->{subjects} }, $subject->subject;
    }

    my @content_types = $erm_obj->content_types;
    foreach my $content_type ( @content_types ) {
        push @{ $erm_hash->{content_types} }, $content_type->content_type;
    }

    $c->res->body( to_json( $erm_hash ) );
}

sub list : Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'resources/list.tt';
}

sub chart : Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'resources/chart.tt';
}

sub title : Local {
    my ( $self, $c, $letter ) = @_;
    
    my @erm_records = CUFTS::DB::ERMMain->search(
        {
            site      => $c->stash->{current_site}->id,
            public    => 't',
            resource  => { ilike => "${letter}%" },
    
        },
        { order_by => 'lower(resource)' },
    );

    $c->stash->{erms}     = \@erm_records;
    $c->stash->{template} = 'resources/test.tt';
}


1;
