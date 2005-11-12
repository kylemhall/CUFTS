## CUFTS::DB::LocalJournals
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

package CUFTS::DB::LocalJournals;

use strict;
use base 'CUFTS::DB::DBI';

use CUFTS::DB::LocalJournalDetails;
use CUFTS::DB::Journals;

__PACKAGE__->table('local_journals');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
	id

	title
	issn
	e_issn
	resource
	journal
	active
	vol_cit_start
	vol_cit_end
	vol_ft_start
	vol_ft_end
	iss_cit_start
	iss_cit_end
	iss_ft_start
	iss_ft_end
	cit_start_date
	cit_end_date
	ft_start_date
	ft_end_date
	embargo_months
	embargo_days
	journal_auth

	created
	scanned
	modified
));                                                                                                        

__PACKAGE__->sequence('local_journals_id_seq');

__PACKAGE__->has_a('journal', 'CUFTS::DB::Journals');
__PACKAGE__->has_details('details', 'CUFTS::DB::LocalJournalDetails' => 'local_journal');
__PACKAGE__->details_columns(qw/
	db_identifier	
	toc_url
	journal_url
	urlbase
	publisher
	abbreviation
	current_months
	cjdb_note
/);



sub normalize_column_values {
	my ($self, $values) = @_;
	
	# Check ISSNs for dashes and strip them out

	if (exists($values->{'issn'}) && defined($values->{'issn'}) && $values->{'issn'} ne '') {
		$values->{'issn'} =~ s/(\d{4})\-?(\d{3}[\dxX])/$1$2/ or
			$self->_croak('issn is not valid: ' . $values->{'issn'});
	}

	if (exists($values->{'e_issn'}) && defined($values->{'e_issn'}) && $values->{'e_issn'} ne '') {
		$values->{'e_issn'} =~ s/(\d{4})\-?(\d{3}[\dxX])/$1$2/ or
			$self->_croak('e_issn is not valid: ' . $values->{'e_issn'});
	}

	return 1;   # ???
}

sub global_join_field {
	return 'journal';
}

1;
