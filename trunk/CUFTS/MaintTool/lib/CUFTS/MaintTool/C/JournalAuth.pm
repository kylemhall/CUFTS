package CUFTS::MaintTool::C::JournalAuth;

use strict;
use base 'Catalyst::Base';
use MARC::Record;

my $marc_fields = {
	'022' => { 
	           subfields => [ qw(a) ],
	           size      => [ 8 ],
	           repeats   => 1,
	         },
	'050' => { 
	           subfields => [ qw(a) ],
	           size      => [ 10 ],
	           repeats   => 1,
	         },
	'110' => {
	           subfields => [ qw(a b c) ],
	           size      => [ 40, 40 , 10 ],
	           repeats   => 0,
	         },
	'245' => {
	           indicators => [ 2 ],
	           subfields  => [ qw(a b c n p) ],
	           size       => [ 40, 40, 10, 10, 10 ],
	           repeats    => 0,
	         },
	'246' => {
	           subfields => [ qw(a b n p) ],
	           size      => [ 40, 40, 10, 10 ],
	           repeats   => 1,
	         },
	'260' => {
	           subfields => [ qw(a b) ],
	           size      => [ 40, 40 ],
	           repeats   => 1,
	         },
	'650' => {
	           subfields => [ qw(a b v x y z) ],
	           size      => [ 40, 40, 10, 10, 10, 10 ],
	           repeats   => 1,
	         },
	'710' => {
	           subfields => [ qw(a b c) ],
	           size      => [ 40, 40, 10 ],
	           repeats   => 1,
	         },
	'780' => {
	           subfields => [ qw(a s t x) ],
	           size      => [ 40, 10, 40, 10 ],
	           repeats   => 1,
	         },
	'785' => {
	           subfields => [ qw(a s t x) ],
	           size      => [ 40, 10, 40, 10 ],
	           repeats   => 1,
	         },
};

my $form_validate_search = {
	optional => [
		'string', 'field', 'search', 'cancel',
	],
	filters => ['trim'],
	missing_optional_valid => 1,
};

my $form_validate_marc = {
	optional => [
		'save', 'cancel',
	],
	optional_regexp => qr/^\d+-\d{3}/,
	filters => ['trim'],
};


sub auto : Private {
	my ($self, $c, $resource_id) = @_;

	$c->stash->{current_account}->{edit_global} || $c->stash->{current_account}->{administrator} or
		die('User not authorized for journal auth maintenance');

	$c->stash->{header_image} = 'global_resources.jpg';

	return 1;
}

sub search : Local {
	my ($self, $c) = @_;

	if ($c->req->params->{search}) {
		$c->form($form_validate_search);

		if ($c->form->valid->{string}) {
			my @records;
			if ($c->form->valid->{field} eq 'title') {
				@records = CUFTS::DB::JournalsAuth->search_by_title($c->form->valid->{string});
			} elsif ($c->form->valid->{field} eq 'official_title') {
				@records = CUFTS::DB::JournalsAuth->search_like('title' => $c->form->valid->{string});
			} elsif ($c->form->valid->{field} eq 'issn') {
				@records = CUFTS::DB::JournalsAuth->search_by_issn($c->form->valid->{string});
			} elsif ($c->form->valid->{field} eq 'id') {
				@records = (CUFTS::DB::JournalsAuth->retrieve($c->form->valid->{string}));
			}
			$c->stash->{journal_auths} = \@records;

			# Stash search field/string for display on search box and into the session for 

			$c->session->{journal_auth_search_field} = $c->stash->{field} = $c->form->valid->{field};
			$c->session->{journal_auth_search_string} = $c->stash->{string} = $c->form->valid->{string};
		}
	} elsif ($c->req->params->{cancel}) {
		$c->redirect('/main');
	}

	$c->stash->{template} = 'journalauth/search.tt';
}

sub edit_marc : Local {
	my ($self, $c, $journal_auth_id) = @_;

	my $journal_auth = CUFTS::DB::JournalsAuth->retrieve($journal_auth_id);

	if ($c->req->params->{cancel}) {
		$c->req->params({
			'field'  => $c->session->{journal_auth_search_field},
			'string' => $c->session->{journal_auth_search_string},
			'search' => 'search',
		});
		return $c->forward('/journalauth/search');
	}
	if ($c->req->params->{save}) {

		$c->form($form_validate_marc);
		unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {		
			
			my @fields;
			foreach my $field_type (sort keys %$marc_fields) {
				my $row = 0;

				while ($c->form->valid->{"${row}-${field_type}-exists"}) {
					my $subfields = {};
					my $indicators = [];
					
					foreach my $subfield (@{$marc_fields->{$field_type}->{subfields}}) {
						my $value = $c->form->valid->{"${row}-${field_type}${subfield}"};
						next unless defined($value) && $value ne '';
						$subfields->{$subfield} = $value;
					}
					$indicators->[0] = $c->form->valid->{"${row}-${field_type}-1"};
					$indicators->[1] = $c->form->valid->{"${row}-${field_type}-2"};
					$row++;
					
					next unless scalar(keys %$subfields);  # Don't save blank fields, they're to be "deleted"

					my $field;
					eval { $field = MARC::Field->new($field_type, @$indicators, %$subfields); };
					if ($@) {
						warn($@);
						push @{$c->stash->{errors}}, $@;
					} else {
						push @fields, $field;
					}
				}
			}

			if (!defined($c->stash->{errors})) {
				my $record;
				eval {
					$record = new MARC::Record();
					$record->append_fields(@fields);
				};
				if ($@) {
					push @{$c->stash->{errors}}, "Error creating MARC record: $@";
				} else {
					$journal_auth->marc($record->as_usmarc());
					$journal_auth->update();
					CUFTS::DB::JournalsAuth->dbi_commit();
					$c->req->params({
						'field'  => $c->session->{journal_auth_search_field},
						'string' => $c->session->{journal_auth_search_string},
						'search' => 'search',
					});
					return $c->forward('/journalauth/search');
					
				}
			}

		}
		
	}
	
	$c->stash->{marc_fields} = $marc_fields;
	$c->stash->{load_javascript} = 'journal_auth.js';
	$c->stash->{journal_auth} = $journal_auth;
	$c->stash->{template} = 'journalauth/edit_marc.tt';
}	

1;