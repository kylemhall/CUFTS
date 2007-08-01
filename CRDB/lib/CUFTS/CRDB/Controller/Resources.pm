package CUFTS::CRDB::Controller::Resources;

use strict;
use warnings;
use base 'Catalyst::Controller';

use JSON::XS qw(to_json);

=head1 NAME

CUFTS::CRDB::Controller::Resources - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for actions against sets of resources.

=head1 METHODS

=cut


sub base : Chained('/site') PathPart('resources') CaptureArgs(0) {}

=head2 edit_erm_records

Check roles to make sure user has rights to edit resources.

=cut

sub edit_erm_records : Chained('base') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;
    
    $c->assert_user_roles('edit_erm_records');
}


=head2 rerank 

AJAX action for reranking a set of resources using drag and drop sortables.

=cut

sub rerank : Chained('edit_erm_records') PathPart('rerank') Args(0) {
    my ( $self, $c ) = @_;

    $c->form({ required => [ qw( subject resource_order ) ] });
    unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
        my $subject = $c->form->{valid}->{subject};
        my %records = map { $_->erm_main => $_ } $c->model('CUFTS::ERMSubjectsMain')->search( { subject => $subject } )->all;

        my $rank = 0;
        my $schema =  $c->model('CUFTS')->schema;
        my $update_transaction = sub {
            foreach my $resource_id ( reverse @{ $c->form->{valid}->{resource_order} } ) {
                my $record = $records{$resource_id};
                if ( !defined($record) ) {
                    die("Unable to find matching ERM record ($resource_id) in subject ($subject)" );
                }
                $record->rank($rank);
                $record->update;
                $rank++;
             }
             return 1;
        };

        $c->model('CUFTS')->schema->txn_do( $update_transaction );
    }

    $c->response->body( to_json( { update => 'success' } ) );
}

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
