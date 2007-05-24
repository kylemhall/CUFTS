package CUFTS::MaintTool::C::Site::ERM;

use strict;
use base 'Catalyst::Base';

use CUFTS::Util::Simple;

my $edit_form_validate = {
    optional => [ qw( submit cancel ) ],
    optional_regexp => qr/^(consortia|content_types|cost_bases|resource_types|resource_mediums|subjects)/,
    filters => ['trim'],
};


sub auto : Private {
    my ( $self, $c ) = @_;
    $c->stash->{section} = 'erm';
}

sub edit : Local {
    my ( $self, $c ) = @_;
    
    my @tables = qw( consortia content_types cost_bases resource_mediums resource_types subjects );

    my %db_classes = (
        consortia        => 'CUFTS::DB::ERMConsortia',
        content_types    => 'CUFTS::DB::ERMContentTypes',
        cost_bases       => 'CUFTS::DB::ERMCostBases',
        resource_mediums => 'CUFTS::DB::ERMResourceMediums',
        resource_types   => 'CUFTS::DB::ERMResourceTypes',
        subjects         => 'CUFTS::DB::ERMSubjects',
    );

    my %value_field = (
        consortia        => 'consortia',
        content_type     => 'content_type',
        cost_bases       => 'cost_base',
        resource_types   => 'resource_type',
        resource_mediums => 'resource_medium',
        subjects         => 'subject',
    );

    my %count_table = (
        consortia        => 'CUFTS::DB::ERMMain',
        content_types    => 'CUFTS::DB::ERMContentTypesMain',
        cost_bases       => 'CUFTS::DB::ERMMain',
        resource_mediums => 'CUFTS::DB::ERMMain',
        resource_types   => 'CUFTS::DB::ERMMain',
        subjects         => 'CUFTS::DB::ERMSubjectsMain',
    );

    my $site_id = $c->stash->{current_site}->id;

    # Process a form if present

    if ( $c->req->params->{cancel} ) {
        $c->redirect('/site/edit');
    }
    elsif ( $c->req->params->{submit} ) {

        $c->form( $edit_form_validate );

        my $records = {};

        # Load database records for each class

        foreach my $table ( @tables ) {
            my $db_class = $db_classes{$table};
            %{ $records->{$table} } = map { $_->id, $_ } $db_class->search( site => $site_id );
        }

        # Deletes

        foreach my $param ( keys %{ $c->req->params } ) {
            if ( $param =~ /^(cost_bases|consortia|content_types|resource_types|resource_mediums|subjects)_delete$/ ) {
                my $table = $1;
                my $method = $value_field{$table};
                my @ids = $c->form->valid->{$param};

                # Check for multiple deletions in the same group
                
                if ( ref $ids[0] ) {
                    @ids = @{ $ids[0] };  
                }

                foreach my $id ( @ids ) {
                    my $value = $records->{$table}->{$id}->$method;
                    $records->{$table}->{$id}->delete;
                    delete $records->{$table}->{$id};
                    push @{ $c->stash->{results} }, "Deleted: $value";
                }
            }
        }

        # Updates

        foreach my $param ( keys %{ $c->req->params } ) {
            if ( $param =~ /^(cost_bases|consortia|content_types|resource_types|resource_mediums|subjects)_(\d+)$/ ) {
                my $method = $value_field{$1};
                my $record = $records->{$1}->{$2};
                next if !defined($record);    # Record was deleted
                my $value  = $c->form->valid->{$param};

                if ( is_empty_string( $value ) ) {
                    push @{ $c->stash->{errors} }, "Updated field is empty.  Use the delete box to remove entries.";
                    next;
                }
                
                if ( $value ne $record->$method ) {
                    $record->$method( $c->req->params->{$param} );
                    $record->update;
                    push @{ $c->stash->{results} }, "Updated: $value";
                }
            }
        }

        # New entries

        foreach my $param ( keys %{ $c->req->params } ) {
            if ( $param =~ /^(cost_bases|consortia|content_types|resource_types|resource_mediums|subjects)_new$/ ) {
                my $table = $1;
                my $value = $c->form->valid->{$param};
                next if is_empty_string( $value );

                my $db_class = $db_classes{$table};
                my $field    = $value_field{$table};
                
                my $new_record = $db_class->create({
                    site =>   $site_id,
                    $field => $value,
                });
                
                push @{ $c->stash->{results} }, "Added: " . $new_record->$field;
            }
        }

        if ( !exists($c->stash->{errors}) ) {
            CUFTS::DB::DBI->dbi_commit;
            
            # Reload the records from the database to make sure what is displayed matches properly
            
            $records = {};
            foreach my $table ( @tables ) {
                my $db_class = $db_classes{$table};
                %{ $records->{$table} } = map { $_->id, $_ } $db_class->search( site => $site_id );
            }

        }
        else {
            delete $c->stash->{results};
            CUFTS::DB::DBI->dbi_rollback;
        }

    }

    # Load records into lists to put in the stash for display

    foreach my $table ( @tables ) {
        my $db_class     = $db_classes{$table};
        my $method       = $value_field{$table};
        my $count_table  = $count_table{$table};

        # Put all records into ordered lists

        @{ $c->stash->{$table} } = $db_class->search( site => $site_id, { order_by => $method } );

        # Get counts for each record to see if they're in use

        @{ $c->stash->{"${table}_count"} } = map { $count_table->count_search( $method => $_ ) } @{ $c->stash->{$table} };
    }

    $c->stash->{template} = 'site/erm/edit.tt';

}

=head1 NAME

CUFTS::MaintTool::C::Site::ERM - Component for ERM related data

=head1 SYNOPSIS

Handles site editing, changing sites, etc.

=head1 DESCRIPTION

Handles site editing, changing sites, etc.

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;

