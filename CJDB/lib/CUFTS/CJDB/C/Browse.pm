package CUFTS::CJDB::C::Browse;

use strict;
use base 'Catalyst::Base';
use Data::Dumper;

sub browse : Local {
	my ($self, $c) = @_;

	$c->stash->{template} = 'browse.tt';
}


sub mytags : Local {
	my ($self, $c, @tags) = @_;

	# If user is not logged in (clicked logout on this screen), bump them back to /browse
	
	return $c->redirect('/browse') if !defined($c->stash->{current_account});

	# Add account to the parameters so that /browse/bytags will search on only that account
	
	$c->req->params->{account} = $c->stash->{current_account}->id;
	
	$c->forward('/browse/bytags', \@tags);
}


sub bytags : Local {
	my ($self, $c, @tags) = @_;
	
	$c->req->params->{search_terms} = \@tags;
	$c->req->params->{browse_field} = 'tag';
	
	$c->forward('/browse/journals');
}


sub journals : Local {
	my ($self, $c) = @_;

	my $site_id = $c->stash->{current_site}->id;

	my $search = ref($c->req->params->{search_terms}) eq 'ARRAY' ? [@{$c->req->params->{search_terms}}] : [$c->req->params->{search_terms}];
	my $browse_field = $c->stash->{browse_field} = $c->req->params->{browse_field};

	my $start_record = 0;
	my $per_page;

	my $search_details = $c->session->{search_details}->{$c->stash->{current_site}->id}->{$browse_field}->{join '+', @$search};
	if (defined($search_details)) {
		$start_record = $c->req->params->{start_record} || 0;
		$per_page = $search_details->{per_page};
	}

	my ($journals, $browse_type);
	if ($browse_field eq 'subject') {
		@$search = map { CUFTS::CJDB::Util::strip_title($_) } @$search;
		$journals = CJDB::DB::Journals->search_distinct_by_exact_subjects($site_id, $search, $start_record, $per_page);
	} elsif ($browse_field eq 'association') {
		@$search = map { CUFTS::CJDB::Util::strip_title($_) } @$search;
		$journals = CJDB::DB::Journals->search_distinct_by_exact_associations($site_id, $search, $start_record, $per_page);
	} elsif ($browse_field eq 'tag') {
		@$search = map { CUFTS::CJDB::Util::strip_tag($_) } map {split /,/} @$search;

		# If a viewing level has not been defined, check the local param for local search only,
		# or default to public + local (3).

		my $viewing = defined($c->req->params->{viewing}) ?
				$c->req->params->{viewing} :
				( $c->req->params->{local} ? 2 : 3 );


		$journals = CJDB::DB::Journals->search_distinct_by_tags($search, $start_record, $per_page, $c->req->params->{level}, $c->stash->{current_site}->id, $c->req->params->{account}, $viewing);
	} elsif ($browse_field eq 'issn') {
		$journals = CJDB::DB::Journals->search_by_issn($site_id, $search, 1, $start_record, $per_page);
	} else {
		die("Inavlid browse field: $browse_field");
	}

	# Build search cache information

	unless ($search_details) {
		$search_details->{count} = scalar(@$journals);
		$search_details->{per_page} = max( int(($search_details->{count} / $c->config->{default_max_columns}) + 1 ), $c->config->{default_min_per_page});
		$start_record = $c->req->params->{start_record} || 0;
				
		# Build list of start/end titles and indexes
		
		my $x = 0;
		while ($x < $search_details->{count}) {
			my $y = min( ($x + $search_details->{per_page} - 1), ($search_details->{count} - 1) );
			push @{$search_details->{indexes}}, [$x, $journals->[$x]->title, $journals->[$y]->title];
			$x += $search_details->{per_page};
		}

		my $slice_max = min($#$journals, ($start_record + $search_details->{per_page} - 1));
		@$journals = @$journals[$start_record .. $slice_max];

		$c->session->{search_details}->{$c->stash->{current_site}->id}->{$browse_field}->{join '+', $search} = $search_details;
	}

	$c->stash->{search_details} = $search_details;
	$c->stash->{start_record} = $start_record;
	$c->stash->{records} = $journals;
	$c->stash->{search_terms} = ref($c->req->params->{search_terms}) eq 'ARRAY' ? $c->req->params->{search_terms} : [$c->req->params->{search_terms}];
	$c->stash->{browse_type} = 'journals';
	$c->stash->{show_unified} = $c->stash->{current_site}->cjdb_unified_journal_list eq 'unified' ? 1 : 0;

	$c->stash->{template} = 'browse_journals.tt';
}	

sub titles : Local {
	my ($self, $c) = @_;
	
	my $site_id = $c->stash->{current_site}->id;
	my $search_term = $c->req->params->{search_terms};  # Only one term when searching titles
	my $search_type = $c->stash->{search_type} = $c->req->params->{search_type};

	my $start_record = 0;
	my $per_page;

	my $search_details = $c->session->{search_details}->{$c->stash->{current_site}->id}->{title}->{$search_type}->{$search_term};
	if (defined($search_details)) {
		$start_record = $c->req->params->{start_record} || 0;
		$per_page = $search_details->{per_page};
	}

	my $titles;

	if ($search_type eq 'startswith') {
		my $tmp_search_term = CUFTS::CJDB::Util::strip_articles($search_term);
		$tmp_search_term = CUFTS::CJDB::Util::strip_title($tmp_search_term);
		$tmp_search_term .= '%';
		$titles = CJDB::DB::Titles->search_distinct_by_journal_main($site_id, $tmp_search_term, $start_record, $per_page);
	} elsif ($search_type eq 'advstartswith') {
		my $tmp_search_term = CUFTS::CJDB::Util::strip_articles($search_term);
		$tmp_search_term = lc($tmp_search_term);
		$tmp_search_term = "^${search_term}.*";
		$titles = CJDB::DB::Titles->search_re_distinct_by_journal_main($site_id, $tmp_search_term, $start_record, $per_page);
	} elsif ($search_type eq 'exact') {

		# Should exact title searches strip articles?

		my $tmp_search_term = CUFTS::CJDB::Util::strip_articles($search_term);
		$tmp_search_term = CUFTS::CJDB::Util::strip_title($tmp_search_term);
		$titles = CJDB::DB::Titles->search_distinct_by_journal_main($site_id, $tmp_search_term, $start_record, $per_page);
	} elsif ($search_type eq 'any') {
		my $tmp_search_term = CUFTS::CJDB::Util::strip_articles($search_term);
		$tmp_search_term = CUFTS::CJDB::Util::strip_title($tmp_search_term);
		my @search_terms = split / /, $tmp_search_term;
		
		$titles = CJDB::DB::Titles->search_distinct_by_journal_main_union($site_id, \@search_terms, $start_record, $per_page);
	} elsif ($search_type eq 'all') {
		my $tmp_search_term = CUFTS::CJDB::Util::strip_articles($search_term);
		$tmp_search_term = CUFTS::CJDB::Util::strip_title($tmp_search_term);
		my @search_terms = split / /, $tmp_search_term;

		$titles = CJDB::DB::Titles->search_distinct_by_journal_main_intersect($site_id, \@search_terms, $start_record, $per_page);
	} else {
		die("Unrecognized title search type: " . Dumper($search_type) );
	}

	# Build search cache information

	unless ($search_details) {
		$search_details->{count} = scalar(@$titles);
		$search_details->{per_page} = max( int(($search_details->{count} / $c->config->{default_max_columns}) + 1 ), $c->config->{default_min_per_page});
		$start_record = $c->req->params->{start_record} || 0;
				
		# Build list of start/end titles and indexes
		
		my $x = 0;
		while ($x < $search_details->{count}) {
			my $y = min( ($x + $search_details->{per_page} - 1), ($search_details->{count} - 1) );
			push @{$search_details->{indexes}}, [$x, $titles->[$x]->title, $titles->[$y]->title];
			$x += $search_details->{per_page};
		}

		my $slice_max = min($#$titles, ($start_record + $search_details->{per_page} - 1));		
		@$titles = @$titles[$start_record .. $slice_max];

		$c->session->{search_details}->{$c->stash->{current_site}->id}->{title}->{$search_type}->{$search_term} = $search_details;
	}

	$c->stash->{search_details} = $search_details;
	$c->stash->{records} = $titles;
	$c->stash->{start_record} = $start_record;
	$c->stash->{browse_type} = 'titles';
	$c->stash->{browse_field} = 'title';
	$c->stash->{search_terms} = [$c->req->params->{search_terms}];
	$c->stash->{show_unified} = $c->stash->{current_site}->cjdb_unified_journal_list eq 'unified' ? 1 : 0;

	$c->stash->{template} = 'browse_journals.tt';
}


sub subjects : Local {
	my ($self, $c) = @_;
	
	my $site_id = $c->stash->{current_site}->id;

	my $search_term = $c->req->params->{search_terms};
	my $search_type = $c->req->params->{search_type};
	$search_term = CUFTS::CJDB::Util::strip_title($search_term);

	my @subjects;

	if ($search_type eq 'startswith') {
		$search_term .= '%';
		@subjects = CJDB::DB::Subjects->search_distinct($site_id, $search_term);
	} elsif ($search_type eq 'exact') {
		@subjects = CJDB::DB::Subjects->search_distinct($site_id, $search_term);
	} elsif ($search_type eq 'any') {
		my @search_terms = split / /, $search_term;
		@subjects = CJDB::DB::Subjects->search_distinct_union($site_id, @search_terms);
	} elsif ($search_type eq 'all') {
		my @search_terms = split / /, $search_term;
		@subjects = CJDB::DB::Subjects->search_distinct_intersect($site_id, @search_terms);
	} else {
		die("Unrecognized subject search type: $search_type");
	}

	$c->stash->{subjects}     = \@subjects;
	$c->stash->{search_terms} = $c->req->params->{search_terms};
	$c->stash->{search_type}  = $c->req->params->{search_type};

	$c->stash->{template} = 'browse_subjects.tt';
}

sub associations : Local {
	my ($self, $c) = @_;
	
	my $site_id = $c->stash->{current_site}->id;

	my $search_term = $c->req->params->{search_terms};
	my $search_type = $c->req->params->{search_type};
	$search_term = CUFTS::CJDB::Util::strip_title($search_term);

	my @associations;

	if ($search_type eq 'startswith') {
		$search_term .= '%';
		@associations = CJDB::DB::Associations->search_distinct($site_id, $search_term);
	} elsif ($search_type eq 'exact') {
		@associations = CJDB::DB::Associations->search_distinct($site_id, $search_term);
	} elsif ($search_type eq 'any') {
		my @search_terms = split / /, $search_term;
		@associations = CJDB::DB::Associations->search_distinct_union($site_id, @search_terms);
	} elsif ($search_type eq 'all') {
		my @search_terms = split / /, $search_term;
		@associations = CJDB::DB::Associations->search_distinct_intersect($site_id, @search_terms);
	} else {
		die("Unrecognized association search type: $search_type");
	}
	
	$c->stash->{associations} = \@associations;
	$c->stash->{search_terms} = $c->req->params->{search_terms};
	$c->stash->{search_type}  = $c->req->params->{search_type};
	$c->stash->{template}     = 'browse_associations.tt';
}



sub show : Local {
	my ($self, $c) = @_;

	my $browse_field = $c->req->params->{browse_field};
	
	if ($browse_field eq 'title') {
		return $c->forward('/browse/titles');
	} elsif ($browse_field eq 'subject') {
		return $c->forward('/browse/subjects');
	} elsif ($browse_field eq 'association') {
		return $c->forward('/browse/associations');
	} elsif ($browse_field eq 'issn') {
		return $c->forward('/browse/journals');
	} elsif ($browse_field eq 'tag') {
		return $c->forward('/browse/journals');
	}
	
	die('Invalid browse_field value: ' . $browse_field);
}


sub selected_journals : Local {
	my ($self, $c) = @_;

	$c->stash->{template} = 'selected_journals.tt';
}	


sub lcc : Local {
	my ($self, $c) = @_;

	$c->stash->{template} = 'lcc_browse.tt';
}


sub max {
	my $max = shift;
	while (defined(my $val = shift)) {
		$val > $max and
			$max = $val;
	}
	
	return $max;
}

sub min {
	my $min = shift;
	while (defined(my $val = shift)) {
		$val < $min and
			$min = $val;
	}

	return $min;
}



1;
