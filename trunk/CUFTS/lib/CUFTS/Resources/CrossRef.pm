## CUFTS::Resources::CrossRef
##
## Copyright Todd Holbrook - Simon Fraser University (2004)
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

package CUFTS::Resources::CrossRef;

use base qw(CUFTS::Resources);

use CUFTS::Exceptions qw(assert_ne);

sub has_title_list { return 0; }
sub local_resource_details { return ['auth_name', 'auth_passwd'] }
sub help_template { return undef }
sub global_resource_details { return ['auth_name', 'auth_passwd'] }
sub overridable_resource_details { return ['auth_name', 'auth_passwd'] }
sub resource_details_help {
	return {
		'auth_name' => 'Login name provided by CrossRef.',
		'auth_passwd' => 'Password provided by CrossRef.',
	}
}

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;

sub get_records {
	my ($class, $resource, $site, $request) = @_;
	
	assert_ne($resource->auth_name) or
		CUFTS::Exception::App->throw('No auth_name defined for CrossRef lookups.');
	assert_ne($resource->auth_passwd) or
		CUFTS::Exception::App->throw('No auth_passwd defined for CrossRef lookups.');
                       

	my $year = '';
	defined($request->date) && $request->date =~ /^(\d{4})/ and
		$year = $1;

	my ($qdata, $qtype);
	
	if (assert_ne($request->issn) || assert_ne($request->title)) {
		$qdata = join('|',(
			$request->issn || '',
			$request->title || '',
			$request->aulast || '',
			$request->volume || '',
			$request->issue || '',
			$request->spage || '',
			$year,
			'',
			time,
			$request->doi || '',
			)
		);
		$qtype = 'q';
	} elsif (assert_ne($request->doi)) {
		$qdata = $request->doi;
		$qtype = 'd';
	} else {
		return undef;
	}
		
	# Lookup meta-data

	my $start_time = time;

	my $ua = LWP::UserAgent->new('timeout' => 20);
	my $response = $ua->request(POST 'http://doi.crossref.org/servlet/query', [
		'type' => $qtype,
		'usr'  => $resource->auth_name,
		'pwd'  => $resource->auth_passwd,
		'area' => 'live',
		'format' => 'piped',
		'qdata' => $qdata,
	]);

	$response->is_success or return undef;
	
	my $returned_data = $response->content;
	$returned_data =~ s/^[\s\n]*//;
	$returned_data =~ s/[\s\n]*$//;

	print STDERR "CrossRef returned (" . (time-$start_time) . "s): $returned_data\n";

	my (
		$issn,
		$title,
		$aulast,
		$volume,
		$issue,
		$start_page,
		$crossref_year,
		$type,
		$key,
		$doi,
	) = split /\|/, $returned_data;

	!defined($request->doi) && assert_ne($doi) and
		$request->doi($doi);

	!defined($request->aulast) && assert_ne($aulast) and
		$request->aulast($aulast);

	!defined($request->title) && assert_ne($title) and
		$request->title($title);

	if (!defined($request->issn) && assert_ne($issn)) {
		$issn =~ /^([\dxX]{8})/ and
			$request->issn($1);
	}

	!defined($request->volume) && assert_ne($volume) and
		$request->volume($volume);

	!defined($request->issue) && assert_ne($issue) and
		$request->issue($issue);

	!defined($request->spage) && assert_ne($start_page) and
		$request->spage($start_page);
	
	return undef;
}

sub can_getMetadata {
	my ($class, $request) = @_;
	
	assert_ne($request->issn) || assert_ne($request->eissn) and
		return 1;
		
	assert_ne($request->title) and
		return 1;
		
	assert_ne($request->doi) and
		return 1;
		
	return 0;
}

1;
