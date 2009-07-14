package CUFTS::COUNTER;

use CUFTS::DB::ERMCounterCounts;
use CUFTS::DB::ERMCounterSources;
use CUFTS::DB::ERMCounterTitles;
use CUFTS::DB::JournalsAuth;

use Data::Dumper;
use Biblio::COUNTER;

use strict;

my $DEBUG = 1;

# Utility code for working with COUNTER records

sub load_report {
    my ( $source, $report_file ) = @_;

    my $report = Biblio::COUNTER->report($report_file)->process;
    die("Biblio::COUNTER was unable to process the report file.") if !$report->is_valid;

    # Try to find a specific report processor, they're different enough
    # reports that there's no real general case.
    
    if ( $report->name =~ /JR1/ ) {
        return load_report_jr1( $source, $report );
    }
    
    die("Could not find a report processor for: " . $report->name);
}


# $report should be a Biblio::COUNTER report
sub load_report_jr1 {
    my ( $source, $report ) = @_;
    
    if ( $DEBUG ) {
        warn("Publisher: "  . $report->publisher    . "\n");
        warn("Platform: "   . $report->platform     . "\n");
        warn("Date: "       . $report->date_run     . "\n");
    }
    
    my $periods = $report->periods;
    foreach my $journal ( $report->records ) {

        my $title = $journal->{name};
        $title = decode_entities(decode_entities($title)); # Necessary for Scholarly Stats, at least - decode &amp; in XML, then decode the result to real characters
        next if is_empty_string($title);

        # Stringify, and remove dashes
        my $issn  = "" . $journal->{print_issn};
        my $eissn = "" . $journal->{online_issn};
        $issn  = ($issn  =~ /(\d{4})-?(\d{3}[xX])/) ? "$1$2" : undef;
        $eissn = ($eissn =~ /(\d{4})-?(\d{3}[xX])/) ? "$1$2" : undef;
    
        my $journal_data = {
            title  => $title,
            issn   => $issn,
            e_issn => $eissn,
        };
        
        if ( $DEBUG ) {
            warn(Dumper($journal_data) . "\n");
        }
        
        my $journal_rec = $schema->resultset('ERMCounterTitles')->find($journal_data);
        if ( !$journal_rec ) {
            # Try to find a matching journal auth first, then create a new Counter titles record
            $journal_rec = $schema->resultset('ERMCounterTitles')->create($journal_data);
        }
        
        my $count  = $journal->{count};
        foreach my $period ( @$periods ) {
            while ( my ($metric, $num) = each %{ $count->{$period} } ) {
                if ( $DEBUG ) {
                    warn("* $metric: $num\n");
                }

                my $requests_data = {
                    start_date     => $period,
                    type           => $metric,
                    counter_title  => $journal_rec->id,
                    counter_source => $source->id,
                };
                
                $schema->resultset('ERMCounterCounts')->search($requests_data)->delete();
                $requests_data->{count} = $num;
                my $count_rec = $schema->resultset('ERMCounterCounts')->create($requests_data);
            }
        }

        
    }
    
}


1;
