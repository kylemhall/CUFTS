## CUFTS::Resources::JSTOR
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

package CUFTS::Resources::JSTOR;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions qw(assert_ne);

use strict;

my $base_url = 'http://makealink.jstor.org/public-tools/GetURL?';

sub title_list_extra_requires {
	require Text::CSV;
	require HTML::Entities;
}

sub title_list_fields {
	return [qw(
		id
		title
		issn
		ft_start_date
		ft_end_date
		journal_url
		publisher
	)];
}

sub title_list_get_field_headings {
	return [qw(
		title
		issn
		___coverage
		___wall
		journal_url
		publisher
		ft_start_date
		ft_end_date
	)];
}

sub title_list_field_map {
	return {
		'title' => 'title',
		'issn' => 'issn',
		'journal_url' => 'journal_url',
		'publisher' => 'publisher',
		'ft_start_date' => 'ft_start_date',
		'ft_end_date' => 'ft_end_date',
	}
}

sub clean_data {
	my ($class, $record) = @_;

	my %month_mapping = (
		'20' => '01',
		'21' => '01',
		'22' => '03',
		'23' => '06',
		'24' => '09',
		'25' => '01',
		'26' => '02',
		'27' => '06',
		'28' => '07',
		'29' => '09',
		'30' => '10',
		'31' => '01',
		'32' => '03',
		'33' => '06',
		'34' => '09',
	);

	if (defined($record->{'ft_start_date'}) &&
	    $record->{'ft_start_date'} =~ /(\d{4})(\d{2})?(\d{2})?/) {
	    	my ($year, $month, $day) = ($1, $2, $3);
	    	$record->{'ft_start_date'} = $year;
	    	if (defined($month)) {
	    		if ($month > 12) {
	    			$month = $month_mapping{$month};
	    		}
	    		$record->{'ft_start_date'} .= "-${month}";
	    		defined($day) and
	    			$record->{'ft_start_date'} .= "-$day";
	    	}
	}

	if (defined($record->{'ft_end_date'}) &&
	    $record->{'ft_end_date'} =~ /(\d{4})(\d{2})?(\d{2})?/) {
	    	my ($year, $month, $day) = ($1, $2, $3);
	    	$record->{'ft_end_date'} = $year;
	    	if (defined($month)) {
	    		if ($month > 12) {
	    			$month = int($month_mapping{$month}) + 3;
	    			$month > 12 and $month = 12;
	    			$month = sprintf("%02i", $month);
	    		}
	    		$record->{'ft_end_date'} .= "-${month}";
	    		defined($day) and 
	    			$record->{'ft_end_date'} .= "-$day";
	    	}
	}

	$record->{'title'} = HTML::Entities::decode_entities($record->{'title'});

	return $class->SUPER::clean_data($record);

}	

sub title_list_split_row {
	my ($class, $row) = @_;
	
	my $csv = Text::CSV->new();
	$csv->parse($row) or
		CUFTS::Exception::App->throw('Error parsing CSV line: ' . $csv->error_input());
	
	my @fields = $csv->fields;
	return \@fields;
}



# -----------------------------------------------------------------------

sub can_getFulltext {
	my ($class, $request) = @_;
	
	return 0 unless assert_ne($request->spage);
	return $class->SUPER::can_getFulltext($request);
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
		next unless assert_ne($record->issn);

		my @params;
		defined($request->volume) and 
			push @params, 'volume=' . $request->volume;
		defined($request->issue) and 
			push @params, 'issue=' . $request->issue;
		if (defined($request->date)) {
			my $date = $request->date;
			$date =~ s/[^\d]//g;
			push @params, 'date=' . $date;
		}

		push @params, 'journal_title=' . $record->issn;
		push @params, 'page=' . $request->spage;	# Must be defined, or we wouldn't be here

		my $url = $base_url;
		$url .= join '&', @params;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


sub can_getTOC {
	my ($class, $request) = @_;
	
	return 0 unless assert_ne($request->volume) ||
		assert_ne($request->issue) ||
		assert_ne($request->date);
	
	return $class->SUPER::can_getTOC($request);
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

		my @params;
		assert_ne($request->volume) and 
			push @params, 'volume=' . $request->volume;
		assert_ne($request->issue) and 
			push @params, 'issue=' . $request->issue;

		!assert_ne($request->volume) && !assert_ne($request->issue) && assert_ne($request->date) and 
			push @params, 'date=' . $request->date;

		push @params, 'issn=' . $record->issn;

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
		next unless assert_ne($record->issn);

		my $result = new CUFTS::Result('http://www.jstor.org/journals/' . $record->issn . '.html');
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


1;