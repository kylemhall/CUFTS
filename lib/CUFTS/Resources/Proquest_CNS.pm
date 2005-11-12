## CUFTS::Resources::Proquest_CNS
## PURPOSE: a variation on the Proquest module, specifically for Canadian Newsstand products
##          since they do not conform to the volume/issue model and an article title search
##          is more effective
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

package CUFTS::Resources::Proquest_CNS;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions qw(assert_ne);

use strict;

my $base_url = 'http://gateway.proquest.com/openurl?ctx_ver=Z39.88-2003&res_id=xri:pqd&rft_val_fmt=ori:fmt:kev:mtx:journal';

sub title_list_fields {
	return [qw(
		id
		title
		issn
		ft_start_date
		ft_end_date
		cit_start_date
		cit_end_date
		embargo_days
		db_identifier
	)];
}

sub overridable_resource_details {
	return undef;
}
	

sub help_template {
	return 'help/Proquest';
}

sub resource_details_help {
	return {
	}
}


sub title_list_field_map {
	return {
		'title' 		=> 'title',
		'issn' 			=> 'issn',
		'cit_start_date' 	=> 'cit_start_date',
		'cit_end_date' 		=> 'cit_end_date',
		'ft_start_date' 	=> 'ft_start_date',
		'ft_end_date'		=> 'ft_end_date',
		'embargo_days'		=> 'embargo_days',
		'db_identifier'		=> 'db_identifier',
	};
}


sub can_getFulltext {
	my ($class, $request) = @_;
	
	return 0 unless assert_ne($request->atitle);
	return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
	my ($class, $request) = @_;
	
	return 0 unless assert_ne($request->date);
	return $class->SUPER::can_getTOC($request);
}

sub build_linkFulltext {
	my ($class, $records, $resource, $site, $request) = @_;

	defined($records) && scalar(@$records) > 0 or 
		return [];
	defined($resource) or 
		CUFTS::Exception::App->throw('No resource defined in build_linkFulltext');
	defined($site) or 
		CUFTS::Exception::App->throw('No site defined in build_linkFulltext');
	defined($request) or 
		CUFTS::Exception::App->throw('No request defined in build_linkFulltext');

	my @results;

	foreach my $record (@$records) {
		next unless (assert_ne($record->issn) || assert_ne($record->title));

		my @params = ('atitle=' . $request->atitle); # must be defined else wouldn't be here

		if(defined($record->issn)) { 
			 push @params, 'issn=' . $record->issn;
		} elsif(defined($record->title)) { 
			push @params, 'jtitle=' . $request->title;
		}

		defined($request->date) and 
			push @params, 'date=' . $request->date;
		
		my $url = $base_url . '&genre=article&';
		$url .= join '&', @params;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}



sub build_linkTOC {
	my ($class, $records, $resource, $site, $request) = @_;
	
	defined($records) && scalar(@$records) > 0 or 
		return [];
	defined($resource) or 
		CUFTS::Exception::App->throw('No resource defined in build_linkTOC');
	defined($site) or 
		CUFTS::Exception::App->throw('No site defined in build_linkTOC');
	defined($request) or 
		CUFTS::Exception::App->throw('No request defined in build_linkTOC');

	my @results;

	foreach my $record (@$records) {
		next unless (assert_ne($record->issn) || assert_ne($record->title));

		my @params = ();

		if(defined($record->issn)) {
			push @params, '&issn=' . $record->issn; 
		}
		elsif (defined($record->title)) {
			push @params, '&title=' . $record->title;
		}

		push @params, 'date=' . $request->date;

		my $url = $base_url;
		$url .= join '&', @params;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
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
		next unless (assert_ne($record->issn) || assert_ne($record->title));

		my $url = $base_url . '&svc_id=xri:pqil:context=title';

		if(defined($record->issn)) {
			$url .= '&issn=' .  $record->issn;
		}
		elsif (defined($record->title)) {
                        $url .= '&title=' .  $record->title;
                }
		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


1;
