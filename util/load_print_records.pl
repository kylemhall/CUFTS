#!/usr/bin/perl

use lib qw(lib);

use CJDB::DB::DBI;
use CUFTS::DB::Sites;
use Getopt::Long;

use strict;

# Read command line arguments

my %options;
GetOptions(\%options, 'site_key=s', 'site_id=i', 'append', 'module=s');
my @files = @ARGV;

# Check for necessary arguments

if (!scalar(@files) || (!defined($options{'site_key'}) && !defined($options{'site_id'}))) {
	usage();
	exit;
}

# Get CUFTS site id

my $site = get_site();   
defined($site) or 
	die("Unable to retrieve site.");

my $site_id = $site->id;
my $site_key = $site->key;

# Create customized loader object
	
my $loader = load_module($site_key);
$loader->site_id($site_id);

# Clear existing records unless append is on

if (!$options{'append'}) {
	clear_site($site_id);
}

# Some loaders might need a first pass at the data to do thing like combine
# holdings records with bib records.  This returns a new list of processed
# files (probably "tmp" files now) or the original list if no pre-processing
# was done.

@files = $loader->pre_process(@files);

# Do a first pass at loading.  If we're merging on ISSN, we have to do two passes, one
# on records with multiple ISSNs, and then a second pass on records with only one
# ISSN.  This avoids having multiple single ISSN records that would have to be merged
# later.

my $batch = $loader->get_batch(@files);
$batch->strict_off;

while (my $record = $batch->next()) {
	$loader->skip_record($record) and
		next;
	
	if ($loader->merge_by_issns) {
		my @issns = $loader->get_issns($record);
		next unless scalar(@issns) > 1;
	}

	process_record($record);
}

# Second pass if we're merging

if ($loader->merge_by_issns) {
	$batch = $loader->get_batch(@files);
	$batch->strict_off;

	while (my $record = $batch->next()) {
	        $loader->skip_record($record) and
                        next;

		process_record($record);
        }
}
        
CJDB::DB::DBI->dbi_commit;

sub process_record {
	my ($record) = @_;

	my $journal = $loader->load_journal($record);
	defined($journal) or
		next;

	$loader->load_titles($record, $journal);

	$loader->load_MARC_subjects($record, $journal);

	$loader->load_LCC_subjects($record, $journal);
		
	$loader->load_associations($record, $journal);

	$loader->load_relations($record, $journal);

	$loader->load_link($record, $journal);
}	


sub load_module {
	my ($site_key) = @_;

	my $module_name = 'CUFTS::CJDB::Loader::MARC::';
	if ($options{'module'}) {
		$module_name .= $options{'module'};
	} elsif (defined($site_key)) {
		$module_name .= $site_key;
	} else {
		die("Unable to determine module name");
	}

	eval "require $module_name";
	if ($@) {
		die("Unable to require $module_name: $@");
	}
	
	my $module = $module_name->new;
	defined($module) or
		die("Failed to create new loading object from module: $module_name");
		
	return $module;
}



sub get_site {
	# Try site_id

	defined($options{'site_id'}) and
		return CUFTS::DB::Sites->retrieve($options{'site_id'});


	defined($options{'site_key'}) or
		return undef;

	# Try site_key

	my @sites = CUFTS::DB::Sites->search('key' => $options{'site_key'});
	
	scalar(@sites) == 1 or
		die('Could not get CUFTS site for key: ' . $options{'site_key'});
		
	return $sites[0];
}


sub clear_site {
	my ($site_id) = @_;

	defined($site_id) && $site_id ne '' && int($site_id) > 0 or
		die("Site id not properly defined in clear_site: $site_id");

	$site_id = int($site_id);

	# Make raw database calls to speed up this process.  Since we're deleting
	# everything for a site from all tables, we don't need Class::DBI triggers
	# being called.

	my $dbh = CJDB::DB::DBI->db_Main;
	foreach my $table (qw(associations journals links subjects titles issns relations)) {
		print "Deleting from table $table... ";
		$dbh->do("DELETE FROM $table WHERE site=$site_id");
		print "done\n";
	}

	return 1;
}	


sub usage {
	print <<EOF;
	
load_print_records - load print records from MARC files into CJDB

 site_key=XXX - CUFTS site key (example: BVAS)
 site_id=111  - CUFTS site id (example: 23)
 append       - do not delete data already loaded
 module       - force a particular loading module (default to site_key)
 
EOF
}
