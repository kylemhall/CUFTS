package SUSHI::Client;

use strict;

use CUFTS::Util::Simple;
use SUSHI::SUSHIInterfaces::SushiService::SushiServicePort;
use SUSHI::SUSHIElements::ReportRequest;
use Data::Dumper;
use DateTime;

# use Unicode::String qw(utf8);
use String::Util qw(hascontent);
use HTML::Entities;
use Encode;

# $site: CUFTS::Sites object
# $source: CUFTS::ERMCounterSources object
# $start: 'YYYY-MM-DD' string.
# $end: 'YYYY-MM-DD' string.
# $report: 'JR1' string

sub get_jr1_report {
    my ( $logger, $schema, $site, $source, $start, $end ) = @_;

    my $sushi = $source->erm_sushi;
    if ( !defined($sushi) ) {
        $logger->error( 'No SUSHI resource configured for this COUNTER Source: ', $source->name );
        return undef;
    }

    my $url = $sushi->service_url;
    if ( !defined($url) ) {
        $logger->error( 'No service URL defined for SUSHI source: ', $sushi->name );
        return undef;
    }

    my $service = SUSHI::SUSHIInterfaces::SushiService::SushiServicePort->new({
        proxy => $url,
        deserializer_args => { strict => 0 },
    });
    # $service->outputxml(1);

    if ( !$service ) {
        $logger->error( 'Failed to create SushiServicePort for SUSHI source: ', $sushi->name );
        return undef;
    }

    my $request_data = {
        Requestor => {
          ID    =>  $sushi->requestor,
          Name  =>  $site->name,
          Email =>  $site->email,
        },
        CustomerReference => {
          ID    =>  $source->reference,
          Name  =>  $site->name,
        },
        ReportDefinition => {
          Filters => {
            UsageDateRange => {
              Begin => $start,
              End   => $end,
            },
          },
        },
    };

    # warn(Dumper($request_data));

    my $request = SUSHI::SUSHIElements::ReportRequest->new( $request_data );
    $request->attr->set_Created( DateTime->now->iso8601 );
    $request->get_ReportDefinition->attr->set_Name( 'JR1' );
    $request->get_ReportDefinition->attr->set_Release( 3 );

    my $result = $service->GetReport($request);
    if ( !$result ) {
        $logger->error( "Unable to process 'GetReport': " . substr($result, 0, 1024 ) );
        return undef;
    }

    my $report = $result->get_Report;
    my $journal_report = $report->get_Report;

    if ( !$journal_report || !defined($journal_report->attr ) ) {
        $logger->error("Unable to retrieve report details through get_Report.");
        return undef;
    }

    # print "Vendor: ", $journal_report->get_Vendor->attr->get_Name, "\n";
    $logger->info( 'Retrieved report: ', $journal_report->attr->get_Title );

    my $report_items = $journal_report->get_Customer->get_ReportItems;

    my $journal_count = 0;
    foreach my $report_item ( @$report_items ) {

        my $title = $report_item->get_ItemName;
        $title = decode_entities(decode_entities($title)); # Necessary for Scholarly Stats, at least - decode &amp; in XML, then decode the result to real characters
        next if !hascontent($title);

        my $journal_data = { title => $title };

        my $identifiers = $report_item->get_ItemIdentifier;
        if ( ref($identifiers) ne 'ARRAY' ) {
            $identifiers = [ $identifiers ];
        }
        foreach my $identifier (@$identifiers) {
            next if !defined($identifier);
            next if !$identifier->can('get_Value');
            next if !$identifier->can('get_Type');

            my $type  = $identifier->get_Type . '';
            my $value = $identifier->get_Value . '';

            # Stringify, and remove dashes
            $value =~ s/^ (\d{4}) -? (\d{3}[\dxX]) $/$1$2/xsm;

            if ( $type eq 'Online_ISSN' ) {
                $journal_data->{e_issn} = $value;
            }
            elsif ( $type eq 'Print_ISSN' ) {
                $journal_data->{issn} = $value;
            }
        }

        # print(Dumper($journal_data));

        my $journal_rec = $schema->resultset('ERMCounterTitles')->find($journal_data);
        if ( !defined($journal_rec) ) {
            $logger->trace('No COUNTER titles record found, creating one.');

            # TODO: Try to find a matching journal auth first, then create a new Counter titles record?

            $journal_rec = $schema->resultset('ERMCounterTitles')->create($journal_data);
        }
        $journal_count++;

        my $item_performances = $report_item->get_ItemPerformance;
        foreach my $performance ( @{ $item_performances } ) {
            my $period = $performance->get_Period;

            my $instances = $performance->get_Instance;
            my $count;
            foreach my $instance (@$instances) {
                if ( $instance->get_MetricType eq 'ft_total' ) {
                    $count = $instance->get_Count->as_num;
                    last;
                }
            }

            my $start = $period->get_Begin->as_string;
            my $end   = $period->get_End->as_string;

            $start =~ s/^(\d{4}-\d{2}-\d{2}).*$/$1/;  # Fix dates that look like "1999-01-01-08:00"
            $end   =~ s/^(\d{4}-\d{2}-\d{2}).*$/$1/;

            next if !defined($count);

            # Verify dates and make sure it's not a multiple month summary record
            if ( $start =~ /^\d{4}-(\d{2})-\d{2}$/ ) {
                my $start_month = $1;
                if ( $end =~ /^\d{4}-(\d{2})-\d{2}$/ ) {
                    my $end_month = $1;
                    if ( int($start_month) != int($end_month) ) {
                        $logger->info('Skipping summary record - start and end months do not match.');
                        next;
                    }
                }
                else {
                    $logger->error( 'Bad end date: ', $end );
                    next;
                }
            }
            else {
                $logger->error( 'Bad start date: ', $start );
                next;
            }

            my $requests_data = {
                start_date     => $start,
                end_date       => $end,
                type           => lc($performance->get_Category->get_value),
                counter_title  => $journal_rec->id,
                counter_source => $source->id,
            };

            # Clear any existing data for this date range if it exists.
            $schema->resultset('ERMCounterCounts')->search($requests_data)->delete();

            $requests_data->{count} = int($count);

            # print Dumper($requests_data);

            # Add data to the statistics table.
            my $count_rec = $schema->resultset('ERMCounterCounts')->create($requests_data);

            # print join(' -- ', $requests_data->{start_date}, $requests_data->{end_date}, $requests_data->{count} ), "\n";
        }
    }

    $logger->info( "Loaded records for $journal_count journals." );

    return 1;
}

1;