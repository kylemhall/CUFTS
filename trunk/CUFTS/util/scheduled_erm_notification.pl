#!/usr/local/bin/perl

##
## This script checks all CUFTS sites for files that are
## marked for reloading.
##

use lib qw(lib);

use CUFTS::Exceptions;
use CUFTS::Config;
use CUFTS::DB::Resources;
use CUFTS::DB::Sites;
use CUFTS::DB::ERMMain;
use Net::SMTP;
use DateTime;
use DateTime::Format::Pg;
use Getopt::Long;

use strict;

my $now     = DateTime->now;
my $now_ymd = $now->ymd;

my %options;
GetOptions( \%options, 'site_key=s', 'site_id=i' );

my $site_iter;
if ( $options{site_id} ) {
    $site_iter = CUFTS::DB::Sites->search( id => int($options{site_id}) );
}
elsif ( $options{site_key} ) {
    $site_iter = CUFTS::DB::Sites->search( key => $options{site_key} );
}
else {
    $site_iter = CUFTS::DB::Sites->retrieve_all;
}


while (my $site = $site_iter->next) {
    print "Checking " . $site->name . "\n";
    my $site_notice = undef;

    my @resources = CUFTS::DB::ERMMain->search( 'site' => $site->id );
    foreach my $resource (@resources) {

        # Check alert expiries
        if ( $resource->alert_expiry ) {
            my $alert_expiry_date = DateTime::Format::Pg->parse_date( $resource->alert_expiry );
            if ( $alert_expiry_date->ymd le $now_ymd ) {
                $resource->alert(undef);
                $resource->alert_expiry(undef);
                $resource->update();
                $site_notice .= 'Expired alert notice for: ' . $resource->key . "\n";
            }
        }
        
        if ( $resource->renewal_notification && $resource->contract_end ) {
            my $rn_days = int($resource->renewal_notification);
            my $end     = DateTime::Format::Pg->parse_date( $resource->contract_end );

            my $rn_date = $end->add( days => -$rn_days );
            if ( $rn_date->ymd eq $now->ymd ) {
                $site_notice .= 'Renewal notification for: ' . $resource->key . '. Contract expires: ' . $end->ymd . "\n";
            }
        }

    }

    next if !defined($site_notice);

    if (!defined($site->email)) {
      warn('Notification scheduled for ' . $site->name . ', but email address is not defined');
      next;
    }
    
    my $email = $site->email;

    my $host = defined($CUFTS::Config::CUFTS_SMTP_HOST) ? $CUFTS::Config::CUFTS_SMTP_HOST : 'localhost';
    my $smtp = Net::SMTP->new($host);
    $smtp->mail($CUFTS::Config::CUFTS_MAIL_FROM);
    $smtp->to(split /\s*,\s*/, $email);
    $smtp->data();
    $smtp->datasend("To: $email\n");
    $smtp->datasend("Subject: CUFTS ERM Notifications\n");
    defined($CUFTS::Config::CUFTS_MAIL_REPLY_TO) and
      $smtp->datasend("Reply-To: ${CUFTS::Config::CUFTS_MAIL_REPLY_TO}\n");
    $smtp->datasend("\n");
    $smtp->datasend("CUFTS ERM Notifications for " . $now->ymd . "\n");
    $smtp->datasend($site_notice);
    $smtp->dataend();
    $smtp->quit();

    CUFTS::DB::DBI->dbi_commit();

    print 'Email sent to: ', $email, "\n";
    print $site_notice;
    print "Finished ", $site->name,  "\n";
}   

    


