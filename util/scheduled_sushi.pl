# Scheduled SUSHI downloads.  Finds all COUNTER sources with a run date of today and attempts to get the counter records through a SUSHI download.

use strict;
use lib 'lib';

use SUSHI::Client;
use CUFTS::Schema;
use CUFTS::Config;
use Getopt::Long;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

my $schema = CUFTS::Schema->connect( $CUFTS::Config::CUFTS_DB_STRING, $CUFTS::Config::CUFTS_USER, $CUFTS::Config::CUFTS_PASSWORD );

my $logger = Log::Log4perl->get_logger();
$logger->info('Starting scheduled SUSHI downloads.');

my %options;
GetOptions( \%options, 'site_key=s', 'site_id=i', 'cs_id=i' );

my $site_search =   $options{site_id}   ? { id => int($options{site_id}) }
                  : $options{site_key}  ? { key => $options{site_key} }
                  : {};
my $sites_rs = $schema->resultset('Sites')->search($site_search);

while ( my $site = $sites_rs->next ) {

    my $sources_search = $options{cs_id} ? { id => $options{cs_id} } : { site => $site->id, next_run_date => \'<= CURRENT_DATE' };

    my $sources_rs = $schema->resultset('ERMCounterSources')->search($sources_search);
    my $count = $sources_rs->count();
    if ( $count > 0 ) {

        $logger->info( "Found $count COUNTER sources for site: ", $site->name );

        while ( my $source = $sources_rs->next() ) {
            my ( $run_start_date, $interval_months ) = ( $source->run_start_date, $source->interval_months );

            if ( !defined($run_start_date) || !defined($interval_months) ) {
                $logger->error('SUSHI download scheduled without start/end dates. ' . 'Site: ' . $source->site->key . ' CounterSource: ' . $source->name );
                next;
            }

            my $start = $run_start_date->clone->set_day(1);
            my $end = $start->clone->add( months => $interval_months )->subtract( days => 1 );

            $logger->info( "Attempting to download report for ", $source->name );
            $logger->info( "Coverage period: ", $start->ymd, " to ", $end->ymd );

            my $result = SUSHI::Client::get_jr1_report( $logger, $schema, $site, $source, $start->ymd, $end->ymd );

            if ( $result ) {
                $source->run_start_date( $run_start_date->add( months => $interval_months ) );
                $source->next_run_date( $source->next_run_date->add( months => $interval_months ) );
                $source->update;
                $logger->info( 'Updated next run date to: ', $source->next_run_date->ymd );
            }
            else {
                $logger->info( 'Error processing SUSHI request, run date was not updated.' );
            }
            
            $logger->info( "Done processing ", $source->name );

        }

        $logger->info( 'Done with site: ', $site->name );

    }

}

