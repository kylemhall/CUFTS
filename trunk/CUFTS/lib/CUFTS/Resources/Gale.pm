## CUFTS::Resources::Gale
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

package CUFTS::Resources::Gale;

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
		cit_start_date
		cit_end_date

		journal_url
	)];
}

sub title_list_field_map {
	return {
		'title'			=> 'title',
		'issn'			=> 'issn',
		'citation_start'	=> 'cit_start_date',
		'citation_end'		=> 'cit_end_date',
		'fulltext_start'	=> 'ft_start_date',
		'fulltext_end'		=> 'ft_end_date',
		'urlbase'		=> 'journal_url',
	};
}

sub clean_data {
	my ($class, $record) = @_;
	my @errors;

	$record->{'title'} =~ s/\s*\(.+?\)$//;
	
	return 	$class->SUPER::clean_data($record);
}


sub global_resource_details {
	my ($class) = @_;
	return [ @{$class->SUPER::global_resource_details},
		 qw(
		 	url_base
		 )
	];
}

sub local_resource_details {
	my ($class) = @_;
	return [ @{$class->SUPER::local_resource_details},
		 qw(
		 	proxy_suffix
		 	proxy_prefix
		 )
	];
}

sub resource_details_help {
	return {
		$_[0]->SUPER::resource_details_help,
		'url_base' => "Base URL for faking searches.\nExample:\nhttp://infotrac.galegroup.com/itw/infomark/1/1/1/purl=rc11_CPI_0_",
	}
}

sub overridable_resource_details {
	return undef;
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
		next unless assert_ne($record->journal_url);

		my $url = $record->journal_url;

		# Workaround for GODOT weirdness!
		
#		$url = 'http://stalefish.lib.sfu.ca:7331/godot/redirector.cgi?_url_=' . $url;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		push @results, $result;
	}

	return \@results;
}

# Fakes a search like this:
# http://infotrac.galegroup.com/itw/infomark/1/1/1/purl=rc11_LT_0_sn_0891-6330_AND_vo_16_AND_iu_4

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

	defined($resource->url_base) or
		CUFTS::Exception::App->throw('No url_base defined for resource.');

	my @results;
	foreach my $record (@$records) {
		next unless assert_ne($record->issn);
		next unless assert_ne($request->volume) || assert_ne($request->issue);

		my $issn = $record->issn;
		substr($issn, 4, 0) = '-';

		my $url = $resource->url_base;
		$url .= "sn_$issn";

		assert_ne($request->volume) and
			$url .= '_AND_vo_' . $request->volume;

		assert_ne($request->issue) and
			$url .= '_AND_iu_' . $request->issue;

		# Workaround for GODOT weirdness!
		
#		$url = 'http://stalefish.lib.sfu.ca:7331/godot/redirector.cgi?_url_=' . $url;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		push @results, $result;
	}

	return \@results;
}


# Fakes a search like this:
# http://infotrac.galegroup.com/itw/infomark/1/1/1/purl=rc11_LT_0_sn_0891-6330_AND_vo_16_AND_iu_4

sub build_linkFulltext {
	my ($class, $records, $resource, $site, $request) = @_;
	
	defined($records) && scalar(@$records) > 0 or 
		return [];
	defined($resource) or 
		CUFTS::Exception::App->throw('No resource defined in build_linkTOC');
	defined($site) or 
		CUFTS::Exception::App->throw('No site defined in build_linkTOC');
	defined($request) or 
		CUFTS::Exception::App->throw('No request defined in build_linkTOC');

	defined($resource->url_base) or
		CUFTS::Exception::App->throw('No url_base defined for resource.');

	my @results;
	foreach my $record (@$records) {
		next unless assert_ne($record->issn);
		next unless assert_ne($request->volume) || assert_ne($request->issue);

		my $issn = $record->issn;
		substr($issn, 4, 0) = '-';

		my $url = $resource->url_base;

		$url .= 'ke_';

		$url .= "sn+$issn";

		assert_ne($request->volume) and
			$url .= '+AND+vo+' . $request->volume;

		assert_ne($request->issue) and
			$url .= '+AND+iu+' . $request->issue;
			
		assert_ne($request->spage) and
			$url .= '+AND+sp+' . $request->spage;

#		assert_ne($request->atitle) and
#			$url .= '_AND_ti_' . $request->atitle;


		my $result = new CUFTS::Result($url);
		$result->record($record);
		push @results, $result;
	}

	return \@results;
}


1;