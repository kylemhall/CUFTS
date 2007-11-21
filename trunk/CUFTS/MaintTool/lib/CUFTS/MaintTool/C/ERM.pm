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
        my $MARC = MARC::Record->new();

        if ( not_empty_string( $erm_record->isbn ) ) {
            $MARC->append_fields( MARC::Field->new( '020', '', '', 'a' => $erm_record->isbn ) );
        }

        if ( not_empty_string( $erm_record->issn ) ) {
            $MARC->append_fields( MARC::Field->new( '022', '', '', 'a' => $erm_record->issn ) );
        }

        if ( not_empty_string( $erm_record->journal_auth ) ) {
            $MARC->append_fields( MARC::Field->new( '035', '', '', 'a' => $erm_record->journal_auth ) );
        }

        $MARC->append_fields( MARC::Field->new( '245', '', '', 'a' => $erm_record->main_name ) );
        $MARC->append_fields( MARC::Field->new( '930', '', '', 'a' => $erm_record->id ) );

        my @subfields;

        if ( not_empty_string( $erm_record->local_fund ) ) {
            push @subfields, 'u', $erm_record->local_fund;
        }

        if ( not_empty_string( $erm_record->vendor ) ) {
            push @subfields, 'v', $erm_record->vendor;
        }
        
        if ( scalar(@subfields) ) {
            $MARC->append_fields( MARC::Field->new( '960', '', '', @subfields ) );
        }

        @subfields = ();

        if ( not_empty_string( $erm_record->currency ) ) {
            push @subfields, 'z', $erm_record->currency;
        }

        if ( not_empty_string( $erm_record->currency ) ) {
            push @subfields, 'c', $erm_record->currency;
        }

        if ( not_empty_string( $erm_record->local_vendor ) ) {
            push @subfields, 'i', $erm_record->local_vendor;
        }

        if ( scalar(@subfields) ) {
            $MARC->append_fields( MARC::Field->new( '961', '', '', @subfields ) );
        }

        $MARC_dump .= $MARC->as_usmarc();

    }

    $c->res->body( $MARC_dump );
}

1;
