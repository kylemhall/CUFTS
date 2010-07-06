# Finds and cleans up orphaned records that are no longer linked to anything

use Data::Dumper;

use lib qw(lib);

use CJDB::DB::DBI;
use CUFTS::DB::DBI;

use CUFTS::DB::Resources;
use CUFTS::DB::Journals;
use CUFTS::DB::JournalsAuth;

use CJDB::DB::Journals;
use CJDB::DB::Tags;

use Log::Log4perl qw(:easy);




Log::Log4perl->easy_init($INFO);
my $logger = Log::Log4perl->get_logger();

$logger->info('Looking for Journal Auth records that are not linked to anything.');

my $ja_iter = CUFTS::DB::JournalsAuth->retrieve_all();
my $remove_count = 0;
while ( my $ja = $ja_iter->next ) {
    my $ja_id = $ja->id;
    
    # Check for links to journals and local_journals
    
    my $count = CUFTS::DB::Journals->count_search({ journal_auth => $ja_id });
    next if $count;
    
    $count = CUFTS::DB::LocalJournals->count_search({ journal_auth => $ja_id });
    next if $count;
    
    $count = CJDB::DB::Journals->count_search({ journals_auth => $ja_id });
    next if $count;
    
    $count = CJDB::DB::Tags->count_search({ journals_auth => $ja_id });
    next if $count;

    $logger->info('Found: ', $ja->title, ' (', $ja_id, ')' );
    $remove_count++;
}

$logger->info('Total of ', $remove_count, ' unused journal authority records would be removed.');
