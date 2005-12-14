package CUFTS::MaintTool::C::Site::Template;

use strict;
use base 'Catalyst::Base';

my @valid_states = ( 'active', 'sandbox' );
my @valid_types  = ( 'css',    'cjdb_template' );

my $form_validate = {
    optional => [ 'submit', 'cancel', 'template_contents' ],
    filters  => ['trim'],
};

sub auto : Private {
    my ( $self, $c ) = @_;
    $c->stash->{section} = 'templates';
}

sub menu : Local {
    my ( $self, $c ) = @_;

    my $site_id = $c->stash->{current_site}->id;

    ##
    ## Get CJDB template files, active, and sandbox lists
    ##

    my @cjdb_template_list = qw(
        account_create.tt
        account_manage.tt
        azmenu.tt
        browse.tt
        browse_associations.tt
        browse_journals.tt
        browse_journals_unified_data.tt
        browse_search_description.tt
        browse_subjects.tt
        errors.tt
        journal.tt
        journal_associations.tt
        journal_availability.tt
        journal_issns.tt
        journal_mytags.tt
        journal_relations.tt
        journal_subjects.tt
        journal_tags.tt
        journal_titles.tt
        layout.tt
        lcc_browse.tt
        lcc_browse_content.tt
        loggedin.tt
        login.tt
        manage_tags_info.tt
        menu.tt
        mytags.tt
        nav_line.tt
        page_footer.tt
        page_header.tt
        page_title.tt
        paging.tt
        selected_journals.tt
        selected_journals_data.tt
        setup_browse.tt
        setup_browse_javascript.tt
        tag_viewing_string.tt
    );

    my $site_dir    = get_site_base_dir('cjdb_template') . '/' . $site_id;
    my $active_dir  = $site_dir . '/active';
    my $sandbox_dir = $site_dir . '/sandbox';

    -d $site_dir
        or mkdir $site_dir
            or die('Unable to access CJDB site base template directory.');

    -d $active_dir
        or mkdir $active_dir
            or die('Unable to access CJDB site active template directory.');

    -d $sandbox_dir
        or mkdir $sandbox_dir
            or die('Unable to access CJDB site sandbox template directory.');

    opendir ACTIVE, $active_dir
        or die('Unable to open CJDB site active template directory for reading');
    my @active_cjdb_templates = grep !/^\./, readdir ACTIVE;
    closedir ACTIVE;

    opendir SANDBOX, $sandbox_dir
        or die('Unable to open CJDB site sandbox template directory for reading');
    my @sandbox_cjdb_templates = grep !/^\./, readdir SANDBOX;
    closedir SANDBOX;

    ##
    ## Get CSS files, active and sandbox lists
    ##

    my @css_list        = qw( cjdb.css );
    my $css_dir         = get_site_base_dir('css') . '/' . $site_id;
    my $active_css_dir  = $css_dir . '/active';
    my $sandbox_css_dir = $css_dir . '/sandbox';

    -d $css_dir
        or mkdir $css_dir
            or die(qq{Unable to access CJDB site base CSS directory "$css_dir": $!});

    -d $active_css_dir
        or mkdir $active_css_dir
            or die('Unable to access CJDB site active CSS directory.');

    -d $sandbox_css_dir
        or mkdir $sandbox_css_dir
            or die('Unable to access CJDB site sandbox CSS directory.');

    opendir ACTIVE, $active_css_dir
        or die('Unable to open CJDB site active CSS directory for reading');
    my @active_css = grep !/^\./, readdir ACTIVE;
    closedir ACTIVE;

    opendir SANDBOX, $sandbox_css_dir
        or die('Unable to open CJDB site sandbox CSS directory for reading');
    my @sandbox_css = grep !/^\./, readdir SANDBOX;
    closedir SANDBOX;

    # TODO: Get URL for CJDB for link to sandbox/active?

    $c->stash->{active_cjdb_templates}  = \@active_cjdb_templates;
    $c->stash->{sandbox_cjdb_templates} = \@sandbox_cjdb_templates;
    $c->stash->{cjdb_templates}         = \@cjdb_template_list;

    $c->stash->{csses}         = \@css_list;
    $c->stash->{active_csses} = \@active_css;
    $c->stash->{sandbox_csses} = \@sandbox_css;

    $c->stash->{template} = 'site/template/menu.tt';
}

sub view : Local {
    my ( $self, $c, $type, $template_name, $state ) = @_;
    $c->stash->{template}      = 'site/template/view.tt';
    $c->stash->{type}          = $type;
    $c->stash->{state}         = $state;
    $c->stash->{template_name} = $template_name;
    $c->forward("/site/template/handle");
}

sub edit : Local {
    my ( $self, $c, $type, $template_name ) = @_;
    $c->stash->{template}      = 'site/template/edit.tt';
    $c->stash->{type}          = $type;
    $c->stash->{state}         = 'sandbox';
    $c->stash->{template_name} = $template_name;
    $c->forward("/site/template/handle");
}

sub handle : Private {
    my ( $self, $c ) = @_;

    my $site_id = $c->stash->{current_site}->id;

    my $state         = $c->stash->{state};
    my $type          = $c->stash->{type};
    my $template_name = $c->stash->{template_name};

    grep { $state eq $_ } @valid_states
        or die("Invalid template state: $state");

    grep { $type eq $_ } @valid_types
        or die("Invalid template type: $type");

    $template_name =~ /[\/\\;:'"]/
        and die("Bad characters in template name: $template_name");

    my $base_dir      = get_base_dir($type);
    my $base_site_dir = get_site_base_dir($type);

    my $site_dir = $base_site_dir . '/' . $site_id . '/sandbox';

    -d $site_dir
        or mkdir $site_dir
        or CUFTS::Exception::App::CGI->throw(
        'Unable to access CJDB site base template directory.');

    my $template_contents;
    my $template_file =
        -e "${site_dir}/${template_name}"
        ? "${site_dir}/${template_name}"
        : "${base_dir}/${template_name}";

    open TEMPLATE, "${template_file}"
        or CUFTS::Exception::App::CGI->throw(qq{Unable to open template file "${template_file}": $!});
    while (<TEMPLATE>) {
        $template_contents .= $_;
    }
    close TEMPLATE;

    $c->stash->{template_name}     = $template_name;
    $c->stash->{type}              = $type;
    $c->stash->{template_contents} = $template_contents;
    $c->stash->{state}             = $state;
}

sub save : Local {
    my ( $self, $c, $type, $template_name ) = @_;

    if ( $c->req->param('cancel') ) {
        $c->redirect('/site/template/menu');
    }

    $c->form($form_validate);

    grep { $type eq $_ } @valid_types
        or die("Invalid template type: $type");

    $template_name =~ /[\/\\;:'"]/
        and die("Bad characters in template name: $template_name");

    if (   $c->form->has_missing
        || $c->form->has_invalid
        || $c->form->has_unknown )
    {
        die('Error with edit form');
    }

    my $site_dir = get_site_base_dir($type) . '/'
        . $c->stash->{current_site}
        . '/sandbox';

    -d $site_dir
        or mkdir $site_dir
            or die('Unable to access template directory.');

    open TEMPLATE, ">${site_dir}/${template_name}"
        or die("Unable to open template file: $!");
    print TEMPLATE $c->form->valid->{template_contents};
    close TEMPLATE;

    $c->stash->{results} = 'File saved.';
    $c->forward('/site/template/menu');
}

sub delete : Local {
    my ( $self, $c, $type, $template_name, $state ) = @_;

    grep { $state eq $_ } @valid_states
        or die("Invalid template state: $state");

    grep { $type eq $_ } @valid_types
        or die("Invalid template type: $type");

    $template_name =~ /[\/\\;:'"]/
        and die("Bad characters in template name: $template_name");

    my $site_dir = get_site_base_dir($type) . '/'
        . $c->stash->{current_site} . '/'
        . $state;

    -d $site_dir
        or mkdir $site_dir
        or die('Unable to access CJDB site base template directory.');

    -e "${site_dir}/${template_name}"
        and unlink "${site_dir}/${template_name}"
        or die(
        "Unable to unlink template file '${site_dir}/${template_name}': $!");

    $c->redirect('/site/template/menu');
}

sub transfer : Local {
    my ( $self, $c, $type, $template_name ) = @_;

    $template_name =~ /[\/\\;:'"]/
        and die("Bad characters in template name: $template_name");

    grep { $type eq $_ } @valid_types
        or die("Invalid template type: $type");

    my $site_dir = get_site_base_dir($type) . '/'
        . $c->stash->{current_site}->id . '/';
    my $sandbox_dir = $site_dir . 'sandbox';
    my $active_dir  = $site_dir . 'active';

    -d $site_dir
        or mkdir $site_dir
            or die('Unable to access site base template directory.');

    -d $active_dir
        or mkdir $active_dir
            or die('Unable to access site active template directory.');

    -d $sandbox_dir
        or mkdir $sandbox_dir
            or die('Unable to access site sandbox template directory.');

    -e "${sandbox_dir}/${template_name}"
        or die("Unable to find template file to copy");

    # Backup any existing active template
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
    $mon++;
    $year += 1900;
    my $timestamp = "${year}-${mon}-${mday}_${hour}:${min}:${sec}";
    -e "${active_dir}/${template_name}"
        and `mv ${active_dir}/${template_name} ${active_dir}/${template_name}.$timestamp`;

    `cp ${sandbox_dir}/${template_name} ${active_dir}/${template_name}`;

    $c->redirect('/site/template/menu');
}

sub get_base_dir {
    my ($type) = @_;

    if ( $type eq 'css' ) {
        return $CUFTS::Config::CJDB_CSS_DIR;
    }
    elsif ( $type eq 'cjdb_template' ) {
        return $CUFTS::Config::CJDB_TEMPLATE_DIR;
    }
}

sub get_site_base_dir {
    my ($type) = @_;

    if ( $type eq 'css' ) {
        return $CUFTS::Config::CJDB_SITE_CSS_DIR;
    }
    elsif ( $type eq 'cjdb_template' ) {
        return $CUFTS::Config::CJDB_SITE_TEMPLATE_DIR;
    }
}

=head1 NAME

CUFTS::MaintTool::C::Site::Template - Component for site templates

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

