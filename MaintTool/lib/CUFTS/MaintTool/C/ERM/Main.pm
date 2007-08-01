package CUFTS::MaintTool::C::ERM::Main;

use strict;
use base 'Catalyst::Base';

use JSON::XS qw( to_json );

use CUFTS::DB::ERMMain;
use CUFTS::DB::ERMMainLink;
use CUFTS::DB::ERMSubjectsMain;

my $form_validate = {
    required => [
        qw(
            key
            main_name
        )
    ],
    optional => [
        qw(
            submit
            cancel

            vendor
            publisher
            resource_type
            resource_medium
            file_type
            description_brief
            description_full
            update_frequency
            coverage
            embargo_period
            pick_and_choose
            public
            public_list
            public_message
            subscription_status
            active_alert
            marc_available
            marc_history
            marc_alert
            requirements
            maintenance
            title_list_url
            help_url
            status_url
            resolver_enabled
            refworks_compatible
            refworks_info_url
            user_documentation
            simultaneous_users
            subscription_type
            subscription_notes
            subscription_ownership
            subscription_ownership_notes

            cost_base
            cost_base_notes
            gst
            pst
            payment_status
            contract_start
            contract_end
            original_term
            auto_renew
            renewal_notification
            notification_email
            notice_to_cancel
            requires_review
            review_notes
            local_bib
            local_vendor
            local_acquisitions
            consortia
            consortia_note
            date_cost_notes
            pricing_model
            subscription
            price_cap
            license_start_date

            stats_available
            stats_url
            stats_frequency
            stats_delivery
            stats_counter
            stats_user
            stats_password
            stats_notes
            counter_stats

            open_access
            admin_subscription_no
            admin_user
            admin_password
            admin_url
            support_url
            access_url
            public_account_needed
            public_user
            public_password
            training_user
            training_password
            marc_url
            ip_authentication
            referrer_authentication
            referrer_url
            openurl_compliant
            access_notes
            breaches7
            
            erm-edit-input-content-types
        )
    ],
    optional_regexp => qr/^erm-edit-input-subject/,
    constraints            => {
        contract_end       => qr/^\d{4}-\d{1,2}-\d{1,2}/,
        contract_start     => qr/^\d{4}-\d{1,2}-\d{1,2}/,
        license_start_date => qr/^\d{4}-\d{1,2}-\d{1,2}/,
    },
    js_constraints => {
        contract_end       => { dateISO => 'true' },
        contract_start     => { dateISO => 'true' },
        license_start_date => { dateISO => 'true' },
    },
    filters                => ['trim'],
    missing_optional_valid => 1,
};

my $form_validate_new = {
    required => [ qw( key name ) ],
    optional => [ qw( cancel save ) ],
    filters  => ['trim'],
    missing_optional_valid => 1,
};


sub auto : Private {
    my ( $self, $c ) = @_;

    my @load_options = (
        [ 'resource_types',   'resource_type',   'CUFTS::DB::ERMResourceTypes' ],
        [ 'resource_mediums', 'resource_medium', 'CUFTS::DB::ERMResourceMediums' ],
        [ 'subjects',         'subject',         'CUFTS::DB::ERMSubjects' ],
        [ 'content_types',    'content_type',    'CUFTS::DB::ERMContentTypes' ],
        [ 'consortias',       'consortia',       'CUFTS::DB::ERMConsortia' ],
        [ 'cost_bases',       'cost_base',       'CUFTS::DB::ERMCostBases' ],
    );
    
    foreach my $load_option ( @load_options ) {

        my ( $type, $field, $model ) = @$load_option;
        my @records = $model->search( { site => $c->stash->{current_site}->id }, { order_by => $field } );

        $c->stash->{"${field}_options"} = \@records;

        $c->stash->{$type}           = { map { $_->id => $_->$field } @records };
        $c->stash->{"${type}_order"} = [ map { $_->id } @records ];

        $c->stash->{"${type}_json"}  = to_json( $c->stash->{$type} );
        $c->stash->{"${field}_lookup"} = $c->stash->{$type};  # Alias for looking up when we have the "field" name rather than the type name.

    }

    return 1;
}



sub default : Private {
    my ( $self, $c ) = @_;

    warn('HERE!');
    $c->stash->{template} = "erm/main/find.tt";
    push( @{ $c->stash->{load_css} }, "erm_find.css" );

    return 1;
}

sub find : Local {
    my ( $self, $c, @facets ) = @_;

    my $facets = {};
    while ( my ( $type, $data ) = splice( @facets, 0, 2 ) ) {
        $facets->{$type} = $data;
    }

    $c->stash->{records}  = CUFTS::DB::ERMMain->facet_search( $c->stash->{current_site}->id, $facets, 1 );
    $c->stash->{facets}   = $facets;
    $c->stash->{template} = "erm/main/find.tt";
    push( @{ $c->stash->{load_css} }, "erm_find.css" );

    return 1;
}

sub ajax_details : Local {
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

    my @subjects = $erm_obj->subjects();
    @{ $erm_hash->{subjects} } = map { $_->subject } sort { $a->subject cmp $b->subject } @subjects;

    my @content_types = $erm_obj->content_types;
    @{ $erm_hash->{content_types} } = map { $_->content_type } sort { $a->content_type cmp $b->content_type } @content_types;

    $c->res->body( to_json( $erm_hash ) );
}


sub count_facets : Local {
    my ( $self, $c, @facets ) = @_;

    my $facets = {};
    while ( my ( $type, $data ) = splice( @facets, 0, 2 ) ) {
        $facets->{$type} = $data;
    }

    my $count = CUFTS::DB::ERMMain->facet_count( $c->stash->{current_site}->id, $facets );
    $c->res->body( '<span class="resources-facet-count">' . $count . '</span>' );
}



sub create : Local {
    my ( $self, $c ) = @_;

    return $c->redirect('/erm/main/') if $c->req->params->{cancel};
        
    if ( $c->req->params->{save} ) {

        $c->form( $form_validate_new );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {

            my $erm;
            eval {
                $erm = CUFTS::DB::ERMMain->create({
                    site => $c->stash->{current_site}->id,
                    key  => $c->form->{valid}->{key},
                });
                
                $erm->main_name( $c->form->{valid}->{name} );

            };

            if ($@) {
                my $err = $@;
                CUFTS::DB::DBI->dbi_rollback;
                die($err);
            }

            CUFTS::DB::DBI->dbi_commit;

            return $c->redirect( "/erm/main/edit/" . $erm->id );

        }

    }

    $c->stash->{template}  = "erm/main/create.tt";

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( 'erm-create', $form_validate_new, 'erm-create-' ) ];
}



sub edit : Local {
    my ( $self, $c, $erm_id  ) = @_;

    $c->req->params->{cancel}
        and return $c->redirect('/erm/main/');

    
    my $erm = CUFTS::DB::ERMMain->search({
        id   => $erm_id,
        site => $c->stash->{current_site}->id,
    })->first;

    if ( !defined($erm) ) {
        die("Unable to find ERMMain record: $erm_id for site " . $c->stash->{current_site}->id);
    }
    my %active_content_types = ( map { $_->id, 1 } $erm->content_types() );
    
    if ( $c->req->params->{submit} ) {

        $c->form( $form_validate );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {
            eval {
                $erm->update_from_form( $c->form );

                $erm->main_name( $c->form->{valid}->{main_name} );

                # Handle content type changes
                
                my $content_types_values = $c->form->{valid}->{'erm-edit-input-content-types'};
                if ( defined($content_types_values) ) {
                    if ( !ref($content_types_values) ) {
                        $content_types_values = [ $content_types_values ];
                    }
                    foreach my $content_type_id ( @{$content_types_values} ) {
                        if ( $active_content_types{$content_type_id} ) {
                            delete $active_content_types{$content_type_id};
                        }
                        else {
                            $erm->add_to_content_types( { content_type => $content_type_id } );
                        }
                    }
                    foreach my $content_type_id ( keys %active_content_types ) {
                        CUFTS::DB::ERMContentTypesMain->search( { erm_main => $erm_id, content_type => $content_type_id } )->delete_all;
                    }
                }
                
                # Handle subject changes
                
                foreach my $param ( keys %{ $c->form->{valid} } ) {
                    if ( $param =~ /^erm-edit-input-subject-(\d+)-subject$/ ) {
                        my $erm_main_subject_id    = $1;
                        my $erm_main_subject_value = $c->form->{valid}->{$param};

                        warn("subject_main_id: $erm_main_subject_id\nvalue: $erm_main_subject_value\n");
                    
                        my $erm_subjects_main = CUFTS::DB::ERMSubjectsMain->search({
                            erm_main => $erm_id,   # include for security - don't grab other sites' subjects
                            id => $erm_main_subject_id,
                        })->first();
                    
                        if ( $erm_main_subject_value eq 'delete' ) {
                            warn("Deleting subject");
                            $erm_subjects_main->delete();
                        }
                        else {
                            warn("Updating subject");
                            $erm_subjects_main->subject( $erm_main_subject_value );
                            $erm_subjects_main->rank( $c->form->{valid}->{"erm-edit-input-subject-${erm_main_subject_id}-rank"} );
                            $erm_subjects_main->description( $c->form->{valid}->{"erm-edit-input-subject-${erm_main_subject_id}-description"} );
                            $erm_subjects_main->update;
                        }
                    }
                    elsif ( $param =~ /^erm-edit-input-subject-add-subject-(\d+)$/ ) {
                        warn("Creating new subject");
                        my $erm_add_id = $1;
                        CUFTS::DB::ERMSubjectsMain->create({
                            erm_main    => $erm_id,
                            subject     => $c->form->{valid}->{"erm-edit-input-subject-add-subject-${erm_add_id}"},
                            rank        => $c->form->{valid}->{"erm-edit-input-subject-add-rank-${erm_add_id}"},
                            description => $c->form->{valid}->{"erm-edit-input-subject-add-description-${erm_add_id}"},
                        });
                    }
                
                }
            };
            
            if ($@) {
                my $err = $@;
                CUFTS::DB::DBI->dbi_rollback;
                die($err);
            }

            CUFTS::DB::DBI->dbi_commit;
            push @{ $c->stash->{results} }, 'ERM data updated.';
        }
    }

    $c->stash->{active_content_types} = { map { $_->id, 1 } $erm->content_types() };
    $c->stash->{erm}       = $erm;
    $c->stash->{erm_id}    = $erm_id;
    $c->stash->{template}  = "erm/main/edit.tt";

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( "main-form", $form_validate, 'erm-edit-input-' ) ];
    push( @{ $c->stash->{load_css} }, "tabs.css" );

    return 1;
}

1;
