#!/usr/bin/perl

use lib qw(lib);

use Data::Dumper;

use strict;

use CUFTS::DB::Accounts;
use CUFTS::DB::Sites;

use CUFTS::DB::Resources;

use CUFTS::DB::Journals;
use CUFTS::DB::JournalsActive;

use CUFTS::DB::Stats;

use CJDB::DB::Journals;

use MARC::File;
use MARC::File::USMARC;
use MARC::Record;

use CUFTS::CJDB::Util;
use CUFTS::CJDB::Loader::MARC::MARCStore;

use CUFTS::Resolve;

use Getopt::Long;

# Read command line arguments

my %options;
GetOptions(\%options, 'site_key=s', 'site_id=i', 'clear');
my @files = @ARGV;

# Check for necessary arguments

if ((!defined($options{'site_key'}) && !defined($options{'site_id'}))) {
	usage();
	exit;
}

# Get CUFTS site id

my $site = get_site();
defined($site) or
	die("Unable to load site.");

if ($options{'clear'}) {
	clear_site($site);
}

load_site_ejournals($site);

sub load_site_ejournals {
	my ($site) = @_;

	my $local_resources_iter = CUFTS::DB::LocalResources->search('active' => 'true', 'site' => $site->id);
#	my $local_resources_iter = CUFTS::DB::LocalResources->search('id' => 44, 'active' => 'true', 'site' => $site->id);

	while (my $local_resource = $local_resources_iter->next) {
		if (defined($local_resource->resource) and !$local_resource->resource->active) {
			next;
		}

		CUFTS::Resolve->overlay_global_resource_data($local_resource);
		next unless defined($local_resource->module);
		
		my $module = CUFTS::Resolve::__module_name($local_resource->module);
		CUFTS::Resolve->__require($module);

		my $journals_iter = CUFTS::DB::LocalJournals->search('resource' => $local_resource->id, 'active' => 'true');
		while (my $local_journal = $journals_iter->next) {

			$local_journal = $module->overlay_global_title_data($local_journal);
			my $journal_auth = $local_journal->journal_auth;
			unless (defined($journal_auth)) {
				print "Skipping journal '", $local_journal->title, "' due to missing journal_auth record.\n";
				next;
			}

			my $new_link = {
				'resource' => $local_resource->id,
				'rank' => $local_resource->rank,
				'site' => $site->id,
				'local_journal' => $local_journal->id,
			};
			
			if ($site->cjdb_display_db_name_only) {
				$new_link->{'name'} = $local_resource->name;
			} else {
				$new_link->{'name'} = $local_resource->name . ' - ' . $local_resource->provider;
			}
			my $ft_coverage = get_cufts_ft_coverage($local_journal);
			defined($ft_coverage) and
				$new_link->{'fulltext_coverage'} = $ft_coverage;
					
			my $cit_coverage = get_cufts_cit_coverage($local_journal);
			defined($cit_coverage) and
				$new_link->{'citation_coverage'} = $cit_coverage;

			if (defined($local_journal->embargo_days)) {
				$new_link->{'embargo'} = $local_journal->embargo_days . ' days';
			}

			if (defined($local_journal->embargo_months)) {
				$new_link->{'embargo'} = $local_journal->embargo_months . ' months';
			}


			# Skip if citations are turned off
				
			next if !defined($new_link->{'fulltext_coverage'}) && !$site->cjdb_show_citations;

			##
			## Create a request object and use the resolver to create journal/database level links
			##

			my $request = new CUFTS::Request;
			$request->title($local_journal->title);
			$request->genre('journal');
			$request->pid({});
			my @links;
			if ($module->can_getJournal($request) && $module->can('build_linkJournal')) {
					
				my $results = $module->build_linkJournal([$local_journal], $local_resource, $site, $request);
				foreach my $result (@$results) {
					$module->prepend_proxy($result, $local_resource, $site, $request);
					$new_link->{'URL'} = $result->url;
					$new_link->{'link_label'} = 'Link to journal';
					$new_link->{'_resource_name'} = $local_resource->name;
					my %temp_hash = %{$new_link};
					push @links, \%temp_hash;
				}

			} elsif ($module->can_getDatabase($request) && $module->can('build_linkDatabase')) {
				my $results = $module->build_linkDatabase([$local_journal], $local_resource, $site, $request);
				foreach my $result (@$results) {
					$module->prepend_proxy($result, $local_resource, $site, $request);
					$new_link->{'URL'} = $result->url;
					$new_link->{'link_label'} = 'Link to journal';
					$new_link->{'_resource_name'} = $local_resource->name;
					my %temp_hash = %{$new_link};
					push @links, \%temp_hash;
				}
			}
				
			if (scalar(@links) > 0) {
		
				my @CJDB_records = CJDB::DB::Journals->search(journals_auth => $journal_auth->id, site => $site->id);
	
				if (scalar(@CJDB_records) == 0) {
					my $record = get_MARC_data($site, $journal_auth);
					defined($record) and
						push @CJDB_records, $record;
				}

				if (scalar(@CJDB_records) == 0) {
					my $record = build_basic_record($site, $journal_auth);
					defined($record) and
						push @CJDB_records, $record;
				}

				foreach my $CJDB_record (@CJDB_records) {
					foreach my $link (@links) {
						# Add resource name as an association
							
						my %temp_link = %{$link};  # Grab a copy because we edit it, but it may be reused if there's multiple CJDB records
						
						CJDB::DB::Associations->find_or_create({
							'journal'            => $CJDB_record->id,
							'association'        => $temp_link{'_resource_name'},
							'search_association' => CUFTS::CJDB::Util::strip_title($temp_link{'_resource_name'}),
							'site'               => $site->id,
						});
					
						delete $temp_link{'_resource_name'};

						# Create links

						$temp_link{'journal'} = $CJDB_record->id;
						CJDB::DB::Links->create(\%temp_link);
					}
				}
			}
		}
	}
	
	CJDB::DB::DBI->dbi_commit;
}

sub get_cufts_ft_coverage {
	my ($local_journal) = @_;
	
	my $ft_coverage;
	
	if (defined($local_journal->ft_start_date) || defined($local_journal->ft_end_date)) {
		$ft_coverage = $local_journal->ft_start_date;
		if (defined($local_journal->vol_ft_start) || defined($local_journal->iss_ft_start)) {
			$ft_coverage .= ' (';
			defined($local_journal->vol_ft_start) and
				$ft_coverage .= 'v.' . $local_journal->vol_ft_start;
			if (defined($local_journal->iss_ft_start)) {
				defined($local_journal->vol_ft_start) and
					$ft_coverage .= ' ';
				$ft_coverage .= 'i.' . $local_journal->iss_ft_start;
			}
			$ft_coverage .= ')';
		}

		$ft_coverage .= ' - ';
		$ft_coverage .= $local_journal->ft_end_date;

		if (defined($local_journal->vol_ft_end) || defined($local_journal->iss_ft_end)) {
			$ft_coverage .= ' (';
			defined($local_journal->vol_ft_end) and
				$ft_coverage .= 'v.' . $local_journal->vol_ft_end;
			if (defined($local_journal->iss_ft_end)) {
				defined($local_journal->vol_ft_end) and
					$ft_coverage .= ' ';
				$ft_coverage .= 'i.' . $local_journal->iss_ft_end;
			}
			$ft_coverage .= ')';
		}
	}
	
	return $ft_coverage;
}
	
sub get_cufts_cit_coverage {
	my ($local_journal) = @_;
	
	my $cit_coverage;

	if (defined($local_journal->cit_start_date) || defined($local_journal->cit_end_date)) {
		$cit_coverage = $local_journal->cit_start_date;
		if (defined($local_journal->vol_cit_start) || defined($local_journal->iss_cit_start)) {
			$cit_coverage .= ' (';
			defined($local_journal->vol_cit_start) and
				$cit_coverage .= 'v.' . $local_journal->vol_cit_start;
			if (defined($local_journal->iss_cit_start)) {
				defined($local_journal->vol_cit_start) and
					$cit_coverage .= ' ';
				$cit_coverage .= 'i.' . $local_journal->iss_cit_start;
			}
			$cit_coverage .= ')';

		}
						
		$cit_coverage .= ' - ';
		$cit_coverage .= $local_journal->cit_end_date;
						
		if (defined($local_journal->vol_cit_end) || defined($local_journal->iss_cit_end)) {
			$cit_coverage .= ' (';
			defined($local_journal->vol_cit_end) and
				$cit_coverage .= 'v.' . $local_journal->vol_cit_end;
			if (defined($local_journal->iss_cit_end)) {
				defined($local_journal->vol_cit_end) and
					$cit_coverage .= ' ';
				$cit_coverage .= 'i.' . $local_journal->iss_cit_end;
			}
			$cit_coverage .= ')';
		}
	}
	
	return $cit_coverage;
}


sub strip_title {
	my ($string) = @_;
	
	return CUFTS::CJDB::Util::strip_title($string);
}


sub build_basic_record {
	my ($site, $journal_auth) = @_;
	
	my $record = {};
	

	my $title = $journal_auth->title;

	my $sort_title = $title;
	$sort_title = CUFTS::CJDB::Util::strip_articles($sort_title);

	my $stripped_sort_title = strip_title($sort_title);

	$record->{'title'} = $title;
	$record->{'sort_title'} = $sort_title;
	$record->{'stripped_sort_title'} = $stripped_sort_title;
	$record->{'site'} = $site->id;
	$record->{'journals_auth'} = $journal_auth->id;
	
#	warn(Dumper($journal_auth));

	my $journal = CJDB::DB::Journals->create($record);
	my $journal_id = $journal->id;
		
	CJDB::DB::Titles->create({
		'journal' => $journal_id,
		'site' => $site->id,
		'search_title' => $stripped_sort_title,
		'title' => $sort_title,
		'main' => 1,
	});
	
	my @issns = $journal_auth->issns;
	foreach my $issn (@issns) {
		CJDB::DB::ISSNs->find_or_create({
			'journal' => $journal_id,
			'issn' => $issn->issn,
			'site' => $site->id,
		});
	}
	
	return $journal;
}

sub get_MARC_data {
	my ($site, $journal_auth) = @_;

	defined($journal_auth->MARC) or
		return undef;
	my $record = MARC::File::USMARC::decode($journal_auth->MARC);


	my $loader = CUFTS::CJDB::Loader::MARC::MARCStore->new();
	$loader->site_id($site->id);

	my $journal = $loader->load_journal($record, $journal_auth->id);
	defined($journal) or 
		next;
	
	$loader->load_titles($record, $journal);
	
	$loader->load_MARC_subjects($record, $journal);

	$loader->load_LCC_subjects($record, $journal);

	$loader->load_associations($record, $journal);

	$loader->load_relations($record, $journal);

	CJDB::DB::DBI->dbi_commit;

	return $journal;
}

sub get_site {
	defined($options{'site_id'}) and
		return CUFTS::DB::Sites->retrieve(int($options{'site_id'}));

	my @sites = CUFTS::DB::Sites->search('key' => $options{'site_key'});
	
	scalar(@sites) == 1 or
		die('Could not get CUFTS site for key: ' . $options{'site_key'});
		
	return $sites[0];
}

sub clear_site {
	my ($site) = @_;

	defined($site) or 
		die("Site not defined in clear_site");

	# Make raw database calls to speed up this process.  Since we're deleting
	# everything for a site from all tables, we don't need Class::DBI triggers
	# being called.

	my $dbh = CJDB::DB::DBI->db_Main;
	foreach my $table (qw(associations journals links subjects titles)) {
		print "Deleting from table $table... ";
		$dbh->do("DELETE FROM $table WHERE site=" . $site->id);
		print "done\n";
	}

	return 1;
}	

sub usage {
	print <<EOF;
	
load_cufts_records - load CUFTS records from a CUFTS database into CJDB

 site_key=XXX - CUFTS site key (example: BVAS)
 site_id=111  - CUFTS site id (example: 23)
 clear        - Delete all existing records before loading 
EOF
}
