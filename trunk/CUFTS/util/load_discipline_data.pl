#!/usr/bin/perl

use lib 'lib';

use CUFTS::DB::Resources;
use CJDB::DB::Journals;
use CJDB::DB::Tags;
use CJDB::DB::Accounts;
use CJDB::DB::ISSNs;
use CUFTS::CJDB::Util;

my @accounts = CJDB::DB::Accounts->retrieve_all;
my %accounts;
foreach my $account (@accounts) {
	$accounts{$account->name} = $account->id;
}

while (<>) {
	my ($name, $tags, @issns) = split /\t/;
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;
	
	next unless $name;
	die("Missing account: $name") unless $accounts{$name};
	
	
	my @tags = split /,/, $tags;
	foreach my $x (0 .. $#tags) {
		$tags[$x] = CUFTS::CJDB::Util::strip_tag($tags[$x]);
	}
	
	my %seen;
	foreach my $issn (@issns) {
		$issn = uc($issn);
		$issn =~ s/^\s+//;
		$issn =~ s/\s+$//;
		$issn =~ s/-//;
		
		next if !defined($issn);
		next unless $issn =~ /\d{7}[\dX]/;

		next if $seen{$issn};
		
		my @issn_records = CJDB::DB::ISSNs->search('site' => 1, 'issn' => $issn);
		foreach my $issn_record (@issn_records)	{
			foreach my $tag (@tags) {

				CJDB::DB::Tags->find_or_create({
					site => 1,
					account => $accounts{$name},
					tag => $tag,
					level => 100,
					viewing => 1,
					journals_auth => $issn_record->journal->journals_auth->id,
				});
			}
		}
	}
}

CJDB::DB::DBI->dbi_commit;