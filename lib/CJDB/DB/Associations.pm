## CJDB::DB::Associations
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

package CJDB::DB::Associations;

use strict;
use base 'CJDB::DB::DBI';
use CJDB::DB::Journals;

__PACKAGE__->table('cjdb_associations');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
	id

	journal
	association
	search_association

	site
));                                                                                                        
__PACKAGE__->columns(Essential => __PACKAGE__->columns);
__PACKAGE__->sequence('cjdb_associations_id_seq');
__PACKAGE__->has_a('journal' => 'CJDB::DB::Journals');

__PACKAGE__->set_sql('distinct' => qq{
	SELECT DISTINCT ON (search_association) cjdb_associations.* FROM cjdb_associations
	WHERE site = ? AND search_association LIKE ?
	ORDER BY search_association
});


sub search_distinct_combined {
	my ($class, $join_type, $site, @search) = @_;

	defined($join_type) && ($join_type =~ /^(INTERSECT|UNION|EXCEPT)$/) or
		CJDB::Exception::DB->throw("Bad join type in search_distinct_combined: $join_type");

	# Return an empty set if there were no search terms

	scalar(@search) == 0 and
		return [];

	my $search_string = 'SELECT * FROM cjdb_associations WHERE cjdb_associations.site = ? AND cjdb_associations.search_association ~ ?';

	my $sql = 'SELECT DISTINCT ON (search_association) * FROM (';
	
	$sql .= $search_string;
	foreach my $count (1 .. (scalar(@search) - 1)) {
		$sql .= " $join_type $search_string";
	}

	$sql .= ') AS combined_associations';

	warn($sql);
	
	my @bind;
	foreach my $search_term (@search) {
		push @bind, ($site, $search_term);
	}

	warn(join ',', @bind);
	
	my $dbh = $class->db_Main();
	my $sth = $dbh->prepare_cached($sql);
	$sth->execute(@bind);
	my @results = $class->sth_to_objects($sth);	
	
	return @results;
}

sub search_distinct_union {
	my ($class, $site, @search) = @_;
	
	return $class->search_distinct_combined('UNION', $site, @search);
}

sub search_distinct_intersect {
	my ($class, $site, @search) = @_;
	
	return $class->search_distinct_combined('INTERSECT', $site, @search);
}


1;
