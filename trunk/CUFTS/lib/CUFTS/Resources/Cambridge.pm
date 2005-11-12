## CUFTS::Resources::Cambridge.pm
##
## Copyright Michelle Gauthier - Simon Fraser University (2004-02-09)
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

package CUFTS::Resources::Cambridge;

use base qw(CUFTS::Resources::Base::DOI CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions qw(assert_ne);

use URI::Escape;

use strict;

my $url_base = 'http://journals.cambridge.org/';

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
		iss_ft_start
		vol_ft_end
		iss_ft_end
		db_identifier
	)];
}


## title_list_field_map - Hash ref mapping fields from the raw title lists to
## internal field names
##

sub title_list_field_map {
	return {
		'Title' 		=> 'title',
		'ISSN' 			=> 'issn',
		'Electronic ISSN'	=> 'e_issn',
		'ft_start_date' 	=> 'ft_start_date',
		'ft_end_date'		=> 'ft_end_date',
		'Start volume'		=> 'vol_ft_start',
		'End volume'		=> 'vol_ft_end',
		'Start issue'		=> 'iss_ft_start',
		'End Issue'		=> 'iss_ft_end',
		'Mnemonic'		=> 'db_identifier'
	};
}

sub clean_data {
	my ($class, $record) = @_;
	
	foreach my $field (qw(vol_ft_start iss_ft_start vol_ft_end iss_ft_end)) {
		defined($record->{$field}) && int($record->{$field}) < 0 and
			delete $record->{$field};
	}
	
	return $class->SUPER::clean_data($record);
}


## preprocess_file - Join the multi-line style of title list into one title list
##                   write a temp file and open it.

sub preprocess_file {
	my ($class, $IN) = @_;

	use File::Temp;
	
	my ($fh, $filename) = File::Temp::tempfile();
	
	# Grab header row
	my $header = <$IN>;
	my @in_header = split /\t/, $header;
	my @out_header = @in_header;
	
	# Build column map
	
	my %columns;
	foreach my $x (0..$#in_header) {
		$columns{$in_header[$x]} = $x;
	}

	splice @out_header, $columns{'Year'}, 1, ('ft_start_date', 'ft_end_date');

	print $fh (join "\t", @out_header);
		
	# For now, assume the file has Mneumonic first, year second and vol(iss) third;

	my $current_id;
	my $first_vol;
	my $first_iss;
	my $first_year;
	my @prev_fields;
	
	while (my $line = <$IN>) {
		my @fields = split /\t/, $line;
		if ($current_id ne $fields[0]) {
			if (defined($current_id)) {
				$prev_fields[$columns{'Start volume'}] = $first_vol;
				$prev_fields[$columns{'Start issue'}] = $first_iss;
				splice @prev_fields, $columns{'Year'}, 0, $first_year;
				print $fh (join "\t", @prev_fields);
			}
			
			$current_id = $fields[$columns{'Mneumonic'}];
			$first_vol = $fields[$columns{'Start volume'}];
			$first_iss = $fields[$columns{'Start issue'}];
			$first_year = $fields[$columns{'Year'}];			

		}

		@prev_fields = @fields;
	}	

	splice @prev_fields, ($columns{'Year'} + 1), 0, $first_year;
	$prev_fields[$columns{'Start volume'}] = $first_vol;
	$prev_fields[$columns{'Start issue'}] = $first_iss;
	print $fh (join "\t", @prev_fields);


	close *$IN;
	seek *$fh, 0, 0;

	return $fh;
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

                my $url = $url_base . 'issue_' . &prepTitle($record->title);
		$url .= '/Vol' . sprintf("%02u", $request->volume) . 'No' . sprintf("%02u", $request->issue);

                my $result = new CUFTS::Result($url);
                $result->record($record);
        
                push @results, $result;
        }       
        
        return \@results;
}       

#### ROUTINE TO FORMAT JOURNAL TITLE FOR TABLE OF CONTENTS LINK
sub prepTitle {

	my $title = shift;
	
	my $preppedTitle = "";

	# remove spaces and upper case first letter of each word in title
	my @words = split(/\s/, $title);
	foreach my $word(@words){
		$preppedTitle .= ucfirst($word);
	}
	$preppedTitle =~  s/,//g;
	$preppedTitle = uri_escape($preppedTitle);
	
	return $preppedTitle;
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

                my $url = $url_base . 'jid_' . $record->db_identifier;

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
                  
		my $url = 'http://www.journals.cup.org/';

                my $result = new CUFTS::Result($url);
                $result->record($record);
           
                push @results, $result;
        }
  
        return \@results;
}


1;
