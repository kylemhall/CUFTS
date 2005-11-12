package CUFTS::CJDB::C::Journal;

use strict;
use base 'Catalyst::Base';


sub view : Private {
	my ($self, $c, $journal_id) = @_;

	defined($journal_id) or
		die "journal id not defined";
	
	my $site_id = $c->stash->{current_site}->id;

	my $journal = CJDB::DB::Journals->retrieve($journal_id);
	defined($journal) or
		die("Unable to retrieve journal id $journal_id");

	if ($c->stash->{current_account}) {
		my @my_tags =  CJDB::DB::Tags->search(
			'journals_auth' => $journal->journals_auth,
			'account' => $c->stash->{current_account}->id,
			{ order_by => 'tag' }
		);
		$c->stash->{my_tags} = \@my_tags;
	}

	$c->stash->{tags} = CJDB::DB::Tags->get_tag_summary($journal->journals_auth, $c->stash->{current_site}->id, (defined($c->stash->{current_account}) ? $c->stash->{current_account}->id : undef));
	$c->stash->{journal} = $journal;	
	$c->stash->{template} = 'journal.tt';
}

sub manage_tags : Local {
	my ($self, $c, $journal_id) = @_;
	
	$c->stash->{'show_manage_tags'} = 1;
	
	$c->forward('/journal/view', [$journal_id]);
}

1;
