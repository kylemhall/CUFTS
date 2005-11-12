## CUFTS::Resources::IEEE.pm
##
## Copyright Michelle Gauthier - Simon Fraser University (2004-01-28)
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

package CUFTS::Resources::IEEE;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions qw(assert_ne);

use strict;

my $url_base = 'http://ieeexplore.ieee.org/';

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
		db_identifier
	)];
}


## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'title' 		=> 'title',
		'issn' 			=> 'issn',
		'ft_start_date' 	=> 'ft_start_date',
		'ft_end_date'		=> 'ft_end_date',
		'db_identifier'		=> 'db_identifier'
	};
}

## -------------------------------------------------------------------------------------------
                
## can_get* - Control whether or not an attempt to create a link is built.  This is run  
## before the database is searched for possible title matches, so catching requests without
## enough data, etc. early (here) cuts down on database hits
                                
                
sub can_getTOC {
        my ($class, $request) = @_;
                
        return 0 unless (assert_ne($request->volume) && assert_ne($request->issue));
        
        return $class->SUPER::can_getTOC($request);
}
                
# --------------------------------------------------------------------------------------------
	
## build_link* - Builds a link to a service.  Should return an array reference containing
## Result objects with urls and title list records (if applicable).
##


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
                next unless assert_ne($record->db_identifier);
                
		my $url = $url_base . 'servlet/opac?punumber=' . $record->db_identifier;
		$url .= '&isvol=' . $request->volume . '&isno=' . $request->issue;

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

		next unless assert_ne($record->db_identifier);

		my $result = new CUFTS::Result($url_base . 'servlet/opac?punumber=' . $record->db_identifier);
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
                
 		next unless assert_ne($resource->database_url);
  
                my $result = new CUFTS::Result($resource->database_url);
                $result->record($record);
           
                push @results, $result;
        }
  
        return \@results;
}


1;
