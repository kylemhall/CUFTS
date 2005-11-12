## CUFTS::Resources::Blackwell
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
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

package CUFTS::Resources::Blackwell;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions qw(assert_ne);

use strict;

## title_list_fields - Controls what fields get displayed and loaded from
## title lists.
##

sub title_list_fields {
	return [qw(
		id
		title
		issn
		e_issn
		
		ft_start_date
		ft_end_date
		
		vol_ft_start
		vol_ft_end
		iss_ft_start
		iss_ft_end
		
		embargo_months
		embargo_days

		journal_url
	)];
}


## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'ISSN' 			=> 'issn',
		'EISSN' 		=> 'e_issn',
		'TITLE' 		=> 'title',
		'URL'			=> 'journal_url',
		'FIRST ONLINE YEAR'	=> 'ft_start_date',
		'FIRST ONLINE VOLUME'	=> 'vol_ft_start',
		'FIRST ONLINE ISSUE'	=> 'iss_ft_start',
		'LAST ONLINE YEAR'	=> 'ft_end_date',
		'LAST ONLINE VOLUME'	=> 'vol_ft_end',
		'LAST ONLINE ISSUE'	=> 'iss_ft_end',
	};
}


## global_resource_details - Controls which details are displayed on the global
## resource pages
##

sub global_resource_details {
	my ($class) = @_;
	return [ @{$class->SUPER::global_resource_details},
		 qw(
			resource_identifier
			database_url
			url_base
		 )
	];
}


## local_resource_details - Controls which details are displayed on the local
## resource pages
##

sub local_resource_details {
	my ($class) = @_;
	return [ @{$class->SUPER::local_resource_details},
		 qw(
			resource_identifier
			database_url
			url_base
			auth_name
			auth_passwd
		 )
	];
}


## overridable_resource_details - Controls which of the *global* resource details
## are displayed on the *local* resource pages to possibly be overridden
##

sub overridable_resource_details {
	my ($class) = @_;
	return [ @{$class->SUPER::overridable_resource_details},
		 qw(
			resource_identifier
			database_url
			url_base
			auth_name
			auth_passwd
		 )
	];
}
	

## help_template - path to the help template for this resource relative to the
## general templates directory
##

#sub help_template {
#	return 'help/Template';
#}


## resource_details_help - A hash ref containing the hoverover help for each of the
## local resource details
##

sub resource_details_help {
	return {
		$_[0]->SUPER::resource_details_help,
		'example_detail' => 'This is an example detail help item that appears for the (?) tooltip',
	}
}

## -------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

#sub can_getFulltext {
#	my ($class, $request) = @_;
#	
#	return 0 unless assert_ne($request->spage);
#	return $class->SUPER::can_getFulltext($request);
#}

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

		my $url;
		$url = $site->proxy_prefix if $resource->proxy;
		$url = $resource->base_url . $request->issn;

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
		CUFTS::Exception::App->throw('No resource defined in build_linkJournal');
	defined($site) or 
		CUFTS::Exception::App->throw('No site defined in build_linkJournal');
	defined($request) or 
		CUFTS::Exception::App->throw('No request defined in build_linkJournal');

	my @results;

	foreach my $record (@$records) {
		next unless assert_ne($record->issn);

		my $url;
		$url = $site->proxy_prefix if $resource->proxy;
		$url = $resource->base_url . $request->issn;

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

		my $url;
		$url = $site->proxy_prefix if $resource->proxy;
		$url = $resource->base_url . $request->issn;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


1;
