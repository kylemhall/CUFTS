package CUFTS::MaintTool::C::ERM;

use strict;
use base 'Catalyst::Base';

use JSON::XS qw( to_json );

sub auto : Private {
    my ( $self, $c ) = @_;
    
    $c->stash->{header_section} = 'Global Resources';
    
    return 1;
}

sub default : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = "erm/menu.tt";
}

sub summary : Local {
    my ( $self, $c, $erm_main_id ) = @_;
    
    my $erm_main = CUFTS::DB::ERMMain->search( { site => $c->stash->{current_site}->id, id => $erm_main_id } )->first;
    if ( !defined($erm_main) ) {
        die("No matching ERM Main record for current site");
    }
    
    $c->stash->{no_wrap} = 1;
    $c->stash->{erm_main} = $erm_main;
    $c->stash->{template} = 'erm/summary.tt';
}

1;
