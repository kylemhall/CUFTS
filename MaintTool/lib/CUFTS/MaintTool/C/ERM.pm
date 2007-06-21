package CUFTS::MaintTool::C::ERM;

use strict;
use base 'Catalyst::Base';

use CUFTS::DB::ERMMain;
use CUFTS::DB::ERMMainLink;
use CUFTS::DB::ERMLicense;

my $form_validate = {
    main => {
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
                breaches
                
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
    },    
    license => {
        required => [
            qw(
                key
            )
        ],
        optional => [
            qw(
                submit
                cancel

                simultaneous_users
                full_on_campus_access
                full_on_campus_notes
                allows_remote_access
                allows_proxy_access
                allows_commercial_use
                allows_walkins
                allows_ill
                ill_notes
                allows_ereserves
                allows_coursepacks
                allows_distance_ed
                allows_downloads
                allows_prints
                allows_emails
                emails_notes
                allows_archiving
                own_data
                citation_requirements
                requires_print
                requires_print_plus
                additional_requirements
                allowable_downtime
                online_terms
                user_restrictions
                terms_notes
           
                contact_name
                contact_role
                contact_address
                contact_phone
                contact_fax
                contact_email
                contact_notes
            )
        ],
        filters  => ['trim'],
        missing_optional_valid => 1,
    },
};

my $form_validate_default = {
    required => [ qw( edit erm_id type ) ],
};

my $form_validate_new = {
    main => {
        required => [ qw( key name ) ],
        optional => [ qw( cancel save ) ],
        filters  => ['trim'],
        missing_optional_valid => 1,
    },
    license => {
        required => [ qw( key ) ],
        optional => [ qw( save cancel ) ],
        filters  => ['trim'],
        missing_optional_valid => 1,
    },
};

my %erm_classes = (
    main    => 'CUFTS::DB::ERMMain',
    license => 'CUFTS::DB::ERMLicense',
);

sub default : Private {
    my ( $self, $c ) = @_;

    if ( $c->req->params->{edit} ) {

        $c->form( $form_validate_default );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {

            my $type   = $c->form->{valid}->{type};
            my $erm_id = $c->form->{valid}->{erm_id};

            if ( $erm_id eq 'new' ) {
                return $c->redirect( "/erm/create/$type/" );
            }
            else {
                return $c->redirect( "/erm/edit/$type/$erm_id" );
            }
        }
    }


    $c->stash->{main_erms}    = [ $erm_classes{main   }->search( { site => $c->stash->{current_site}->id }, { order_by => 'key' } ) ];
    $c->stash->{license_erms} = [ $erm_classes{license}->search( { site => $c->stash->{current_site}->id }, { order_by => 'key' } ) ];

    $c->stash->{template}     = "erm/main.tt";
}

sub create : Local {
    my ( $self, $c, $type ) = @_;

    my $erm_class = $erm_classes{$type};
    if ( !defined($erm_class) ) {
        die("Unmatched erm class: $type");
    }

    return $c->redirect('/erm/') if $c->req->params->{cancel};
        
    if ( $c->req->params->{save} ) {

        $c->form( $form_validate_new->{$type} );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {

            my $erm;
            eval {
                $erm = $erm_class->create({
                    site => $c->stash->{current_site}->id,
                    key  => $c->form->{valid}->{key},
                });
                
                if ( $type eq 'main' ) {
                    $erm->main_name( $c->form->{valid}->{name} );
                }

            };

            if ($@) {
                my $err = $@;
                CUFTS::DB::DBI->dbi_rollback;
                die($err);
            }

            CUFTS::DB::DBI->dbi_commit;

            return $c->redirect( "/erm/edit/$type/" . $erm->id );

        }

    }

    $c->stash->{type}      = $type;
    $c->stash->{template}  = "erm/create.tt";

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( 'erm-create', $form_validate_new->{$type}, 'erm-create-' ) ];
}

# .. /erm/edit/main/123         (erm_main)
# .. /erm/edit/license/423523   (erm_license)

sub edit : Local {
    my ( $self, $c, $type, $erm_id  ) = @_;

    $c->req->params->{cancel}
        and return $c->redirect('/erm/');

    my $erm_class = $erm_classes{$type};
    if ( !defined($erm_class) ) {
        die("Unmatched erm class: $type");
    }
    
    my $erm = $erm_class->search({
        id   => $erm_id,
        site => $c->stash->{current_site}->id,
    })->first;

    if ( !defined($erm) ) {
        die("Unable to find ERM record '$type': $erm_id for site " . $c->stash->{current_site}->id);
    }
    my %active_content_types = ( map { $_->id, 1 } $erm->content_types() );
    
    if ( $c->req->params->{submit} ) {

        $c->form( $form_validate->{$type} );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {
            eval {
                $erm->update_from_form( $c->form );

                if ( $type eq 'main' ) {
                    $erm->main_name( $c->form->{valid}->{main_name} );

                    # Handle content type changes
                    my $content_types_values = $c->form->{valid}->{'erm-edit-input-content-types'};
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
                        CUFTS::DB::ERMContentTypesMain->search( { erm_main => $erm->id, content_type => $content_type_id } )->delete_all;
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

    my @cost_base_options = CUFTS::DB::ERMCostBases->search( site => $c->stash->{current_site}->id, { order_by => 'cost_base' } );
    if ( scalar(@cost_base_options) ) {
        $c->stash->{cost_base_options} = \@cost_base_options;
    }

    my @consortia_options = CUFTS::DB::ERMConsortia->search( site => $c->stash->{current_site}->id, { order_by => 'consortia' } );
    if ( scalar(@consortia_options) ) {
        $c->stash->{consortia_options} = \@consortia_options;
    }

    my @resource_type_options = CUFTS::DB::ERMResourceTypes->search( site => $c->stash->{current_site}->id, { order_by => 'resource_type' } );
    if ( scalar(@resource_type_options) ) {
        $c->stash->{resource_type_options} = \@resource_type_options;
    }

    my @resource_medium_options = CUFTS::DB::ERMResourceMediums->search( site => $c->stash->{current_site}->id, { order_by => 'resource_medium' } );
    if ( scalar(@resource_medium_options) ) {
        $c->stash->{resource_medium_options} = \@resource_medium_options;
    }

    my @subjects_options = CUFTS::DB::ERMSubjects->search( site => $c->stash->{current_site}->id, { order_by => 'subject' } );
    if ( scalar(@subjects_options) ) {
        $c->stash->{subjects_options} = \@subjects_options;
    }

    my @content_type_options = CUFTS::DB::ERMContentTypes->search( site => $c->stash->{current_site}->id, { order_by => 'content_type' } );
    if ( scalar(@content_type_options) ) {
        $c->stash->{content_type_options} = \@content_type_options;
    }

    $c->stash->{active_content_types} = { map { $_->id, 1 } $erm->content_types() };
    $c->stash->{erm}       = $erm;
    $c->stash->{erm_id}    = $erm_id;
    $c->stash->{type}      = $type;
    $c->stash->{template}  = "erm/edit/${type}/general.tt";

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( "${type}-form", $form_validate->{$type}, 'erm-edit-input-' ) ];
}

1;
