package CUFTS::MaintTool::C::ERM;

use strict;
use base 'Catalyst::Base';

use CUFTS::Util::Simple;
use JSON::XS qw( to_json );
use MARC::Record;

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

sub marc_dump : Local {
    my ( $self, $c ) = @_;
    
    
    my $MARC_dump;
    
    my @erm_records = CUFTS::DB::ERMMain->search( { site => $c->stash->{current_site}->id } );
    foreach my $erm_record ( @erm_records ) {
        if ( $c->req->params('text') eq '1' ) {
            $MARC_dump .= $erm_record->as_marc()->as_formatted();
        }
        else {
            $MARC_dump .= $erm_record->as_marc()->as_usmarc();
        }
    }

    if ( $c->req->params('text') eq '1' ) {
        $c->res->content_type( 'text/plain' );
    }
    else {
        $c->res->content_type( 'application/marc' );
    }
    
    $c->res->body( $MARC_dump );
}

1;
