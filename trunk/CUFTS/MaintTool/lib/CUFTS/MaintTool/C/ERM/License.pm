package CUFTS::MaintTool::C::ERM::License;

use strict;
use base 'Catalyst::Base';

use CUFTS::DB::ERMLicense;
use CUFTS::DB::ERMFiles;

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
            ereserves_notes
            allows_coursepacks
            coursepack_notes
            allows_distance_ed
            allows_downloads
            allows_prints
            allows_emails
            emails_notes
            allows_archiving
            archiving_notes
            own_data
            citation_requirements
            requires_print
            requires_print_plus
            additional_requirements
            allowable_downtime
            online_terms
            user_restrictions
            terms_notes
            termination_requirements
            perpetual_access
            perpetual_access_notes
       
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

my $form_validate_new_file = {
    required => [
        qw(
            upload
            file_description
            file
        )
    ],
    optional => [],
    filters => ['trim'],
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

    my @records = CUFTS::DB::ERMLicense->search( site => $c->stash->{current_site}->id, { order_by => 'LOWER(key)' } );
    $c->stash->{records} = \@records;
    $c->stash->{template} = "erm/license/find.tt";

    return 1;
}

# find_json - Gets a list of license keys and ids starting with the passed in key.  This is used for ExtJS
#             combo box lookups, but could be expanded out to cover other uses.

sub find_json : Local {
    my ( $self, $c ) = @_;
    
    my @records;
    my $search = { site => $c->stash->{current_site}->id };

    if ( my $key = $c->req->params->{key} ) {
        $search->{key} = { ilike => "$key\%" };
    }

    @records = CUFTS::DB::ERMLicense->search( $search, { order_by => 'LOWER(key)' } );

    $c->stash->{json}->{rowcount} = scalar(@records);

    # TODO: Move this to the DB module later.
    $c->stash->{json}->{results}  = [ map { { id => $_->id, key => $_->key } } @records ];

    $c->forward('V::JSON');
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
    elsif ( $c->req->params->{upload} ) {
        
        $c->form( $form_validate_new_file );

        unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {
        
            my $upload = $c->req->upload('file');
            if ( $upload->filename !~ /\.([A-Za-z0-9]+)$/ ) {
                die("Could not determine file name extension.  Please upload files with a proper extension such as .jpg, .pdf, etc.");
            };
            my $ext = $1;

            my $file_rec = CUFTS::DB::ERMFiles->create({
                linked_id   => $erm_id,
                link_type   => 'l',
                description => $c->form->{valid}->{file_description},
                ext         => $ext,
            });

            my $filename = $c->path_to( 'root', 'static', 'erm_files', 'l', $file_rec->UUID . '.' . $ext );

            if ( defined($filename) ) {
                $upload->copy_to( $filename ) or
                    die("Error copying file: $!");
            }

            CUFTS::DB::DBI->commit();
            
        }
    }


    $c->stash->{license_files} = [ CUFTS::DB::ERMFiles->search({ linked_id => $erm_id, link_type => 'l' }) ];

    $c->stash->{erm}       = $erm;
    $c->stash->{erm_id}    = $erm_id;
    $c->stash->{template}  = 'erm/license/edit.tt';
    push @{$c->stash->{load_css}}, 'tabs.css';

    $c->stash->{javascript_validate} = [ $c->convert_form_validate( 'license-form', $form_validate, 'erm-edit-input-' ) ];
}

sub delete : Local {
    my ( $self, $c ) = @_;
    
    $c->form({
        required => [ qw( erm_license_id ) ],
        optional => [ qw( confirm cancel delete ) ],
    });

    unless ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {

        if ( $c->form->{valid}->{cancel} ) {
            return $c->forward('/erm/license/edit/' . $c->form->{valid}->{erm_license_id} );
        }
    
        my $erm_license = CUFTS::DB::ERMLicense->search({
            site => $c->stash->{current_site}->id,
            id => $c->form->{valid}->{erm_license_id},
        })->first;

        my @erm_mains = CUFTS::DB::ERMMain->search( { license => $erm_license->id, site => $c->stash->{current_site}->id });

        $c->stash->{erm_mains} = \@erm_mains;
        $c->stash->{erm_license} = $erm_license;

        if ( defined($erm_license) ) {

            if ( $c->form->{valid}->{confirm} ) {

                eval {
                
                    foreach my $erm_main ( @erm_mains ) {
                        $erm_main->license( undef );
                        $erm_main->update();
                    }
                    
                    $erm_license->delete();
                };

                if ($@) {
                    my $err = $@;
                    CUFTS::DB::DBI->dbi_rollback;
                    die($err);
                }
            
                CUFTS::DB::ERMMain->dbi_commit();
                $c->stash->{result} = "ERM License record deleted.";
            }
        }
        else {
            $c->stash->{error} = "Unable to locate ERM record: " . $c->form->{valid}->{erm_license_id};
        }

    }

    $c->stash->{template} = 'erm/license/delete.tt';
}


sub delete_file : Local {
    my ( $self, $c, $erm_id, $file_id  ) = @_;

    my $erm = CUFTS::DB::ERMLicense->search({
        id   => $erm_id,
        site => $c->stash->{current_site}->id,
    })->first;

    if ( !defined($erm) ) {
        die("Unable to find ERMLicense record: $erm_id for site " . $c->stash->{current_site}->id);
    }

    my $file = CUFTS::DB::ERMFiles->search({
        linked_id   => $erm_id,
        id          => $file_id,
        link_type   => 'l'
    })->first;

    if ( !defined($file) ) {
        die("Unable to find ERMFile record: $file_id for site " . $c->stash->{current_site}->id);
    }
    
    my $filename = $c->path_to( 'root', 'static', 'erm_files', 'l', $file->UUID . '.' . $file->ext );
    unlink($filename) or
        die("Error removing file: $!");
    
    $file->delete();
    CUFTS::DB::ERMMain->dbi_commit();
    
    $c->redirect("/erm/license/edit/$erm_id");
}


1;
