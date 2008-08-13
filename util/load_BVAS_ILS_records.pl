# Loads ERM records exported from SFU's III system

use lib 'lib';
use strict;

use Data::Dumper;

# use CUFTS::Schema;
use CUFTS::DB::ERMMain;
use Date::Manip;
use Unicode::String qw(utf8);
use CUFTS::CJDB::Util;

my $DEBUG = 0;

# load started at erm main id 7343
#                 costs id 22

# CONFIG STUFF, GET IDS FROM DATABASE

my $site_id = 1;
my $resource_type_id = 31;

my @month_names = qw( january february march april may june july august september october november december );
my $month_names_for_regex = join '|', @month_names;

my @field_names = qw(
    other_num
    bib_num
    order_num
    issn
    author
    title
    imprint
);

my @remainder_field_names = qw(
    paid_date
    invoice_date
    invoice_num
    amount_paid
    voucher
    copies
    sub_from
    sub_to
    note
);

# my $schema = CUFTS::Schema->connect( 'dbi:Pg:dbname=CUFTS3', 'tholbroo', '' );

# Skip first row
my $row = <>;

while ($row = <>) {
    chomp($row);
    my $record = parse_row($row);
    
    # print Dumper($record);
    
    # Pretty print record
    
    print "\n--------\n";
    print join( '   ', map { $record->{$_} } ( qw( order_num record_num other_num ) ) );
    print "\n";
    print $record->{title}, "  ", join( ', ', map { substr($_, 0, 4) . '-' . substr($_, 4, 4) } @{ $record->{issns} } );
    print "\n";
    
    # Find or create ERM Main record
    
    # my $erm = $schema->resultset('ERMMain')->search( { site => $site_id, 'local_bib' => $record->{record_num} } )->first();
    my $erm = CUFTS::DB::ERMMain->search( { site => $site_id, 'local_bib' => $record->{record_num} } )->first();
    if ( !defined($erm) ) {
        # $erm = $schema->resultset('ERMMain')->create( {
        $erm = CUFTS::DB::ERMMain->create( {
            site  => $site_id,
            key   => $record->{title},
            issn  => join( ', ', map { substr($_, 0, 4) . '-' . substr($_, 4, 4) } @{ $record->{issns} } ),
            local_bib => $record->{record_num},
            public => 0,
            public_list => 0,
            resource_type => $resource_type_id,
        } );
        $erm->main_name( $record->{title} );
        print "* CREATED ERM MAIN: ", $erm->id, "\n";
    }
    else {
        print "* FOUND ERM MAIN: ", $erm->id, "\n";
    }
    
    CUFTS::DB::DBI->dbi_commit;
    
    # foreach my $payment ( sort { $b->{end_date} cmp $a->{end_date} } @{ $record->{payments} } ) {
    #     print "   ", $payment->{invoice_date};
    #     print "   ", $payment->{start_date}, ' - ', $payment->{end_date};
    #     printf( "%8i", $payment->{voucher} );
    #     printf( "   \$ %9.2f  %3s \$ %9.2f", $payment->{amount_paid}, $payment->{currency_billed}, $payment->{amount_billed} );
    #     print "  ($payment->{references})" if exists $payment->{references};
    #     if ( $payment->{sub_from} =~ /\d/ || $payment->{sub_to} =~ /\d/ ) {
    #         print "   FROM: ", $payment->{sub_from}, ' - TO: ', $payment->{sub_to};
    #     }
    #     print "\n";
    #     
    #     my $cost = $schema->resultset('ERMCosts')->search( { erm_main => $erm->id, number => $payment->{voucher} } )->first();
    #     if ( !defined($cost) ) {
    #         $cost = $schema->resultset('ERMCosts')->create( {
    #             erm_main         => $erm->id,
    #             number           => $payment->{voucher},
    #             reference        => $payment->{references},
    #             date             => $payment->{invoice_date},
    #             period_start     => $payment->{start_date},
    #             period_end       => $payment->{end_date},
    #             paid             => $payment->{amount_paid},
    #             paid_currency    => 'USD',  # ???
    #             invoice          => $payment->{amount_billed},
    #             invoice_currency => $payment->{currency_billed},
    #         } );
    #         print "* CREATED COSTS: ", $cost->id, "\n";
    #     }
    #     else {
    #         print "* FOUND EXISTING COSTS: ", $cost->id, "\n";
    #     }
    #     
    # 
    # }
    # 
}



# Returns a record.  Yes, this is very ugly because of the bizarre III format.  See the END section for examples
sub parse_row {
    my ($row) = @_;
    # print $row;
    
    my %record;
    
    # $record{other_num}  = get_comma_field( \$row, 'other_num' );
    $record{record_num} = get_comma_field( \$row, 'record_num' );
    $record{order_num}  = get_comma_field( \$row, 'order_num' );

    my $issns = get_comma_field( \$row, 'issns' );
    $record{issns} = [ split /";"/, $issns ];

    $record{author}   = get_comma_field( \$row, 'author' );
    $record{title}    = utf8( get_comma_field( \$row, 'title' ) )->latin1;
    $record{imprint}  = get_comma_field( \$row, 'imprint' );
    $record{currency} = get_comma_field( \$row, 'currency' );

    $record{payments} = [];

    if ( $row !~ /^""/ ) {
        my %references;
        my @payments = split /";/, $row;
        foreach my $payment ( @payments ) {
            my %payment_record;

            # print($payment);
            
            $payment_record{paid_date}     = get_comma_field( \$payment, 'paid_date' );
            $payment_record{invoice_date}  = get_comma_field( \$payment, 'invoice_date' );
            $payment_record{invoice_num}   = get_comma_field( \$payment, 'invoice_num' );
            $payment_record{amount_paid}   = get_comma_field( \$payment, 'amount_paid' );
            $payment_record{voucher}       = get_comma_field( \$payment, 'voucher' );
            $payment_record{copies}        = get_comma_field( \$payment, 'copies' );
            $payment_record{sub_from}      = get_comma_field( \$payment, 'sub_from' );
            $payment_record{sub_to}        = get_comma_field( \$payment, 'sub_to' );

            $payment =~ s/^[",]\s*//;
            $payment =~ s/\s*[",]$//;
            $payment_record{note} = $payment;

            # Cleanup the invoice date
            
            my $inv_date_year = int( substr( $payment_record{invoice_date}, 0, 2 ) );
            substr( $payment_record{invoice_date}, 0, 2 ) = $inv_date_year + ( $inv_date_year > 60 ? 1900 : 2000 );


            # Parse the price and currency
            
            if ( $payment =~ / \\ ([a-zA-Z]{2,3}) \s* ([-.\d]+) $/xsm ) {
                $payment_record{currency_billed} = $1;
                $payment_record{amount_billed} = $2;
            }

            # Try to parse a date out
            
            # V. 19, JULY 95 - JUNE 96

            if ( $payment =~ m# ($month_names_for_regex) \s* (\d{2}) \s* - \s* ($month_names_for_regex) \s* (\d{2}) #ixsm ) {
                my $start_month = format_month( $1 );
                my $start_year  = int($2) + ( int($2) > 60 ? 1900 : 2000 );
                my $end_month   = format_month( $3 );
                my $end_year    = int($4) + ( int($4) > 60 ? 1900 : 2000 );
                my $end_day     = get_end_day( $end_month );
                
                $payment_record{start_date} = sprintf( "%04i-%02i-01",   $start_year, $start_month );
                $payment_record{end_date}   = sprintf( "%04i-%02i-%02i", $end_year,   $end_month, $end_day );
            } 
            
            # 1YR 010196 FRM 01-96
            elsif ( $payment =~ m# 1YR \s* \d* \s* FRM \s* (\d{2})-(\d{2}) #xsmi ) {
                my $month = $1;
                my $year = int($2) + ( int($2) > 60 ? 1900 : 2000 );
                $payment_record{start_date} = sprintf( "%04i-%02i-01", $year,     $month );
                $payment_record{end_date}   = sprintf( "%04i-%02i-01", $year + 1, $month );
            }

            # 74(01/99)-75(12/99)
            elsif ( $payment =~ m# \( (\d{2}) / (\d{2}) \) .* - .*  \( (\d{2}) / (\d{2}) \) #xsmi ) {
                my $start_month = $1;
                my $start_year = int($2) + ( int($2) > 60 ? 1900 : 2000 );
                my $end_month = $1;
                my $end_year = int($2) + ( int($2) > 60 ? 1900 : 2000 );
                $payment_record{start_date} = sprintf( "%04i-%02i-01", $start_year,   $start_month );
                $payment_record{end_date}   = sprintf( "%04i-%02i-01", $end_year + 1, $end_month );
            }
            
            # sept 1/98 - oct 31/99
            elsif ( $payment =~ m# (\w{3,4}) \s* (\d{1,2}) \s* / \s* (\d{2}) [-&] (\w{3,4}) \s* (\d{1,2}) \s* / \s* (\d{2}) #xsm ) {
                my $start_month = format_month( $1 );
                my $start_day   = $2;
                my $start_year  = int($3) + ( int($3) > 60 ? 1900 : 2000 );
                my $end_month   = format_month( $4 );
                my $end_day     = $5;
                my $end_year    = int($6) + ( int($6) > 60 ? 1900 : 2000 );
                
                $payment_record{start_date} = sprintf( "%04i-%02i-%02i", $start_year, $start_month, $start_day );
                $payment_record{end_date}   = sprintf( "%04i-%02i-%02i", $end_year,   $end_month, $end_day );
            } 
            # sep/09 - sep/00
            elsif ( $payment =~ m# (\w{3,4}) / (\d{2}) [-&] (\w{3,4}) / (\d{2}) #xsm ) {
                my $start_month = format_month( $1 );
                my $start_year  = int($2) + ( int($2) > 60 ? 1900 : 2000 );
                my $end_month   = format_month( $3 );
                my $end_year    = int($4) + ( int($4) > 60 ? 1900 : 2000 );
                
                $payment_record{start_date} = sprintf( "%04i-%02i-01", $start_year, $start_month );
                $payment_record{end_date}   = sprintf( "%04i-%02i-01", $end_year,   $end_month );
            }
            # 02/09 - 02/00
            elsif ( $payment =~ m# (\d{2}) / (\d{2}) [-&] (\d{2}) / (\d{2}) #xsm ) {
                my $start_month = $1;
                my $start_year  = int($2) + ( int($2) > 60 ? 1900 : 2000 );
                my $end_month   = $3;
                my $end_year    = int($4) + ( int($4) > 60 ? 1900 : 2000 );
                
                $payment_record{start_date} = sprintf( "%04i-%02i-01", $start_year, $start_month );
                $payment_record{end_date}   = sprintf( "%04i-%02i-01", $end_year,   $end_month );
            }
            # re:23423
            elsif ( $payment =~ / re: \s* (o?\d+) /ixsm ) {   # Try for a reference number
                $payment_record{references} = $1;
                
                if ( exists $references{ $payment_record{references} } ) {
                    $payment_record{start_date} = $references{ $payment_record{references} }->{start_date};
                    $payment_record{end_date}   = $references{ $payment_record{references} }->{end_date};                 
                }
                else {  # Default to previous record if it exists
                    if ( scalar(@{ $record{payments} }) ) {
                        $payment_record{start_date} = $record{payments}->[ $#{ $record{payments} } ]->{start_date};
                        $payment_record{end_date}   = $record{payments}->[ $#{ $record{payments} } ]->{end_date};
                    }
                }
                
            }
            # 1998
            elsif ( $payment =~ / ((?:19|20)\d{2}) /xsm ) {  # Last ditch for a single year
                $payment_record{start_date} = sprintf( "%04i-01-01", $1 );
                $payment_record{end_date}   = sprintf( "%04i-12-31", $1 );
            }
            else {
                $DEBUG && print STDERR "Can't parse: $payment\n";
            }


            # Validate all dates, or throw the row away.
            if ( ParseDate($payment_record{start_date}) && ParseDate($payment_record{end_date}) && $payment_record{invoice_date} ) {
                $references{ $payment_record{voucher} }->{start_date} = $payment_record{start_date};
                $references{ $payment_record{voucher} }->{end_date}   = $payment_record{end_date};

                push @{ $record{payments} }, \%payment_record;
            }
            else {
                print "* ERROR FOUND IN DATES, SKIPPING ROW\n";
            }
            
        }
    }

    return \%record;
}

sub get_comma_field {
    my ( $string, $fieldname ) = @_;
    if ( $$string =~ s/"(.*?)",//xsm ) {
        return $1;
    }
    die( "Error parsing $fieldname" );
}

sub format_month {
    my ( $month, $period ) = @_;

    defined($month) && $month ne ''
        or return undef;

    $month =~ /^\d+$/
        and return $month;

    if    ( $month =~ /^Jan/i )  { return 1 }
    elsif ( $month =~ /^Feb/i )  { return 2 }
    elsif ( $month =~ /^Mar/i )  { return 3 }
    elsif ( $month =~ /^Apr/i )  { return 4 }
    elsif ( $month =~ /^May/i )  { return 5 }
    elsif ( $month =~ /^Jun/i )  { return 6 }
    elsif ( $month =~ /^Jul/i )  { return 7 }
    elsif ( $month =~ /^Aug/i )  { return 8 }
    elsif ( $month =~ /^Sep/i )  { return 9 }
    elsif ( $month =~ /^Sept/i ) { return 9 }
    elsif ( $month =~ /^Oct/i )  { return 10 }
    elsif ( $month =~ /^Nov/i )  { return 11 }
    elsif ( $month =~ /^Dec/i )  { return 12 }
    elsif ( $month =~ /^Spr/i )  { return $period eq 'start' ? 1 : 6 }
    elsif ( $month =~ /^Sum/i )  { return $period eq 'start' ? 3 : 9 }
    elsif ( $month =~ /^Fal/i )  { return $period eq 'start' ? 6 : 12 }
    elsif ( $month =~ /^Aut/i )  { return $period eq 'start' ? 6 : 12 }
    elsif ( $month =~ /^Win/i )  { return $period eq 'start' ? 9 : 12 }
    else {
        CUFTS::Exception::App->throw("Unable to find month match: $month");
    }

}

sub get_end_day {
    my $month = int(shift);
    if ( $month > 0 && $month < 13 ) {
        return ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 )[$month - 1];
    }
    return 1;  # Safe default
}

__END__

"RECORD #(BIBLIO)","RECORD #(ORDER)","ISBN/ISSN","AUTHOR","TITLE","IMPRINT","CODE3","Paid Date","Invoice Date","Invoice Num","Amount Paid","Voucher Num","Copies","Sub From","Sub To","Note"
"b17605659","o1502438","01482076","","19th century music.","[Berkeley, Calif. : University of California Press, c1977-","j","96-01-10","95-12-07","9352330","95.65","3822","001","  -  -  ","  -  -  ","  V. 19, JULY 95 - JUNE 96\us69.00";"96-12-10","96-07-11","9363405","102.31","10274","001","  -  -  ","  -  -  ","  1YR FRM 07-96\us75.00";"97-11-18","97-10-29","9384334","117.85","15427","001","  -  -  ","  -  -  ","  1YR FRM 07-97\us82.00";"98-11-18","98-10-28","9408601","138.79","21041","001","  -  -  ","  -  -  ","  21(07/98)-23(06/99)\us89.00";"99-11-17","99-03-11","9428855","151.29","26713","001","  -  -  ","  -  -  ","  22(07/99)-24(06/00)\us95.00";"01-02-01","00-02-11","9456664","163.33","33420","001","  -  -  ","  -  -  ","  23(07/00)-24(06/01)\us98.00";"01-12-11","01-10-25","9477491","179.56","39079","001","  -  -  ","  -  -  ","  25(07/01)-25(06/02)\us105.00";"02-12-06","02-11-02","9492897","205.21","45382","001","  -  -  ","  -  -  ","  26(07/02)-26(06/03)\us120.00";"04-01-23","03-11-21","9514572","181.96","51996","001","  -  -  ","  -  -  ","  27(07/03)-27(06/04)\us130.00";"05-01-21","04-12-02","9545364","180.93","57359","001","  -  -  ","  -  -  ","  28(07/04)-28(06/05)!X62011\us139.00";"05-12-20","05-11-04","9564056","192.66","63512","001","  -  -  ","  -  -  ","  29(07/05)-29(0\us 149.00";"07-01-19","06-11-08","9582809","181.00","69646","001","  -  -  ","  -  -  ","30(07/06)-30(0\us 159.00";"07-12-13","07-10-26","9603638","172.97","75280","001","  -  -  ","  -  -  ","31(07/07)-31(0\us 170.00"
"b43386167","o3805608","16101928","","Acta acustica united with Acustica.","Stuttgart : S. Hirzel, 2001-","j","05-09-15","05-07-29","9558628","1172.11","61595","001","  -  -  ","  -  -  ","    v.91,2005";"05-12-15","05-10-13","0019498","-72.71","63302","001","  -  -  ","  -  -  ","    Re:9558628";"05-12-16","05-11-02","9564094","1232.19","63406","001","  -  -  ","  -  -  ","    92(01/06)-92(12/06)!Y214";"06-01-12","05-12-13","0009981","-78.26","63728","001","  -  -  ","  -  -  ","   Re:9564094 Rate adj ";"07-01-18","06-11-08","9582877","1380.29","69545","001","  -  -  ","  -  -  ","   93(01/07)-93(12/07)!A335";"07-02-08","07-01-13","0019420","-89.68","70339","001","  -  -  ","  -  -  ","  Re:9582877 VAT credit ";"08-01-15","07-11-09","9603801","1422.28","75555","001","  -  -  ","  -  -  ","94(01/08)-94(12/08)!C051";"08-05-07","08-02-13","0007582","-91.54","77626","001","  -  -  ","  -  -  ","Re:9603801 VAT credit "
"b16417276","o1219844","01924788","","Activities, adaptation & aging.","[New York, NY] : The Haworth Press, [c1980-","j","95-07-27","95-06-13","034738","35.38","1414","001","  -  -  ","  -  -  ","RATE ADJ RE V.20 INV 93248\us25.00";"95-08-02","95-07-13","S-74098","89.26","1441","001","  -  -  ","  -  -  ","RATE ADJ RE INV 9324884\us63.08";"96-01-16","95-11-29","9344849","311.51","4007","001","  -  -  ","  -  -  ","1YR 090196 FRM 09-96\us225.00";"96-06-26","96-06-13","S-48583","48.52","7402","001","  -  -  ","  -  -  ","RATE ADJ RE:9344849\us35.00";"96-12-05","96-07-11","9363370","354.67","10192","001","  -  -  ","  -  -  ","1YR FRM 09-97\us260.00";"97-06-24","97-06-13","S-39424","55.45","13277","001","  -  -  ","  -  -  ","RATE ADJ RE:9363370\us40.00";"97-11-18","97-10-29","9384300","431.15","15394","001","  -  -  ","  -  -  ","1YR FRM 09-98\us300.00";"98-01-07","97-11-13","S-49948","90.65","16098","001","  -  -  ","  -  -  ","RATE ADJ RE:9344849\us63.08";"98-06-30","98-06-13","S-79755","37.34","18788","001","  -  -  ","  -  -  ","RATE ADJ RE 9384300\us25.00";"98-10-01","98-09-13","S-47787","115.17","20353","001","  -  -  ","  -  -  ","V.22 RATE ADJ RE:9363370\us72.90";"98-11-18","98-10-28","9408567","506.83","21008","001","  -  -  ","  -  -  ","23(09/99)-24(08/00)\us325.00";"99-02-04","99-01-13","S-30136","132.89","22229","001","  -  -  ","  -  -  ","V.23 RATE ADJ \us84.11";"99-06-24","99-06-13","S-91832","40.03","24548","001","  -  -  ","  -  -  ","RE:9408567 RATE ADJ \us25.00";"99-11-17","99-03-11","9428822","557.37","26680","001","  -  -  ","  -  -  ","24(09/00)-25(08/01)\us350.00";"00-06-01","00-05-13","S-94676","120.46","29338","001","  -  -  ","  -  -  ","RATE ADJ RE:9408567\us75.23";"00-08-09","00-07-13","S-47688","56.05","30501","001","  -  -  ","  -  -  ","RE:9428822 RATE INC \us35.00";"01-01-17","00-11-02","9456630","600.40","33172","001","  -  -  ","  -  -  ","\us385.00";"01-01-19","00-11-02","9456630","-600.39","33174","001","  -  -  ","  -  -  ","FTP ERROR\us-385.00";"01-02-01","00-02-11","9456630","641.64","33386","001","  -  -  ","  -  -  ","25(09/01)-26(08/02)\us385.00";"01-06-19","01-06-13","S-65691","59.47","35933","001","  -  -  ","  -  -  ","RATE ADJ.RE:9456630\us35.00";"01-09-27","01-09-13","S-52981","167.90","37666","001","  -  -  ","  -  -  ","RE:9456630 END-USER FEE \us100.75";"01-12-11","01-10-25","9477457","969.65","39046","001","  -  -  ","  -  -  ","26(09/02)-27(08/03)\us567.00";"02-07-11","02-06-13","S-54850","162.91","42957","001","  -  -  ","  -  -  ","RE:9477457: END USER FEE \us97.75";"02-12-06","02-11-02","9492866","1136.82","45348","001","  -  -  ","  -  -  ","27(09/03)-28(08/04)\us664.75";"03-07-17","03-06-13","S-85650","29.33","49134","001","  -  -  ","  -  -  ","RE:9492866 RATE ADJ \us20.25";"04-01-23","03-11-21","9514544","713.84","51968","001","  -  -  ","  -  -  ","28(09/04)-29(08/05)\us510.00";"04-07-08","04-06-13","S-82908","36.22","55140","001","  -  -  ","  -  -  ","RE:9514544 RATE ADJ \us25.00";"04-08-12","04-07-13","S-35461","212.96","55605","001","  -  -  ","  -  -  ","RE:9514544 PRICE ADJ \us147.00";"05-01-21","04-12-02","9545318","696.36","57313","001","  -  -  ","  -  -  ","29(09/05)-30(08/06)!X61103\us535.00";"05-06-29","05-06-13","S-83567","19.72","60193","001","  -  -  ","  -  -  ","Re:9545318 rate adj \us15.00";"05-12-16","05-11-04","9564011","711.21","63419","001","  -  -  ","  -  -  ","30(09/06)-31(0\us 550.00";"06-09-07","06-07-13","S-68737","354.32","67609","001","  -  -  ","  -  -  ","Re:9564011 r\us 293.75";"07-01-19","06-11-08","9582773","668.23","69610","001","  -  -  ","  -  -  ","31(09/07)-32(0\us 587.00";"07-08-30","07-08-13","S-57649","71.64","73831","001","  -  -  ","  -  -  ","Re:9582773 r\us 63.00";"07-12-13","07-11-13","0033274","289.48","75231","001","  -  -  ","  -  -  ","Re:9582773 rate adj \us 284.50";"07-12-13","07-10-26","9603609","673.58","75251","001","  -  -  ","  -  -  ","32(09/08)-Thru 12/09 [see gen]\us 662.00"
"b16417276","o1335704","01924788","","Activities, adaptation & aging.","[New York, NY] : The Haworth Press, [c1980-","j","95-07-27","95-06-13","034738","35.38","1414","001","  -  -  ","  -  -  ","RATE ADJ RE V.20 INV 93248\us25.00";"95-08-02","95-07-13","S-74098","89.26","1441","001","  -  -  ","  -  -  ","RATE ADJ RE INV 9324884\us63.08";"97-01-15","97-01-02","9377395","360.42","10765","001","  -  -  ","  -  -  ","V.21,1996\us260.00";"97-01-15","97-01-02","9377395","360.41","10765","001","  -  -  ","  -  -  ","V.22,1997\us260.00";"97-03-27","97-03-13","S-82040","101.04","11968","001","  -  -  ","  -  -  ","1997 RATE ADJ RE:9377395\us72.90";"97-06-24","97-06-13","S-39424","55.45","13277","001","  -  -  ","  -  -  ","RATE ADJ RE:9377395\us40.00";"97-11-18","97-10-29","9384300","431.15","15394","001","  -  -  ","  -  -  ","1YR FRM 09-98\us300.00";"98-06-30","98-06-13","S-79755","37.34","18788","001","  -  -  ","  -  -  ","RATE ADJ RE 9384300\us25.00";"98-10-01","98-09-13","S-47787","115.17","20353","001","  -  -  ","  -  -  ","V.22 RATE ADJ RE:9377395\us72.90";"98-11-18","98-10-28","9408567","506.83","21008","001","  -  -  ","  -  -  ","23(09/99)-24(08/00)\us325.00";"99-06-24","99-06-13","S-91832","40.03","24548","001","  -  -  ","  -  -  ","RE:9408567 RATE ADJ \us25.00";"99-11-17","99-03-11","9428822","557.37","26680","001","  -  -  ","  -  -  ","24(09/00)-25(08/01)\us350.00";"00-06-01","00-05-13","S-94676","120.46","29338","001","  -  -  ","  -  -  ","RATE ADJ RE:9408567\us75.23";"00-08-09","00-07-13","S-47688","56.05","30501","001","  -  -  ","  -  -  ","RE:9428822 RATE INC \us35.00";"01-01-17","00-11-02","9456630","600.40","33172","001","  -  -  ","  -  -  ","\us385.00";"01-01-19","00-11-02","9456630","-600.39","33174","001","  -  -  ","  -  -  ","FTP ERROR\us-385.00";"01-02-01","00-02-11","9456630","641.64","33386","001","  -  -  ","  -  -  ","25(09/01)-26(08/02)\us385.00";"01-06-19","01-06-13","S-65691","59.47","35933","001","  -  -  ","  -  -  ","RATE ADJ RE:9456630\us35.00";"01-09-27","01-09-13","S-52981","167.90","37666","001","  -  -  ","  -  -  ","RE:9456630 END-USER FEE\us100.75";"01-12-11","01-10-25","9477457","969.65","39046","001","  -  -  ","  -  -  ","26(09/02)-27(08/03)\us567.00";"02-07-11","02-06-13","S-54850","162.91","42957","001","  -  -  ","  -  -  ","RE:9477457 END USER FEE \us97.75";"02-12-06","02-11-02","9492866","1136.82","45348","001","  -  -  ","  -  -  ","27(09/03)-28(08/04)\us664.75";"03-07-17","03-06-13","S-85650","29.33","49134","001","  -  -  ","  -  -  ","RE:9492866 RATE ADJ \us20.25";"04-01-23","03-11-21","9514544","713.84","51968","001","  -  -  ","  -  -  ","28(09/04)-29(08/05)\us510.00";"04-07-08","04-06-13","S-82908","36.22","55140","001","  -  -  ","  -  -  ","RE:9514544 RATE ADJ \us25.00";"04-08-12","04-07-13","S-35461","212.96","55605","001","  -  -  ","  -  -  ","RE:9514544 PRICE ADJ \us147.00";"05-01-21","04-12-02","9545318","696.36","57313","001","  -  -  ","  -  -  ","29(09/05)-30(08/06)!X61102\us535.00";"05-06-29","05-06-13","S-83567","19.72","60193","001","  -  -  ","  -  -  ","Re:9545318 rate adj \us15.00";"05-12-16","05-11-04","9564011","711.21","63419","001","  -  -  ","  -  -  ","30(09/06)-31(0\us 550.00";"06-09-07","06-07-13","S-68737","354.32","67609","001","  -  -  ","  -  -  ","Re:9564011 r\us 293.75";"07-01-19","06-11-08","9582773","668.23","69610","001","  -  -  ","  -  -  ","31(09/07)-32(0\us 587.00";"07-08-30","07-08-13","S-57649","71.64","73831","001","  -  -  ","  -  -  ","Re:9582773 r\us 63.00";"07-12-13","07-11-13","0033274","289.48","75231","001","  -  -  ","  -  -  ","Re:9582773 r\us 284.50";"07-12-13","07-10-26","9603609","673.58","75251","001","  -  -  ","  -  -  ","32(09/08) Thru 12/09 [see gen]\us 662.00"
"b16420135","o1219868","00018392","","Administrative science quarterly.","[Ithaca, N.Y., Graduate School of Business and Public Administration, Cornell University]","j","96-01-16","95-11-29","9344849","124.60","4007","001","  -  -  ","  -  -  ","  1YR 030196 FRM 03-96\us90.00";"96-12-05","96-07-11","9363370","122.77","10192","001","  -  -  ","  -  -  ","  1YR FRM 03-97\us90.00";"97-11-18","97-10-29","9384300","143.72","15394","001","  -  -  ","  -  -  ","  1YR FRM 03-98\us100.00";"98-11-18","98-10-28","9408567","155.95","21008","001","  -  -  ","  -  -  ","  43(03/99)-45(02/00)\us100.00";"99-11-17","99-03-11","9428822","207.02","26680","001","  -  -  ","  -  -  ","  44(03/00)-46(02/01)\us130.00";"01-01-17","00-11-02","9456630","202.73","33172","001","  -  -  ","  -  -  ","  VOL   0046  STARTS    03-0\us130.00";"01-01-19","00-11-02","9456630","-202.73","33174","001","  -  -  ","  -  -  ","  FTP ERROR\us-130.00";"01-02-01","00-02-11","9456630","216.65","33386","001","  -  -  ","  -  -  ","  V.46 [SEE GEN]\us130.00";"01-12-11","01-10-25","9477457","222.31","39046","001","  -  -  ","  -  -  ","  46(03/02)-47(02/03)\us130.00";"02-12-06","02-11-02","9492866","324.93","45348","001","  -  -  ","  -  -  ","  48(03/03)-49(02/04)\us190.00";"04-01-23","03-11-21","9514544","279.94","51968","001","  -  -  ","  -  -  ","  49(03/04)-50(02/05)\us200.00";"05-01-21","04-12-02","9545318","260.32","57313","001","  -  -  ","  -  -  ","  50(03/05)-51(02/06)!X60878\us200.00";"05-12-16","05-11-04","9564011","284.49","63419","001","  -  -  ","  -  -  ","  51(03/06)-52(0\us 220.00";"07-01-19","06-11-08","9582773","252.72","69610","001","  -  -  ","  -  -  "," 52(03/07)-52(0\us 222.00";"07-12-13","07-10-26","9603609","246.23","75251","001","  -  -  ","  -  -  ","53(03/08)-53(0\us 242.00"
"b16422818","o3549902","00018678","","Advances in applied probability.","[Sheffield, Eng.?, Applied Probability Trust]","j","05-01-21","04-12-02","9545318","316.29","57313","","  -  -  ","  -  -  ","37(01/05)-37(12/05)!X60924\us243.00";"05-03-30","05-03-12","S-82327","35.49","59090","","  -  -  ","  -  -  ","Re:9545318 rate inc \us27.00";"05-12-16","05-11-04","9564011","426.73","63419","001","  -  -  ","  -  -  ","38(01/06)-38(1\us 330.00";"07-01-19","06-11-08","9582773","375.67","69610","001","  -  -  ","  -  -  ","39(01/07)-39(1\us 330.00";"07-12-13","07-10-26","9603609","378.51","75251","001","  -  -  ","  -  -  ","40(01/08)-40(1\us 372.00"






Bad Data in example records:

v.29-30,09/03-\us 484.00
31(01/06)-31(1\us 332.00