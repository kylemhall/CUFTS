package CUFTS::CJDB::C::Journal;

use strict;
use base 'Catalyst::Base';
use CUFTS::Util::Simple;
use XML::RAI;
use LWP::Simple;

sub view : Private {
	my ($self, $c, $journals_auth_id) = @_;

	defined($journals_auth_id) or
		die "journal auth id not defined";
	
	my $site_id = $c->stash->{current_site}->id;

	my $journal = CJDB::DB::Journals->search(site => $site_id, journals_auth => $journals_auth_id)->first;
	defined($journal) or
		die("Unable to retrieve journal auth id $journals_auth_id");

	if ($c->stash->{current_account}) {
		my @my_tags =  CJDB::DB::Tags->search(
			'journals_auth' => $journals_auth_id,
			'account' => $c->stash->{current_account}->id,
			{ order_by => 'tag' }
		);
		$c->stash->{my_tags} = \@my_tags;
	}

    if ( not_empty_string($journal->rss) ) {
        my $xml = get($journal->rss);
        
        XML::RSS::Parser->register_ns_prefix( 'prism', 'http://purl.org/rss/1.0/modules/prism/' );
        
        XML::RAI::Channel->add_mapping( 'year',   'year'   );
        XML::RAI::Channel->add_mapping( 'month',  'month'  );
        XML::RAI::Channel->add_mapping( 'day',    'day'    );
        XML::RAI::Channel->add_mapping( 'date',   'prism:coverDisplayDate' );
        
        XML::RAI::Item->add_mapping( 'volume',     'volume',    'prism:volume' );
        XML::RAI::Item->add_mapping( 'issue',      'issue',     'prism:number' );
        XML::RAI::Item->add_mapping( 'startPage',  'startPage', 'prism:startingPage' );
        XML::RAI::Item->add_mapping( 'endPage',    'endPage',   'prism:endingPage' );
        XML::RAI::Item->add_mapping( 'date',       'pubDate',   'prism:publicationDate' );
        XML::RAI::Item->add_mapping( 'authors',    'authors',   'author', 'dc:creator' );
        XML::RAI::Item->add_mapping( 'publisher',   'dc:publisher' );
        
        
        eval {
            $c->stash->{rss} = XML::RAI->parse_string($xml);
        };
        
    }

	$c->stash->{tags} = CJDB::DB::Tags->get_tag_summary($journals_auth_id, $c->stash->{current_site}->id, (defined($c->stash->{current_account}) ? $c->stash->{current_account}->id : undef));
	$c->stash->{journal} = $journal;	
	$c->stash->{template} = 'journal.tt';
}

sub manage_tags : Local {
	my ($self, $c, $journals_auth_id) = @_;
	
	$c->stash->{'show_manage_tags'} = 1;
	
	$c->forward('/journal/view', [$journals_auth_id]);
}

1;
