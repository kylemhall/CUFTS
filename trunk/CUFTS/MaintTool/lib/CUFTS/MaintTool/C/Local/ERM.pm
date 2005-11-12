package CUFTS::MaintTool::C::Local::ERM;

use strict;
use base 'Catalyst::Base';

my $form_validate = {
	basic => {
		optional => ['submit', 'cancel', 'erm_basic_name', 'erm_basic_vendor', 'erm_basic_publisher', 'erm_basic_subscription_notes'],
		filters => ['trim'],
		missing_optional_valid => 1,
	},
	datescosts => {
		optional => ['submit', 'cancel', 'erm_datescosts_cost', 'erm_datescosts_contract_end', 'erm_datescosts_renewal_notification', 'erm_datescosts_notification_email', 'erm_datescosts_local_fund', 'erm_datescosts_local_acquisitions', 'erm_datescosts_consortia', 'erm_datescosts_consortia_notes', 'erm_datescosts_notes'],
		filters => ['trim'],
		missing_optional_valid => 1,
		constraints => {
			erm_datescosts_contract_end => qr/^\d{4}-\d{1,2}-\d{1,2}/,
		},
	},
	stats => {
		optional => ['submit', 'cancel', 'erm_statistics_notes'],
		filters => ['trim'],
		missing_optional_valid => 1,
	},
	admin => {
		optional => ['submit', 'cancel', 'erm_admin_notes'],
		filters => ['trim'],
		missing_optional_valid => 1,
	},
	terms => {
		optional => ['submit', 'cancel', 'erm_terms_simultaneous_users', 'erm_terms_allows_ill', 'erm_terms_ill_notes', 'erm_terms_allows_ereserves', 'erm_terms_ereserves_notes', 'erm_terms_allows_coursepacks', 'erm_terms_coursepacks_notes', 'erm_terms_notes'],	
		filters => ['trim'],
		missing_optional_valid => 1,
	},		
	contacts => {
		optional => ['submit', 'cancel', 'erm_contacts_notes'],
		filters => ['trim'],
		missing_optional_valid => 1,
	},		
	misc => {
		optional => ['submit', 'cancel', 'erm_misc_notes'],
		filters => ['trim'],
		missing_optional_valid => 1,
	},		
		
};	


sub manage : Regex('^local/erm/(edit|view)/(\w+)$') {
	my ($self, $c, $resource_id) = @_;

	$c->req->params->{cancel} and
		return $c->redirect('/local/menu');

	my $action = shift @{$c->req->snippets};
	my $section = $c->stash->{section} = shift @{$c->req->snippets};
	$c->stash->{template} = "local/erm/${action}/${section}.tt";

	my $local_resource = $c->stash->{local_resource};
	my $global_resource = $c->stash->{global_resource};

	if ($c->req->params->{submit}) {
		$c->form($form_validate->{$section});

		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {
			eval {
				defined($local_resource) or
					$local_resource = $c->stash->{local_resource} = CUFTS::DB::LocalResources->create({resource => $global_resource->id, site => $c->stash->{current_site}->id});
					
				$local_resource->update_from_form($c->form);
			};
			if ($@) {
				my $err = $@;
				CUFTS::DB::DBI->dbi_rollback;
				die($err);
			}

			CUFTS::DB::DBI->dbi_commit;
			push @{$c->stash->{results}}, 'ERM data updated.';
		}
	}
}


1;