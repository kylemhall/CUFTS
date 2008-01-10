package CUFTS::CRDB::Controller::Resource::Field;

use strict;
use warnings;
use base 'Catalyst::Controller';

use CUFTS::Util::Simple;

=head1 NAME

CUFTS::CRDB::Controller::Resource::Field - Catalyst Controller for working with an individual fields in a resource.  This is generally for AJAX updates.

=head1 DESCRIPTION

Catalyst Controller

=head1 METHODS

=cut

my %handler_map = (
    consortia           => 'consortia',
    content_types       => 'content_types',
    resource_medium     => 'resource_medium',
    resource_type       => 'resource_type',
    subjects            => 'subjects',
);

my %data_type_handler_map = (
    varchar => 'text',
    text    => 'textarea',
    boolean => 'boolean',
);

sub base : Chained('/resource/load_resource') PathPart('field') CaptureArgs(0) {
    my ( $self, $c ) = @_;
    
    $c->assert_user_roles('edit_erm_records');
}

sub edit : Chained('base') PathPart('edit') Args(1) {
    my ( $self, $c, $field ) = @_;

    # Dispatch to appropriate field handler

    my $handler = $self->get_handler( $c, $field );
    
    die("Unable to find handler for field: $field") if !defined( $handler );
    
    $c->stash->{no_wrap} = 1;
    $c->forward( $handler, [ $field ] );
}

sub get_handler {
    my ( $self, $c, $field ) = @_;
    
    $c->stash->{display_field} = $c->model('CUFTS::ERMDisplayFields')->search( { field => $field } )->first();
    
    my $handler = $handler_map{$field};

    # Try to get a data type from the schema

    if ( !defined($handler) ) {
        my $data_type = $c->model('CUFTS::ERMMain')->result_source->column_info($field)->{data_type};
        
        warn( $data_type . ' - ' . $field );
        
        # Special cases
        
        if ( $data_type eq 'varchar' && $field =~ /_url$/ ) {
#            $handler = 'URL';
            $handler = 'text';  # Treat URL fields as text for now
        }
        else {
            $handler = $data_type_handler_map{$data_type};
        }
    }

    if ( defined($handler) ) {
        $handler = "edit_field_${handler}";
    }
    
    return $handler;
}

sub edit_field_consortia : Private {
    my ( $self, $c, $field ) = @_;

    if ( defined( $c->req->params->{$field} ) ) {

        # Add in validation here
        
        my $value = $c->req->params->{$field};
        if ( not_empty_string( $value) ) {
            my $count = $c->model('CUFTS::ERMConsortia')->search( site => $c->site->id, id => $value )->count();
            if ( $count < 1 ) {
                die("Attempt to update consortia to a value not appropriate for this site: $value");
            }
        }
        else {
            $value = undef;
        }

        $c->model('CUFTS')->schema->txn_do( sub {
            $c->stash->{erm}->set_column('consortia', $value );
            $c->stash->{erm}->update();
        } );
        
        $c->stash->{display_field_name} = $field;
        $c->stash->{template} = 'display_field.tt'
    }
    else {
        $c->stash->{field} = $field;
        $c->stash->{value} = $c->stash->{erm}->get_column('consortia');
        $c->stash->{options} = [ $c->model('CUFTS::ERMConsortia')->search( site => $c->site->id )->all ];
        $c->stash->{display_field} = 'consortia';
        $c->stash->{template} = 'fields/select.tt'
    }
}

sub edit_field_resource_medium : Private {
    my ( $self, $c, $field ) = @_;

    if ( defined( $c->req->params->{$field} ) ) {

        # Add in validation here
        
        my $value = $c->req->params->{$field};
        if ( not_empty_string( $value) ) {
            my $count = $c->model('CUFTS::ERMResourceMediums')->search( site => $c->site->id, id => $value )->count();
            if ( $count < 1 ) {
                die("Attempt to update resource_medium to a value not appropriate for this site: $value");
            }
        }
        else {
            $value = undef;
        }

        $c->model('CUFTS')->schema->txn_do( sub {
            $c->stash->{erm}->set_column('resource_medium', $value );
            $c->stash->{erm}->update();
        } );
        
        $c->stash->{display_field_name} = $field;
        $c->stash->{template} = 'display_field.tt'
    }
    else {
        $c->stash->{field} = $field;
        $c->stash->{value} = $c->stash->{erm}->get_column('resource_medium');
        $c->stash->{options} = [ $c->model('CUFTS::ERMResourceMediums')->search( site => $c->site->id )->all ];
        $c->stash->{display_field} = 'resource_medium';
        $c->stash->{template} = 'fields/select.tt'
    }
}

sub edit_field_resource_type : Private {
    my ( $self, $c, $field ) = @_;

    if ( defined( $c->req->params->{$field} ) ) {

        # Add in validation here
        
        my $value = $c->req->params->{$field};
        if ( not_empty_string( $value) ) {
            my $count = $c->model('CUFTS::ERMResourceTypes')->search( site => $c->site->id, id => $value )->count();
            if ( $count < 1 ) {
                die("Attempt to update resource_type to a value not appropriate for this site: $value");
            }
        }
        else {
            $value = undef;
        }

        $c->model('CUFTS')->schema->txn_do( sub {
            $c->stash->{erm}->set_column('resource_type', $value );
            $c->stash->{erm}->update();
        } );
        
        $c->stash->{display_field_name} = $field;
        $c->stash->{template} = 'display_field.tt'
    }
    else {
        $c->stash->{field} = $field;
        $c->stash->{value} = $c->stash->{erm}->get_column('resource_type');
        $c->stash->{options} = [ $c->model('CUFTS::ERMResourceTypes')->search( site => $c->site->id )->all ];
        $c->stash->{display_field} = 'resource_type';
        $c->stash->{template} = 'fields/select.tt'
    }
}


sub edit_field_text : Private {
    my ( $self, $c, $field ) = @_;

    if ( defined( $c->req->params->{$field} ) ) {

        # Add in validation here

        $c->model('CUFTS')->schema->txn_do( sub {
            $c->stash->{erm}->$field( $c->req->params->{$field} );
            $c->stash->{erm}->update();     
        } );
        
        $c->stash->{display_field_name} = $field;
        $c->stash->{template} = 'display_field.tt'
    }
    else {
        $c->stash->{field} = $field;
        $c->stash->{value} = $c->stash->{erm}->$field();
        $c->stash->{template} = 'fields/text.tt'
    }
}

sub edit_field_textarea : Private {
    my ( $self, $c, $field ) = @_;

    if ( defined( $c->req->params->{$field} ) ) {

        # Add in validation here

        $c->model('CUFTS')->schema->txn_do( sub {
            $c->stash->{erm}->$field( $c->req->params->{$field} );
            $c->stash->{erm}->update();     
        } );
        
        $c->stash->{display_field_name} = $field;
        $c->stash->{template} = 'display_field.tt'
    }
    else {
        $c->stash->{field} = $field;
        $c->stash->{value} = $c->stash->{erm}->$field();
        $c->stash->{template} = 'fields/textarea.tt'
    }
}


sub edit_field_boolean : Private {
    my ( $self, $c, $field ) = @_;

    if ( defined( $c->req->params->{$field} ) ) {

        # Add in validation here
        
        if ( $c->req->params->{$field} eq '' ) {
            $c->req->params->{$field} = undef;
        }

        $c->model('CUFTS')->schema->txn_do( sub {
            $c->stash->{erm}->$field( $c->req->params->{$field} );
            $c->stash->{erm}->update();     
        } );
        
        $c->stash->{display_field_name} = $field;
        $c->stash->{template} = 'display_field.tt'
    }
    else {
        $c->stash->{field} = $field;
        $c->stash->{value} = $c->stash->{erm}->$field();
        $c->stash->{template} = 'fields/boolean.tt'
    }
}


sub edit_field_text_field : Private {
    my ( $self, $c, $field ) = @_;
}


=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
