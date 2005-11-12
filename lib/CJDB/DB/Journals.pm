## CJDB::DB::Journals
##
## Copyright Todd Holbrook, Simon Fraser University (2003)
##
## This file is part of CJDB.
##
## CJDB is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 2 of the License, or (at your option)
## any later version.
## 
## CJDB is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CJDB; if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CJDB::DB::Journals;

use strict;
use base 'CJDB::DB::DBI';
use CJDB::DB::Titles;
use CJDB::DB::Links;
use CJDB::DB::Subjects;
use CJDB::DB::Relations;
use CJDB::DB::Associations;
use CJDB::DB::ISSNs;
use CUFTS::DB::JournalsAuth;

__PACKAGE__->table('journals');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
	id

	title
	sort_title
	stripped_sort_title

	call_number

	journals_auth

	site

	created
));                                                                                                        
__PACKAGE__->columns(Essential => __PACKAGE__->columns);
__PACKAGE__->sequence('journals_id_seq');

__PACKAGE__->has_many('titles', 'CJDB::DB::Titles' => 'journal');
__PACKAGE__->has_many('links', 'CJDB::DB::Links' => 'journal');
__PACKAGE__->has_many('subjects', 'CJDB::DB::Subjects' => 'journal');
__PACKAGE__->has_many('associations', 'CJDB::DB::Associations' => 'journal');
__PACKAGE__->has_many('relations', 'CJDB::DB::Relations' => 'journal');
__PACKAGE__->has_many('issns', 'CJDB::DB::ISSNs' => 'journal');
__PACKAGE__->has_a('journals_auth' => 'CUFTS::DB::JournalsAuth');


sub search_distinct_by_exact_subjects {
	my ($class, $site, $search, $offset, $limit) = @_;

	scalar(@$search) == 0 and
		return [];
	
	$limit ||= 'ALL';
	$offset ||= 0;

	my @bind = ($site);	
	my $sql = "SELECT DISTINCT ON (journals.stripped_sort_title, journals.id) journals.* FROM journals ";
	my $where = " WHERE journals.site = ? ";

	my $count = 0;
	foreach my $search (@$search) {
		$count++;

		$sql .= " JOIN subjects AS subjects${count} ON (subjects${count}.journal = journals.id) ";
		$where .= " AND subjects${count}.search_subject = ? ";
		
		push @bind, $search;
	}

	$sql .= $where;
	$sql .= " ORDER BY journals.stripped_sort_title, journals.id LIMIT $limit OFFSET $offset";

	my $dbh = $class->db_Main();
        my $sth = $dbh->prepare($sql, {pg_server_prepare => 0});
	
	$sth->execute(@bind);
	my @results = $class->sth_to_objects($sth);
	return \@results;
}		

sub search_distinct_by_exact_associations {
	my ($class, $site, $search, $offset, $limit) = @_;

	scalar(@$search) == 0 and
		return [];
	
	$limit ||= 'ALL';
	$offset ||= 0;

	my @bind = ($site);	
	my $sql = "SELECT DISTINCT ON (journals.stripped_sort_title, journals.id) journals.* FROM journals ";
	my $where = " WHERE journals.site = ? ";

	my $count = 0;
	foreach my $search (@$search) {
		$count++;

		$sql .= " JOIN associations AS associations${count} ON (associations${count}.journal = journals.id) ";
		$where .= " AND associations${count}.search_association = ? ";
		
		push @bind, $search;
	}

	$sql .= $where;
	$sql .= " ORDER BY journals.stripped_sort_title, journals.id LIMIT $limit OFFSET $offset";

	my $dbh = $class->db_Main();
        my $sth = $dbh->prepare($sql, {pg_server_prepare => 0});
	
	$sth->execute(@bind);
	my @results = $class->sth_to_objects($sth);
	return \@results;
}		


sub search_by_issn {
	my ($class, $site, $issns, $exact, $offset, $limit) = @_;

	scalar(@$issns) == 0 and
		return [];
	
	$limit ||= 'ALL';
	$offset ||= 0;

	my $search_type = $exact ? '=' : 'LIKE';
	
	my $issn = uc($issns->[0]);
	$issn =~ s/[^0-9X]//g;

	my $sql = <<"";
SELECT DISTINCT ON (journals.stripped_sort_title, journals.id) journals.* FROM journals
JOIN issns ON (journals.id = issns.journal) 
WHERE issns.issn $search_type ? AND journals.site = ?
ORDER BY journals.stripped_sort_title, journals.id
LIMIT $limit OFFSET $offset;

	my $dbh = $class->db_Main();
        my $sth = $dbh->prepare($sql, {pg_server_prepare => 0});
	
	$sth->execute($issn, $site);
	my @results = $class->sth_to_objects($sth);
	return \@results;
}

sub search_distinct_by_tags {
	my ($class, $tags, $offset, $limit, $level, $site, $account, $viewing) = @_;
	
	scalar(@$tags) == 0 and
		return [];

	$limit ||= 'ALL';
	$offset ||= 0;

	my @bind;	
	my $sql = 'SELECT DISTINCT ON (combined_journals.stripped_sort_title, combined_journals.id) combined_journals.* FROM (';

	my @search;
	foreach my $tag (@$tags) {
		my $search_sql = '(SELECT journals.* FROM journals JOIN tags ON (journals.journals_auth = tags.journals_auth) WHERE tag = ?';
		push @bind, $tag;

		# Full on public search.
		
		if ($viewing == 0) {
			$search_sql .= ' AND tags.viewing = ? ';
			push @bind, 0;
		} elsif ($viewing == 1) {
			$search_sql .= ' AND tags.viewing = ? AND tags.site = ? ';
			push @bind, 1, $site;
		} elsif ($viewing == 2) {
			$search_sql .= ' AND tags.viewing = ? AND tags.site = ?	';
			push @bind, 2, $site;
		} elsif ($viewing == 3) {
			$search_sql .= ' AND (tags.viewing = ? OR (tags.viewing = ? AND tags.site = ?)) ';
			push @bind, 1, 2, $site;
		}

		if ($level) {
			$search_sql .= ' AND tags.level >= ?';
			push @bind, $level;
		}

		if ($account) {
			$search_sql .= ' AND tags.account = ?';
			push @bind, $account;
		}

		$search_sql .= ' )';
		push @search, $search_sql;
	}
		
	$sql .= join ' INTERSECT ', @search;
	$sql .= ") AS combined_journals ORDER BY combined_journals.stripped_sort_title, combined_journals.id LIMIT $limit OFFSET $offset";

	my $dbh = $class->db_Main();
	my $sth = $dbh->prepare($sql, {pg_server_prepare => 0});
	$sth->execute(@bind);
	my @results = $class->sth_to_objects($sth);	
	
	return \@results;
}	












__PACKAGE__->set_sql('distinct_by_title' => qq{
	SELECT DISTINCT journals.*
	FROM journals JOIN titles ON (journals.id = titles.journal)
	WHERE journals.site = ? AND titles.search_title LIKE ?
	ORDER BY journals.sort_title
});


	
1;
