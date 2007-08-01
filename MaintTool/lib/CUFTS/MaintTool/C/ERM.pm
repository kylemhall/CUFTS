package CUFTS::MaintTool::C::ERM;

use strict;
use base 'Catalyst::Base';

sub auto : Private {
    my ( $self, $c ) = @_;
    
    $c->stash->{header_section} = 'Global Resources';
    
    return 1;
}

sub default : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = "erm/menu.tt";
}


1;
