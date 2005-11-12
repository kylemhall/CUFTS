## CUFTS::Resources::Ovid
##
## Copyright Michelle Gauthier - Simon Fraser University (2003-12-05)
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

package CUFTS::Resources::Ovid;

use base qw(CUFTS::Resources::Base::Journals);
use CUFTS::Exceptions qw(assert_ne);
use URI::Escape;
use strict;

## title_list_fields - Controls what fields get displayed and loaded from
## title lists.
##

sub title_list_fields {
	return [qw(
		id
		title
		issn
		
		ft_start_date
		ft_end_date
		vol_ft_start
		vol_ft_end
		iss_ft_start
		iss_ft_end
		
		publisher
	)];
}


## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'Title' 		=> 'title',
		'ISSN' 			=> 'issn',
		'Publisher'		=> 'publisher',
	};
}


sub clean_data {
	my ($class, $record) = @_;

	$record->{'title'} =~ s/^"(.+)"$/$1/;

	my $coverage = $record->{'___Coverage'};

	$coverage =~ s/^"(.+)"$/$1/;
	$coverage =~ s/\sVOL\.*\s?\w*\.?\,?\s?N?O?\.?\s?\w*\-?\w*//i;
	$coverage =~ s/[()]//g;
	
	if ($coverage =~ /^(\d{2})-(\d{2})$/) {
		$record->{'ft_start_date'} = format_date($1, undef, undef, 'start');
		$record->{'ft_end_date'} = format_date($2, undef, undef, 'end');
	} elsif ($coverage =~ /^(\d{1,2})\/(\d{2})-(\d{1,2})\/(\d{2})$/) {
		$record->{'ft_start_date'} = format_date($2, $1, undef, 'start');
		$record->{'ft_end_date'} = format_date($4, $3, undef, 'end');
	} elsif ($coverage =~ /^(\w+)\/?(\w*)\-?\w*\s*([A-Y]{0,3})[\/\- ]?[A-Y]{0,3}[\/\- ]?[A-Y]{0,3}\/?(\d{2,4})\-?/i) {

		my ($year, $month, $vol, $iss) = ($4, $3, $1, $2);

		$record->{'ft_start_date'} = format_date($year, $month, undef, 'start');
		
		$vol and 
			$record->{'vol_ft_start'} = get_first($vol);
		$iss and 
			$record->{'iss_ft_start'} = get_first($iss);
		
	} elsif ($coverage =~ /^(\w+)\/?(\w*)\-?\w*\s*([A-Y]{0,3})\s\d{1,2}\/(\d{1,4})\-?/i) {
	
		my ($year, $month, $vol, $iss) = ($4, $3, $1, $2);

		$record->{'ft_start_date'} = format_date($year, $month, undef, 'start');
		
		$vol and 
			$record->{'vol_ft_start'} = get_first($vol);
		$iss and 
			$record->{'iss_ft_start'} = get_first($iss);

	} elsif ($coverage =~ /^([A-Y]{3,})\/?(\d{2,4})\-/i) {

		my ($year, $month) = ($2, $1);

		$record->{'ft_start_date'} = format_date($year, $month, undef, 'start');

	} elsif ($coverage =~ /^(\d+)\/(\d+)\/(\d{2,4})/) {

		my ($year, $vol, $iss) = ($3, $1, $2);
		
		if (defined($year)) {
			$record->{'ft_start_date'} = format_date($year, undef, undef, 'start');
		}
	
		$vol and 
			$record->{'vol_ft_start'} = get_first($vol);
		$iss and 
			$record->{'iss_ft_start'} = get_first($iss);

	} elsif ($coverage =~ /^(\d+)\/(\d+)\s([A-Y]{3})\/(\d)\-/) {

		my ($year, $month, $vol, $iss) = ($4, $3, $1, $2);

		$record->{'ft_start_date'} = format_date($year, $month, undef, 'start');
		
		$vol and 
			$record->{'vol_ft_start'} = get_first($vol);
		$iss and 
			$record->{'iss_ft_start'} = get_first($iss);
	}
		
	# coverage ending

	if (!defined($record->{'ft_end_date'}) &&
	    $coverage =~ /\-(\d+)\/(\w+)*\s.*?([A-Y]{0,3})\/?(\d{2,4})$/i) {
		
		

		my ($year, $month, $vol, $iss) = ($4, $3, $1, $2);
		
		$record->{'ft_end_date'} = format_date($year, $month, undef, 'end');
		
		$vol and 
			$record->{'vol_ft_end'} = get_first($vol);
		$iss and 
			$record->{'iss_ft_end'} = get_first($iss);

	}		

	# Strip (#12345) from publishers

	$record->{'publisher'} =~ s/^"(.+)"$/$1/;
	$record->{'publisher'} =~ s/\s*\(#.+?\)$//;
	
	my @errors;
	
	# Skip records with no titles, they're not very useful

	if (!defined($record->{'title'}) || $record->{'title'} eq '') {
		push @errors, 'Title is empty, skipping record';
	}
	
	push @errors, @{$class->SUPER::clean_data($record)};
	
	return \@errors;

	sub format_date {
		my ($year, $month, $day, $period) = @_;

		my $date;
	
		$year = format_year($year, $period);
		defined($year) or return undef;
		$date = $year;
		
		$month = format_month($month, $period);
		if (defined($month)) {
			$date .= sprintf("-%02i", $month);
		}
			
		return $date;
	}

	sub format_year {
		my ($year, $period) = @_;
		length($year) == 4 and
			return $year;
			
		if (length($year) == 2) {
			if ($year > 10) {
				return "19$year";
			} else {
				return "20$year";
			} 
		}

		return undef;
	}

	sub format_month {
		my ($month, $period) = @_;
		
		defined($month) && $month ne '' or
			return undef;

		$month =~ /^\d+$/ and 
			return $month;

		if ($month =~ /^Jan/i) { return 1 }
		elsif ($month =~ /^Feb/i) { return 2 }
		elsif ($month =~ /^Mar/i) { return 3 }
		elsif ($month =~ /^Apr/i) { return 4 }
		elsif ($month =~ /^May/i) { return 5 }
		elsif ($month =~ /^Jun/i) { return 6 }
		elsif ($month =~ /^Jul/i) { return 7 }
		elsif ($month =~ /^Aug/i) { return 8 }
		elsif ($month =~ /^Sep/i) { return 9 }
		elsif ($month =~ /^Oct/i) { return 10 }
		elsif ($month =~ /^Nov/i) { return 11 }
		elsif ($month =~ /^Dec/i) { return 12 }
		elsif ($month =~ /^Spr/i) { return $period eq 'start' ? 1 : 6 }
		elsif ($month =~ /^Sum/i) { return $period eq 'start' ? 3 : 9 }
		elsif ($month =~ /^Fal/i) { return $period eq 'start' ? 6 : 12 }
		elsif ($month =~ /^Aut/i) { return $period eq 'start' ? 6 : 12 }
		elsif ($month =~ /^Win/i) { return $period eq 'start' ? 9 : 12 }
		else { CUFTS::Exception::App->throw("Unable to find month match in fulltext date: $month") }

	}

	sub get_first {
		$_[0] =~ s/\-.*//;
		return $_[0];
	}


}



## global_resource_details - Controls which details are displayed on the global
## resource pages
##

sub global_resource_details {
        my ($class) = @_;
        return [ #@{$class->SUPER::global_resource_details},
                 qw(
			resource_identifier
                        url_base
                 )
        ];
}
 
# overridable_resource_details - Controls which of the *global* resource details
## are displayed on the *local* resource pages to possibly be overridden
## 
  
sub overridable_resource_details {
        my ($class) = @_;   
        return [ @{$class->SUPER::overridable_resource_details},
                 qw(
                        database_url
                        url_base
                 )
       ];
}


sub local_resource_details {
        my ($class) = @_;
        return [ @{$class->SUPER::local_resource_details},
                 qw(
			url_base
                   )
        ];
}



## help_template - path to the help template for this resource relative to the
## general templates directory
##

sub help_template {
	return 'help/Ovid';
}


## resource_details_help - A hash ref containing the hoverover help for each of the
## local resource details
##

sub resource_details_help {
	my ($class) = @_;

	my $help_hash = $class->SUPER::resource_details_help;
	$help_hash->{'url_base'} = 'The address of your Ovid Web Gateway. Required for linking.';
	
	return $help_hash;
}

## -------------------------------------------------------------------------------------------

## can_get* - Control whether or not an attempt to create a link is built.  This is run
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits

sub can_getFulltext {
	my ($class, $request) = @_;
	
        return 0 unless ((assert_ne($request->volume) && assert_ne($request->issue) 
			&& assert_ne($request->spage)) || assert_ne($request->atitle));
	
	return $class->SUPER::can_getFulltext($request);
}

sub can_getTOC {
	my ($class, $request) = @_;
	
        return 0 unless ((assert_ne($request->volume) && assert_ne($request->issue)) 
			|| assert_ne($request->atitle));

	return 0 unless assert_ne($request->atitle);
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
		next unless assert_ne($resource->url_base);

		my $url = 'http://' . $resource->url_base .  '/ovidweb.cgi?T=JS&MODE=ovid&NEWS=n&PAGE=fulltext';
		$url .= '&D=' . $resource->resource_identifier . '&SEARCH=';

		if(assert_ne($record->issn) && assert_ne($request->volume)) {

                	$url .= substr($record->issn,0,4) . '-' . substr($record->issn,4,4) . '.IS+and+' 
				. $request->volume . '.VO+and+'
				. $request->issue . '.IP+and+' . $request->spage . '.PG';
		}
		else {
			$url .= uri_escape($request->atitle) . '.TI';
		}
			
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
		next unless assert_ne($resource->url_base); 

		my $url = 'http://' . $resource->url_base .  '/ovidweb.cgi?T=JS&MODE=ovid&NEWS=n&PAGE=TOC';
		$url .= '&D=' . $resource->resource_identifier . '&SEARCH=';

		if(assert_ne($record->issn) && assert_ne($request->volume)) {
                	$url .= substr($record->issn,0,4) . '-' . substr($record->issn,4,4) . '.IS+and+' 
				. $request->volume . '.VO+and+'
				. $request->issue . '.IP+and+' . $request->spage . '.PG';
		}
		else {
			$url .= uri_escape($request->atitle) . '.TI';
		}

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
		next unless assert_ne($resource->url_base); 

		my $url = 'http://' . $resource->url_base . '/ovidweb.cgi?T=JS';
		$url .= '&PAGE=toc&D=' . $resource->resource_identifier . '&SEARCH=';
		$url .= (assert_ne($record->issn)) ? substr($record->issn,0,4) . '-' . substr($record->issn,4,4) . '.IS' 
					: uri_escape($record->title) . '.JN';
					
		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}


1;
