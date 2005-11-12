## CUFTS::Resources::Lexis_Nexis_AC
##
## Copyright Michelle Gauthier - Simon Fraser University (2004)
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

package CUFTS::Resources::Lexis_Nexis_AC;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions qw(assert_ne);

use strict;

sub title_list_fields {
	return [qw(
		id
		title
		issn
		ft_start_date
		ft_end_date
		db_identifier
	)];
}

sub clean_data {
	my ($self, $record) = @_;

	$record->{'title'} =~ s/\(.+?\)//g;
	
	return $self->SUPER::clean_data($record);
}



sub build_linkJournal {
	my ($class, $records, $resource, $site, $request) = @_;
	
	defined($records) && scalar(@$records) > 0 or 
		return [];
	defined($resource) or 
		CUFTS::Exception::App->throw('No resource defined in build_linkJournal');
	defined($site) or 
		CUFTS::Exception::App->throw('No site defined in build_linkJournal');
	defined($request) or 
		CUFTS::Exception::App->throw('No request defined in build_linkJournal');

	my @results;

	foreach my $record (@$records) {
		next unless assert_ne($record->db_identifier);
  
		my $url = 'http://cisweb.lexis-nexis.com/sourceselect/returnToSearch.asp?csisrc=';
		$url .= $record->db_identifier;
		$url .= '&srcpdn=academic&cc=&spn=&product=universe&unix=http://web.lexis-nexis.com/universe';

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}

sub build_linkDatabase {
        my ($class, $records, $resource, $site, $request) = @_;

        defined($records) && scalar(@$records) > 0 or
                return [];
        defined($resource) or
                CUFTS::Exception::App->throw('No resource defined in build_linkDatabase');
        defined($site) or
                CUFTS::Exception::App->throw('No site defined in build_linkDatabase');
        defined($request) or
                CUFTS::Exception::App->throw('No request defined in build_linkDatabase');

        my @results;

        foreach my $record (@$records) {
                my $result = new CUFTS::Result('http://web.lexis-nexis.com/universe');
                $result->record($record);
        
                push @results, $result;
        }
                
        return \@results;
}


1;
