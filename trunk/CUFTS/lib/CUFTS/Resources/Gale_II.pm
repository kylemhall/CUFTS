## CUFTS::Resources::Gale_II
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

package CUFTS::Resources::Gale_II;

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
		ft_start_date
		ft_end_date
		cit_start_date
		cit_end_date
	)];
}


## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'Journal Name' 		=> 'title',
		'ISSN' 			=> 'issn',
	};
}

sub clean_data {
	my ($class, $record) = @_;

	my ($ft_start_date, $ft_end_date) = ('0', '0');
	
	if (defined($record->{'___Index Start'}) && $record->{'___Index Start'} =~ /(\w{3})-(\d{2})/) {
		my $temp_date = get_date($1, $2);
		$record->{'cit_start_date'} = substr($temp_date, 0, 4) . '-' . substr($temp_date, 4, 2);
	}		
	if (defined($record->{'___Index End'}) && $record->{'___Index End'} =~ /(\w{3})-(\d{2})/) {
		my $temp_date = get_date($1, $2);
		$record->{'cit_end_date'} = substr($temp_date, 0, 4) . '-' . substr($temp_date, 4, 2);
	}		

	if (defined($record->{'___Full-text Start'}) && $record->{'___Full-text Start'} =~ /(\w{3})-(\d{2})/) {
		$ft_start_date = get_date($1, $2);
	}		
	if (defined($record->{'___Full-text End'}) && $record->{'___Full-text End'} =~ /(\w{3})-(\d{2})/) {
		$ft_end_date = get_date($1, $2);
	}		

	if (defined($record->{'___Image Start'}) && $record->{'___Image Start'} =~ /(\w{3})-(\d{2})/) {
		my $temp_date = get_date($1, $2);
		if (int($temp_date) < int($ft_start_date)) {
			$ft_start_date = $temp_date;
		}
	}		
	if (defined($record->{'___Image End'}) && $record->{'___Image Start'} =~ /(\w{3})-(\d{2})/) {
		my $temp_date = get_date($1, $2);
		if (int($temp_date) > int($ft_end_date)) {
			$ft_end_date = $temp_date;
		}
	}		

	defined($ft_start_date) && $ft_start_date ne '0' and
		$record->{'ft_start_date'} = substr($ft_start_date, 0, 4) . '-' . substr($ft_start_date, 4, 2);

	defined($ft_end_date) && $ft_end_date ne '0' and
		$record->{'ft_end_date'} = substr($ft_end_date, 0, 4) . '-' . substr($ft_end_date, 4, 2);

	$record->{'title'} =~ s/\s*\(.+?\)\s*$//g;

	return $class->SUPER::clean_data($record);

	sub get_date {
		my ($month, $year) = @_;
		
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

		if (int($year) > 20) {
			$year = "19$year";
		} else {
			$year = "20$year";
		}

		return sprintf("%04i%02i", $year, $month);
	}
}




## global_resource_details - Controls which details are displayed on the global
## resource pages
##

sub global_resource_details {
	my ($class) = @_;
	return [ @{$class->SUPER::global_resource_details},
		qw(resource_identifier
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
		qw(auth_name)
		];
}

## overridable_resource_details - Controls which of the *global* resource details
## are displayed on the *local* resource pages to possibly be overridden
## 
  
sub overridable_resource_details {
        my ($class) = @_;  
        return [ @{$class->SUPER::overridable_resource_details},
                 qw(
                        database_url
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
        my ($class) = @_;
          
        my $help_hash = $class->SUPER::resource_details_help;
        $help_hash->{'resource_identifier'} = 
                'Unique code defined by Gale for each database or resource.';
        $help_hash->{'url_base'} = 
                'Base URL for linking to resource.';
        $help_hash->{'auth_name'}  = 'Location ID assigned by Gale. Used in construction of URL.';
        return $help_hash;
}

## -------------------------------------------------------------------------------------------


## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##


sub build_linkDatabase {
	my ($class, $records, $resource, $site, $request) = @_;

        my $url_base = $resource->url_base or return [];
	
	my @results;

	foreach my $record (@$records) {
		
		my $url = $url_base;

	 	if ($resource->auth_name) {
			$url .= $resource->auth_name; 
		}

	 	if ($resource->resource_identifier) {
			$url .= '?db=' . $resource->resource_identifier; 
		}

		my $result = new CUFTS::Result($url);
		$result->record($record);
		
		push @results, $result;
	}

	return \@results;
}

sub can_getFulltext {
    return 0;
}

sub can_getJournal {
    return 0;
}
1;
