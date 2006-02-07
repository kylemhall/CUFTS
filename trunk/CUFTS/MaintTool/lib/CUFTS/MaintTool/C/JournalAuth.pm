package CUFTS::MaintTool::C::JournalAuth;

use strict;
use base 'Catalyst::Base';
use MARC::Record;
use CUFTS::Util::Simple;

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
				@records = CUFTS::DB::JournalsAuth->search_by_issns($c->form->valid->{string});
			} elsif ($c->form->valid->{field} eq 'ids') {
			    my @ids = split /\s+/,  $c->form->valid->{string};
				@records = CUFTS::DB::JournalsAuth->search( { 'id' => {'in' => \@ids} } );
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

sub edit : Local {
    my ($self, $c, $journal_auth_id) = @_;
    
    my $form_validate_edit = {
    	optional => [
    		'save', 'cancel', 'title'
    	],
    	optional_regexp => qr/_(issn|info|title|count)$/,
    	filters => ['trim'],
    };
    
    my $journal_auth = CUFTS::DB::JournalsAuth->retrieve($journal_auth_id);

	$c->form($form_validate_edit);

	if ( $c->form->valid->{cancel} ) {
		return $c->forward('/journalauth/done_edits');
	}
    if ( $c->form->valid->{save} ) {
        unless ($c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown) {		
  		eval {
                $journal_auth->title($c->form->valid->{'title'});
                $journal_auth->update();
            
                $journal_auth->issns->delete_all;
                foreach my $param ( keys %{$c->form->valid} ) {
                    next if $param !~ / ^(.+)_issn $/xsm;

                    my $prefix = $1;
                    my $value  = $c->form->valid->{$param};

                    next if is_empty_string($value);
                    if ($value =~ / (\d{4}) -? (\d{3}[\dxX]) /xsm ) {
                        $journal_auth->add_to_issns({
                            issn  => uc("$1$2"),
                            info  => $c->form->valid->{"${prefix}_info"}
                        });
                    } else {
                        push @{$c->stash->{errors}}, "Invalid ISSN: $value";
                    }
                }
            
                $journal_auth->titles->delete_all;
                foreach my $param ( keys %{$c->form->valid} ) {
                    next if $param !~ / ^(.+)_title $/xsm;

                    my $prefix = $1;
                    my $value  = $c->form->valid->{$param};

                    next if is_empty_string($value);

                    $journal_auth->add_to_titles({
                            title       => $value,
                            title_count => $c->form->valid->{"${prefix}_count"}
                    });
                }
            
            };
            if ($@) {
                push @{$c->stash->{errors}}, $@;
            }
            if ( defined($c->stash->{errors}) ) {
                CUFTS::DB::DBI->dbi_rollback();
                
                # See if there's any "new" fields that need to be added
                
                foreach my $param ( keys %{$c->form->valid} ) {
                    if ( $param =~ / new(\d+)_issn /xsm ) {
                        if ( $1 > $c->stash->{max_issn_field} ) {
                            $c->stash->{max_issn_field} = $1;
                        }
                    }
                    if ( $param =~ / new(\d+)_title /xsm ) {
                        if ( $1 > $c->stash->{max_title_field} ) {
                            $c->stash->{max_title_field} = $1;
                        }
                    }
                }
                
    		} else {
    		    CUFTS::DB::DBI->dbi_commit;
    		    return $c->forward('/journalauth/done_edits');
    		}
        }
    }

    $c->stash->{max_title_field} ||= 0;
    $c->stash->{max_issn_field}  ||= 0;
    
	$c->stash->{load_javascript} = 'journal_auth.js';
    $c->stash->{journal_auth}    = $journal_auth;
    $c->stash->{template}        = 'journalauth/edit.tt';
}


sub edit_marc : Local {
	my ($self, $c, $journal_auth_id) = @_;

	my $journal_auth = CUFTS::DB::JournalsAuth->retrieve($journal_auth_id);

	if ($c->req->params->{cancel}) {
		return $c->forward('/journalauth/done_edits');
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
					return $c->forward('/journalauth/done_edits');
				}
			}
		}
	}
	
	$c->stash->{marc_fields} = $marc_fields;
	$c->stash->{load_javascript} = 'journal_auth.js';
	$c->stash->{journal_auth} = $journal_auth;
	$c->stash->{template} = 'journalauth/edit_marc.tt';
}	

sub done_edits : Local {
    my ($self, $c) = @_;

	$c->req->params({
		'field'  => $c->session->{journal_auth_search_field},
		'string' => $c->session->{journal_auth_search_string},
		'search' => 'search',
	});
	return $c->forward('/journalauth/search');
}


1;