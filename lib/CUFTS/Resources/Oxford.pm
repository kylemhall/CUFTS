## CUFTS::Resources::Ovid
##
## Copyright Michelle Gauthier - Simon Fraser University (2003-12-24)
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

package CUFTS::Resources::Oxford;

use base qw(CUFTS::Resources::Base::Journals);
use CUFTS::Exceptions qw(assert_ne);
use URI::Escape;
use strict;

## title_list_fields - Controls what fields get displayed and loaded from
## title lists.
##

my $base_url = 'http://www3.oup.co.uk/content?';

sub title_list_fields {
	return [qw(
		id
		title
		issn		
		ft_start_date
		vol_ft_start
	)];
}

sub title_list_extra_requires {
	require Text::CSV;
}

sub title_list_split_row {
	my ($class, $row) = @_;
	
	my $csv = Text::CSV->new();
	$csv->parse($row) or
		CUFTS::Exception::App->throw('Error parsing CSV line: ' . $csv->error_input());
	
	my @fields = $csv->fields;
	return \@fields;
}



## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'Journal Name' 		=> 'title',
		'Print ISSN'		=> 'issn',
		'Full-text Start Year' 	=> 'ft_start_date',
		'Start Volume' 		=> 'vol_ft_start',
	};
}




## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

sub can_getFulltext {
	my ($class, $request) = @_;
	
        return 0 unless (assert_ne($request->spage) || assert_ne($request->atitle));
	
	return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
	my ($class, $request) = @_;
	
        return 0 unless assert_ne($request->issue);
	return $class->SUPER::can_getTOC($request);
}

# --------------------------------------------------------------------------------------------

## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##

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
		next unless assert_ne($record->issn);

		my $url = $base_url .  'genre=article';
		$url .= '&issn=' . substr($record->issn,0,4) . '-' . substr($record->issn,4,4);
		$url .= '&volume=' . $request->volume;
		$url .= '&issue=' . $request->issue;
		$url .= ($request->spage) ? '&spage=' . $request->spage
			: '&atitle=' . uri_escape($request->atitle);

		$url .= '&sid=CUFTS:CUFTS&pid=content:fulltext';
			
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
		next unless assert_ne($record->issn);

		my $url = $base_url .  'genre=journal';
		$url .= '&issn=' . substr($record->issn,0,4) . '-' . substr($record->issn,4,4);
		$url .= '&volume=' . $request->volume;
		$url .= '&issue=' . $request->issue;

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
		next unless assert_ne($record->issn);

		my $url .= $base_url .  'genre=journal';
		$url .= '&issn=' . substr($record->issn,0,4) . '-' . substr($record->issn,4,4);
					
		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


1;
