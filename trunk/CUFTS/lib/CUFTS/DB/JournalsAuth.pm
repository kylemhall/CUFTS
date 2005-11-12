## CUFTS::DB::Journals
##
## Copyright Todd Holbrook, Simon Fraser University (2003)
##
## This file is part of CUFTS.
##
## CUFTS is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 2 of the License, or (at your option)
## any later version.
## 
## CUFTS is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CUFTS; if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CUFTS::DB::JournalsAuth;

use strict;
use base 'CUFTS::DB::DBI';

use CUFTS::DB::JournalsAuthTitles;
use CUFTS::DB::JournalsAuthISSNs;
use MARC::Record;

__PACKAGE__->table('journals_auth');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
	id

	title
	MARC

	created
	modified
));                                                                                                        
__PACKAGE__->columns(Essential => qw(
	id
	title
));

__PACKAGE__->sequence('journals_auth_id_seq');

__PACKAGE__->has_many('titles', 'CUFTS::DB::JournalsAuthTitles' => 'journal_auth');
__PACKAGE__->has_many('issns', 'CUFTS::DB::JournalsAuthISSNs' => 'journal_auth');

1;

sub search_by_issns {
	my ($class, @issns) = @_;
	
	scalar(@issns) == 0 and
		return ();
		
	my @bind;
	my $sql = 'SELECT DISTINCT ON (journals_auth.id) journals_auth.* FROM journals_auth JOIN journals_auth_issns ON (journals_auth.id = journals_auth_issns.journal_auth) WHERE journals_auth_issns.issn IN (';

	my $count = 0;
	foreach my $issn (@issns) {
		$issn = uc($issn);
		$issn =~ tr/0-9X//cd;
		$issn =~ /^\d{7}[\dX]$/ or
			next;

		$count++;
		$sql .= '?';
		$count == scalar(@issns) or
			$sql .= ',';
		
		push @bind, $issn;
	}

	$sql .= ')';

	my $dbh = $class->db_Main();
	my $sth = $dbh->prepare_cached($sql);
	$sth->execute(@bind);
	
	my @results = $class->sth_to_objects($sth);	

	return @results;
}	

__PACKAGE__->set_sql('by_title' => qq{
	SELECT DISTINCT ON (journals_auth.id) journals_auth.* FROM journals_auth JOIN journals_auth_titles ON (journals_auth_titles.journal_auth = journals_auth.id) WHERE journals_auth_titles.title ILIKE ?
});	


sub marc_object {
	my ($self) = @_;
	
	defined($self->marc) or
		return undef;

	my $obj = MARC::Record->new_from_usmarc($self->marc);
	return $obj;
}


__END__

Original code before Catalyst and new JournalsAuth rewrite




sub normalize_column_values {
	my ($self, $values) = @_;
	
	# Check ISSNs for dashes and strip them out

	if (exists($values->{'issn'}) && defined($values->{'issn'}) && $values->{'issn'} ne '') {
			$self->_croak('issn is not valid: ' . $values->{'issn'});
	}

	if (exists($values->{'e_issn'}) && defined($values->{'e_issn'}) && $values->{'e_issn'} ne '') {
		$values->{'e_issn'} = uc($values->{'e_issn'});
		$values->{'e_issn'} =~ s/(\d{4})\-?(\d{3}[\dxX])/$1$2/ or
			$self->_croak('e_issn is not valid: ' . $values->{'e_issn'});
	}

	return 1;   # ???
}




__PACKAGE__->set_sql('active_site' => qq{
	SELECT DISTINCT ON (journals_auth.title, journals_auth.id) journals_auth.id,journals_auth.title,journals_auth.issn,journals_auth.e_issn,journals_auth.created,journals_auth.modified FROM journals_auth
	JOIN journals ON (journals.journal_auth = journals_auth.id)
	JOIN local_journals ON (journals.id = local_journals.journal)
	JOIN local_resources ON (local_journals.resource = local_resources.id)
	WHERE local_journals.active = true AND
	      local_resources.active = true AND
	      local_resources.site = ? AND
	      journals_auth.title like ?
	ORDER BY journals_auth.title, journals_auth.id
});

__PACKAGE__->set_sql('all_active_site' => qq{
	SELECT DISTINCT ON (journals_auth.title, journals_auth.id) journals_auth.id,journals_auth.title,journals_auth.issn,journals_auth.e_issn,journals_auth.created,journals_auth.modified FROM journals_auth
	JOIN journals ON (journals.journal_auth = journals_auth.id)
	JOIN local_journals ON (journals.id = local_journals.journal)
	JOIN local_resources ON (local_journals.resource = local_resources.id)
	WHERE local_journals.active = true AND
	      local_resources.active = true AND
	      local_resources.site = ?
	ORDER BY journals_auth.title, journals_auth.id
});


1;
