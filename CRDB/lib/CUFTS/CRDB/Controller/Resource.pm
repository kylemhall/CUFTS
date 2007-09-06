package CUFTS::CRDB::Controller::Resource;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME

CUFTS::CRDB::Controller::Resource - Catalyst Controller for working with an individual ERM resource

=head1 DESCRIPTION

Catalyst Controller

=head1 METHODS

=cut

use CUFTS::DB::ERMMain;

sub base : Chained('/site') PathPart('resource') CaptureArgs(0) { }

sub load_resource : Chained('base') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $resource_id ) = @_;
    
    $c->stash->{erm} = CUFTS::DB::ERMMain->retrieve( $resource_id );
}



=head2 default_view

Default is to view the resource.

=cut

sub default_view : Chained('load_resource') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    $c->save_current_action();
    
    $c->stash->{template} = 'resource.tt';
}

=head2 json

Packages up a bunch of information about the resource, and returns it in JSON.  This is
used for things like the pop-up resource details.

=cut


sub json : Chained('load_resource') PathPart('json') Args(0) {
    my ( $self, $c ) = @_;

    my $erm_obj = $c->stash->{erm};
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
    @{ $erm_hash->{subjects} } = map { $_->subject } sort { $a->subject cmp $b->subject } @subjects;

    my @content_types = $erm_obj->content_types;
    @{ $erm_hash->{content_types} } = map { $_->content_type } sort { $a->content_type cmp $b->content_type } @content_types;

    if ( my $license = $erm_hash->{license} ) {
        $erm_hash->{license} = {};
        foreach my $column ( $license->columns() ) {
            $erm_hash->{license}->{$column} = $license->$column();
        }
    }

    $c->stash->{json} = $erm_hash;

    $c->stash->{current_view} = 'JSON';
}

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
