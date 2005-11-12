## CUFTS::Resources::Highwire.pm
##
## Copyright Michelle Gauthier - Simon Fraser University (2003)
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

package CUFTS::Resources::Highwire;

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
                journal_url
                db_identifier
                publisher
	)];
}


## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'Journal Name' 			=> 'title',
		'What is the print ISSN number?'	=> 'issn',
                'What is the online ISSN number?'	=> 'e_issn',
                'What is the main URL for the journal site?'		=> 'journal_url',
                'Who is the publisher?' 	=> 'publisher',
                'db_identifier' => 'db_identifier',
                'ft_start_date' => 'ft_start_date',
	};
}


sub clean_data {
	my ($class, $record) = @_;
	
	defined($record->{'issn'}) && $record->{'issn'} eq 'Unknown' and
		delete($record->{'issn'});

	defined($record->{'e_issn'}) && $record->{'e_issn'} eq 'Unknown' and
		delete($record->{'e_issn'});

	if (defined($record->{'___What is the range of content online?'})) {
		my $dates = get_dates($record->{'___What is the range of content online?'});

		if (defined($dates->{'HTML'}) && (!defined($dates->{'PDF'}) || int($dates->{'PDF'}) > int($dates->{'HTML'}))) {
			$record->{'ft_start_date'} = $dates->{'HTML'};
			$record->{'db_identifier'} = 'HTML';
		} elsif (defined($dates->{'PDF'})) {
			$record->{'ft_start_date'} = $dates->{'PDF'};
			$record->{'db_identifier'} = 'PDF';
		}
	}
			
	$class->SUPER::clean_data($record);

	sub get_dates {
		my ($string) = @_;
		
		my %dates;
		
		while ($string =~ /(html|pdf)\s*fulltext\sdate\:?\s*([a-z]{3})\s*(\d{2}),?\s*(\d{4})/ig) {
			my ($identifier, $month, $day, $year) = (uc($1), $2, $3, $4);
			
			if ($month =~ /^Jan/i) { $month = 1 }
			elsif ($month =~ /^Feb/i) { $month = 2 }
			elsif ($month =~ /^Mar/i) { $month = 3 }
			elsif ($month =~ /^Apr/i) { $month = 4 }
			elsif ($month =~ /^May/i) { $month = 5 }
			elsif ($month =~ /^Jun/i) { $month = 6 }
			elsif ($month =~ /^Jul/i) { $month = 7 }
			elsif ($month =~ /^Aug/i) { $month = 8 }
			elsif ($month =~ /^Sep/i) { $month = 9 }
			elsif ($month =~ /^Oct/i) { $month = 10 }
			elsif ($month =~ /^Nov/i) { $month = 11 }
			elsif ($month =~ /^Dec/i) { $month = 12 }
			else { CUFTS::Exception::App->throw("Unable to find month match in fulltext date: $month") }
			
			$dates{$identifier} = sprintf("%04i%02i%02i", $year, $month, $day);
		}
		return \%dates;
	}
}

		
## -------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

sub can_getFulltext {
	my ($class, $request) = @_;
	
	return 0 unless (assert_ne($request->spage) && assert_ne($request->volume) && assert_ne($request->issue));
	return $class->SUPER::can_getFulltext($request);
}

# --------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits
        
sub can_getTOC {
       my ($class, $request) = @_;
                   
       return 0 unless (assert_ne($request->issue) && assert_ne($request->volume));
       return $class->SUPER::can_getTOC($request);
}
                        
# --------------------------------------------------------------------------------------------
        

## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##

# fulltext linking works on some but not all highwire journals so comment out for now
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
		next unless assert_ne($record->db_identifier);
             
                my $dir = ($record->db_identifier eq 'HTML') ? 'content/full' : 'reprint'; 
		my $url = $record->journal_url . '/cgi/' . $dir . '/';
                $url .= $request->volume . '/' . $request->issue . '/' . $request->spage;

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


# TOC linking works on some but not all highwire journals so comment out for now
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

                my $url = $record->journal_url . '/content/vol' . $request->volume;
                $url .= '/issue' . $request->issue . '/index.shtml';

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
		next unless assert_ne($record->journal_url);

		my $result = new CUFTS::Result($record->journal_url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


1;
