package CUFTS::MaintTool::C::Local;

use strict;
use base 'Catalyst::Base';

use CUFTS::Util::Simple;

my $form_validate_local = {
    required => ['name', 'provider', 'module', 'resource_type'],
    optional => [
        'provider', 'proxy', 'dedupe', 'rank', 'active', 'resource_services', 'submit', 'cancel',
        'resource_identifier', 'database_url', 'auth_name', 'auth_passwd', 'url_base', 'notes_for_local', 'cjdb_note', 'proxy_suffix'
    ],
    defaults => {
        'active' => 'false',
        'proxy' => 'false',
        'dedupe' => 'false',
        'auto_activate' => 'false',
        'resource_services' => []
    },
    filters => ['trim'],
    missing_optional_valid => 1,
};

my $form_validate_global = {
    optional => [
        'proxy', 'dedupe', 'auto_activate', 'rank', 'active', 'resource_services', 'submit', 'cancel',
        'resource_identifier', 'database_url', 'auth_name', 'auth_passwd', 'url_base', 'cjdb_note', 'proxy_suffix'
    ],
    defaults => {
        'active' => 'false',
        'proxy' => 'false',
        'dedupe' => 'false',
        'auto_activate' => 'false',
        'resource_services' => []
    },
    filters => ['trim'],
    missing_optional_valid => 1,
};

my $form_validate_menu = {
    optional => ['show', 'filter', 'apply_filter', 'sort'],
    filters => ['trim'],
};

my $form_validate_titles = {
    optional => ['page', 'filter', 'display_per_page', 'apply_filter'],
    filters => ['trim'],
    defaults => { 'filter' => '', 'page' => 1 },
};  

my $form_validate_bulk = {
    required => ['file', 'upload'],
};

sub auto : Private {
    my ($self, $c, $resource_id) = @_;

    if (defined($resource_id) && $resource_id =~ /^([gl])(\d+)$/) {
        my ($type, $id) = ($1, $2);
        
        if ($type eq 'l') {
            $c->stash->{local_resource} = CUFTS::DB::LocalResources->retrieve($id);
            $c->stash->{global_resource} = $c->stash->{local_resource}->resource;
        } else {
            $c->stash->{global_resource} = CUFTS::DB::Resources->retrieve($id);
            $c->stash->{local_resource} = CUFTS::DB::LocalResources->search({site => $c->stash->{current_site}->id, resource => $id})->first;
        }
    }

    $c->stash->{header_section} = 'Local Resources';

    return 1;
}

sub menu : Local {
    my ($self, $c) = @_;

    $c->form($form_validate_menu);

    $c->form->valid->{show} and
        $c->session->{local_menu_show} = $c->form->valid->{show};

    # Default to "show active"

    my $active = !defined($c->session->{local_menu_show}) || $c->session->{local_menu_show} eq 'show active' ? 1 : 0;

    $c->form->valid->{apply_filter} and
        $c->session->{local_menu_filter} = $c->form->valid->{filter};

    $c->form->valid->{sort} and
        $c->session->{local_menu_sort} = $c->form->valid->{sort};

    my %search;
    if ($c->session->{local_menu_filter}) {

        # Get filter and escape SQL LIKE special characters

        my $filter = $c->session->{local_menu_filter};
        $filter =~ s/([%_])/\\$1/g;
        $filter =~ s#\\#\\\\\\\\#;
            
        $search{-nest} =
            [
             name => {ilike => "\%$filter\%"},
             provider => {ilike => "\%$filter\%"},
            ];
    }

    my @global_resources = CUFTS::DB::Resources->search_where({ %search, active => 'true' });

    $active and
        $search{active} = 'true';

    my @local_resources = $c->session->{local_menu_filter} 
                          ? CUFTS::DB::LocalResources->search_where({ -nest => [\%search, {resource => { '!=' => undef }}], site => $c->{stash}->{current_site}->id })
                          : CUFTS::DB::LocalResources->search_where({ %search, site => $c->{stash}->{current_site}->id });

    # Merge resources into a resource that we can treat like a real CDBI resource except for DB interaction.

    my $resources = CUFTS::MaintTool::M::MergeResources->merge(\@local_resources, \@global_resources, $active);
                                                     
    # Delete the title list filter, it should be clear when we go to browse a new list
    
    delete $c->session->{local_titles_filter};

    # Sort resources before displaying.  Set is too small to bother with Schwartzian Transform
    # Sort reverse numeric by rank (only numeric field so far), by any other field with name being the second
    # sort column, or just by name as default.
    
    my $sort = $c->session->{local_menu_sort} || 'name';
    if ($sort eq 'rank') {
        @$resources = sort { (int($b->$sort || 0) <=> int($a->$sort || 0)) or lc($a->name) cmp lc($b->name) } @$resources;
    } elsif ($sort ne 'name') {
        @$resources = sort { lc($a->$sort) cmp lc($b->$sort) or lc($a->name) cmp lc($b->name) } @$resources;
    } else {
        @$resources = sort { lc($a->$sort) cmp lc($b->$sort) } @$resources;
    }
        
    $c->stash->{filter} = $c->session->{local_menu_filter};
    $c->stash->{sort} = $sort;
    $c->stash->{show} = $c->session->{local_menu_show} || 'show active';
    $c->stash->{resources} = $resources;
    $c->stash->{template} = 'local/menu.tt';
}


sub view : Local {
    my ($self, $c, $resource_id) = @_;

    if (defined($c->stash->{global_resource})) {
        $c->stash->{template} = 'local/view_global.tt';
    } elsif (defined($c->stash->{local_resource})) {
        $c->stash->{template} = 'local/view_local.tt';
    } else {
        return die('No resource loaded to view');
    }
}   


sub edit : Local {
    my ($self, $c, $resource_id) = @_;

    $c->req->params->{cancel} and
        return $c->redirect('/local/menu');

    my $global_resource = $c->stash->{global_resource};
    my $local_resource  = $c->stash->{local_resource};

    if ( !defined($local_resource) ) {
        my $new_record = { site => $c->stash->{current_site}->id };

        if ( defined($global_resource) ) {
            $new_record->{resource} = $global_resource->id;
        }
        else {
            $new_record->{module} = 'blank';
        }

        eval {
            $local_resource = CUFTS::DB::LocalResources->create($new_record);
            $c->stash->{local_resource} = $local_resource;
        };
            
        if ($@) {
            my $err = $@;
            CUFTS::DB::DBI->dbi_rollback;
            die($err);
        }
            
        CUFTS::DB::DBI->dbi_commit;
    }

    $c->form->valid->{site} = $c->stash->{current_site}->id;

    if ($c->req->params->{submit}) {

        $c->form(defined($global_resource) ? $form_validate_global : $form_validate_local);
        
        unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
        
            # Remove services and recreate links, then update and save the resource
            
            eval {
                $local_resource->update_from_form($c->form);
                CUFTS::DB::LocalResources_Services->search({local_resource => $local_resource->id})->delete_all;
                
                foreach my $service ($c->form->valid('resource_services')) {
                    $local_resource->add_to_services({ service => $service });
                }
                
                if ($local_resource->auto_activate) {
                    $local_resource->activate_titles();
                }
                
            };
            
            if ($@) {
                my $err = $@;
                CUFTS::DB::DBI->dbi_rollback;
                die($err);
            }
            
            CUFTS::DB::DBI->dbi_commit;
            
            return $c->redirect('/local/menu');
        }
    }

    # Get ERM Main record if one is linked
    
    my $erm_main_link = CUFTS::DB::ERMMainLink->search( { link_type => 'r', link_id => $local_resource->id } )->first;
    if ( defined($erm_main_link) ) {
        $c->stash->{erm_main} = CUFTS::DB::ERMMain->retrieve( $erm_main_link->erm_main );
    }

    # Get all the ERM mains for a select box - switch this to use the search system later
    
    my $erm_mains = CUFTS::DB::ERMMain->retrieve_all_for_site( $c->stash->{current_site}->id, 1 );    # 1 - fast, no objects
    $c->stash->{erm_mains} = $erm_mains;

    # Fill out the rest of the stash

    $c->stash->{section} = 'general';
    $c->stash->{module_list} = [CUFTS::ResourcesLoader->list_modules()];

    if (defined($global_resource)) {
        $c->stash->{services} = [$global_resource->services];
        $c->stash->{template} = 'local/edit_global.tt';
    } else {
        $c->stash->{resource_types} = [CUFTS::DB::ResourceTypes->retrieve_all()];
        $c->stash->{services} = [CUFTS::DB::Services->retrieve_all()];
        $c->stash->{template} = 'local/edit_local.tt';
    }
}

    
sub delete : Local {
    my ($self, $c, $resource_id) = @_;
    
    defined($c->stash->{local_resource}) or
         die('No resource loaded to delete.');
        
    $c->stash->{local_resource}->delete();
    CUFTS::DB::DBI->dbi_commit;
    
    $c->redirect('/local/menu');
}


1;