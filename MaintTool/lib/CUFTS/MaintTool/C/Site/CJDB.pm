package CUFTS::MaintTool::C::Site::CJDB;

use strict;
use base 'Catalyst::Base';

my @valid_states = ('active', 'sandbox');
my @valid_types = ('css', 'cjdb_template');

my $form_settings_validate = {
	optional => [qw{
	    submit
	    cancel

	    cjdb_print_name
	    cjdb_print_link_label

	    cjdb_authentication_module
	    cjdb_authentication_server
	    cjdb_authentication_string1
	    cjdb_authentication_string2
	    cjdb_authentication_string3
	    cjdb_authentication_level100
	    cjdb_authentication_level50
	}],
	required => [qw{
	    cjdb_unified_journal_list
	    cjdb_show_citations
	    cjdb_display_db_name_only
	}],
	filters  => ['trim'],
	missing_optional_valid => 1,
};

my $form_data_validate = {
	optional => ['submit', 'cancel', 'delete', 'rebuild', 'test', 'delete_lccn', 'rebuild_ejournals_only', 'upload_data', 'cjdb_data_upload', 'upload_label', 'lccn_data_upload', 'upload_lccn'],
	dependency_groups => {
		'data_upload' => ['upload_data', 'cjdb_data_upload'],
		'lccn_upload' => ['lccn_data_upload', 'upload_lccn'],
	},
	constraints => {
		'delete' => qr/^[^\|:;'"\\\/]+$/,
		'test' => qr/^[^\|:;'"\\\/]+$/,
		'rebuild' => qr/^[^\|:;'"\\\/]+$/,
	},		
	filters  => ['trim'],
};

sub settings : Local {
	my ($self, $c) = @_;

	$c->req->params->{cancel} and
		return $c->redirect('/site/edit');

	if ($c->req->params->{submit}) {
		$c->form($form_settings_validate);

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
		
			eval {
				$c->stash->{current_site}->update_from_form($c->form);
			};
			if ($@) {
				my $err = $@;
				CUFTS::DB::DBI->dbi_rollback;
				die($err);
			}
			
			CUFTS::DB::DBI->dbi_commit;
			push @{$c->stash->{results}}, 'Site data updated.';
		}
	}

	$c->stash->{section} = 'cjdb_settings';
	$c->stash->{template} = 'site/cjdb/settings.tt';
}

sub data : Local {
	my ($self, $c) = @_;
	
	$c->req->params->{cancel} and
		return $c->redirect('/site/edit');

	my $upload_dir = $CUFTS::Config::CJDB_SITE_DATA_DIR . '/' . $c->stash->{current_site}->id;

	if ($c->req->params->{submit}) {
		$c->form($form_data_validate);

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
			my (%delete, %rebuild, %test);
			$c->form->valid->{delete} and
				%delete = map {$_,1} ref($c->form->valid->{delete}) ? @{$c->form->valid->{delete}} : ($c->form->valid->{delete});
			$c->form->valid->{rebuild} and
				%rebuild = map {($_,1)} ref($c->form->valid->{rebuild}) ? @{$c->form->valid->{rebuild}} : ($c->form->valid->{rebuild});
			$c->form->valid->{test} and
				%test = map {($_,1)} ref($c->form->valid->{test}) ? @{$c->form->valid->{test}} : ($c->form->valid->{test});

			# Remove items to be deleted from rebuild/test lists
			
			foreach my $key (keys %delete) {
				delete $rebuild{$key};
				delete $test{$key};
			}

			$c->form->valid->{delete_lccn} and
				$delete{lccn_subjects} = 1;

			my @delete = keys(%delete);
			my @rebuild = keys(%rebuild);
			my @test = keys(%test);
				
			foreach my $file (@delete) {
				-e "$upload_dir/$file" and
					unlink "$upload_dir/$file" or
						die("Unable to unlink file '$file': $!");
			}
			
			scalar(@delete) and
				push @{$c->stash->{results}}, ('Files deleted: ' . (join ', ', @delete));

			if (scalar(@rebuild)) {
				$c->stash->{current_site}->rebuild_cjdb(join '|', @rebuild);
				push @{$c->stash->{results}}, ('CJDB will be rebuilt using files: ' . (join ', ', @rebuild));
			} elsif ($c->form->valid->{rebuild_ejournals_only}) {
				$c->stash->{current_site}->rebuild_ejournals_only(1);
				push @{$c->stash->{results}}, 'CJDB will be rebuilt from CUFTS electronic journal data only.';
			} else {
				$c->stash->{current_site}->rebuild_cjdb(undef);
				$c->stash->{current_site}->rebuild_ejournals_only(undef);
				push @{$c->stash->{results}}, 'CJDB will not be rebuilt.';
			}

			if (scalar(@test)) {
				$c->stash->{current_site}->test_MARC_file(join '|', @test);
				push @{$c->stash->{results}}, ('Files to have MARC data tested: ' . (join ', ', @test));
			} else {
				$c->stash->{current_site}->test_MARC_file(undef);
				push @{$c->stash->{results}}, 'No files marked for MARC testing.';
			}
			
			eval {$c->stash->{current_site}->update};
			if ($@) {
				my $err = $@;
				CUFTS::DB::DBI->dbi_rollback;
				die($err);
			}

			CUFTS::DB::DBI->dbi_commit;
		}	
	} elsif ($c->req->params->{upload_data}) {
		$c->form($form_data_validate);

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
			my $filename = $c->form->valid->{upload_label}; 
			unless ($filename) {
				my ($sec, $min, $hour, $mday, $mon, $year, $wday) = localtime(time);
				$mon += 1;
				$year += 1900;
				$filename = sprintf("%04i%02i%02i_%02i-%02i-%02i", $year, $mon, $mday, $hour, $min, $sec);
			}

			-d $upload_dir or
				mkdir $upload_dir or
					die("Unable to create site upload dir '$upload_dir': $!");
	
			-e "$upload_dir/$filename" and
				die("File already exists with label: $filename");

			$c->request->upload('cjdb_data_upload')->copy_to("$upload_dir/$filename") or 
				die("Unable to copy uploaded file to:  ($upload_dir/$filename): $!");

			$c->stash->{current_site}->rebuild_ejournals_only(undef);
			eval {$c->stash->{current_site}->update};
			if ($@) {
				my $err = $@;
				CUFTS::DB::DBI->dbi_rollback;
				die($err);
			}
			
			push @{$c->stash->{results}}, 'Uploaded data file.';
		}			
	} elsif ($c->req->params->{upload_lccn}) {
		$c->form($form_data_validate);

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
			my $filename = 'lccn_subjects';

			-d $upload_dir or
				mkdir $upload_dir or
					die("Unable to create site upload dir '$upload_dir': $!");
	
			if (-e "$upload_dir/$filename") {
				unlink "$upload_dir/$filename" or
					die("Unable to delete existing file: $!");
			}

			$c->request->upload('lccn_data_upload')->copy_to("$upload_dir/$filename") or 
				die("Unable to copy uploaded file to:  ($upload_dir/$filename): $!");

			push @{$c->stash->{results}}, 'Uploaded LCCN data file.';
		}			
	}		
	
	if (-d $upload_dir && opendir FILES, $upload_dir) {
		my @file_list = grep !/^lccn_subjects$/, grep !/^\./, readdir FILES;
		$c->stash->{print_files} = \@file_list;

		if (-e "$upload_dir/lccn_subjects") {
			my $mtime = (stat "$upload_dir/lccn_subjects")[9];
			my ($sec, $min, $hour, $mday, $mon, $year) = localtime($mtime);
			$year += 1900;
			$mon++;
			$c->stash->{call_number_file} = sprintf("%04i-%02i-%02i %02i:%02i:%02i", $year, $mon, $mday, $hour, $min, $sec);
		}
	}
	
	$c->stash->{section} = 'cjdb_data';
	$c->stash->{template} = 'site/cjdb/data.tt';
}	



=head1 NAME

CUFTS::MaintTool::C::Site::CJDB - Component for CJDB related data

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

