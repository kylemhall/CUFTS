package CUFTS::CJDB::C::Resources;

use strict;
use base 'Catalyst::Base';
use CUFTS::Util::Simple;

use Data::Dumper;

use CUFTS::DB::LocalResources;

sub default : Private {
    my ( $self, $c ) = @_;

    warn('default');

    $c->redirect('/resources/browse/');
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
