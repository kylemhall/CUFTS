package CUFTS::MaintTool::C::ERM::License;

use strict;
use base 'Catalyst::Base';

use CUFTS::DB::ERMLicense;

my $form_validate = {
    required => [
        qw(
            key
        )
    ],
    optional => [
        qw(
            submit 
            cancel

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
};

my $form_validate_new = {
    required => [ qw( key ) ],
    optional => [ qw( save cancel ) ],
    filters  => ['trim'],
    missing_optional_valid => 1,
};

sub default : Private {
    my ( $self, $c ) = @_;

    if ( $c->req->params->{submit} ) {
        my $id = $c->req->params->{license};
        
        if ( $id eq 'new' ) {
            $c->redirect('/erm/license/create');
        }
        else {
            $c->redirect("/erm/license/edit/$id");
        }
    }

    my @records = CUFTS::DB::ERMLicense->search( site => $c->stash->{current_site}->id );
    $c->stash->{records} = \@records;
    $c->stash->{template} = "erm/license/find.tt";

    return 1;
}


sub create : Local {
    my ( $self, $c ) = @_;

    return $c->redirect('/erm/license/') if $c->req->params->{cancel};

    if ( $c->req->params->{save} ) {

        $c->form( $form_validate_new );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {

            my $erm;
            eval {
                $erm = CUFTS::DB::ERMLicense->create({
                    site => $c->stash->{current_site}->id,
                    key  => $c->form->{valid}->{key},
                });
            };

            if ($@) {
                my $err = $@;
                CUFTS::DB::DBI->dbi_rollback;
                die($err);
            }

            CUFTS::DB::DBI->dbi_commit;

            return $c->redirect( "/erm/license/edit/" . $erm->id );

        }

    }

    $c->stash->{template}  = "erm/license/create.tt";

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( 'erm-create', $form_validate_new, 'erm-create-' ) ];
}

# .. /erm/edit/main/123         (erm_main)
# .. /erm/edit/license/423523   (erm_license)

sub edit : Local {
    my ( $self, $c, $erm_id  ) = @_;

    $c->req->params->{cancel}
        and return $c->redirect('/erm/license/');


    my $erm = CUFTS::DB::ERMLicense->search({
        id   => $erm_id,
        site => $c->stash->{current_site}->id,
    })->first;

    if ( !defined($erm) ) {
        die("Unable to find ERMLicense record: $erm_id for site " . $c->stash->{current_site}->id);
    }
    
    if ( $c->req->params->{submit} ) {

        $c->form( $form_validate );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {

            eval {
                $erm->update_from_form( $c->form );
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

    $c->stash->{erm}       = $erm;
    $c->stash->{erm_id}    = $erm_id;
    $c->stash->{template}  = 'erm/license/edit.tt';
    push @{$c->stash->{load_css}}, 'tabs.css';

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( 'license-form', $form_validate, 'erm-edit-input-' ) ];
}

1;
