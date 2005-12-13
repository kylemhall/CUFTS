#!/usr/local/bin/perl

##
## This script checks all CUFTS sites for files that are
## marked for reloading.
##

use lib qw(lib);

use CUFTS::Exceptions;
use CUFTS::Config;
use CUFTS::DB::Sites;
use CUFTS::DB::LocalResources;
use Net::SMTP;
use Date::Calc qw(Delta_Days Today Parse_Date);

use strict;

my $site_iter = CUFTS::DB::Sites->retrieve_all;
while (my $site = $site_iter->next) {
	print "Checking " . $site->name . "\n";
	my @resources = CUFTS::DB::LocalResources->search('site' => $site->id, 'active' => 't');

	foreach my $resource (@resources) {
		next unless defined($resource->erm_datescosts_contract_end) &&
		            defined($resource->erm_datescosts_renewal_notification);

		if ($resource->erm_datescosts_contract_end =~ /^(\d{4})-(\d{1,2})-(\d{1,2})$/) {
			my ($year, $month, $day) = ($1, $2, $3);
			next unless Delta_Days(Today(), $year, $month, $day) == $resource->erm_datescosts_renewal_notification;
		} else {
			next;
		}

		if (!defined($site->email)) {
			warn('Notification scheduled for ' . $site->name . ', but email address is not defined');
			next;
		}

		my $resource_name = $resource->name || $resource->erm_basic_name;
		!defined($resource_name) && defined($resource->resource) and
			$resource_name = $resource->resource->name;

		my $resource_vendor = $resource->provider || $resource->erm_basic_vendor;
		!defined($resource_vendor) && defined($resource->resource) and
			$resource_vendor = $resource->resource->provider;

		my $email = $site->email;

		my $host = defined($CUFTS::Config::CUFTS_SMTP_HOST) ? $CUFTS::Config::CUFTS_SMTP_HOST : 'localhost';
		my $smtp = Net::SMTP->new($host);
		$smtp->mail($CUFTS::Config::CUFTS_MAIL_FROM);
		$smtp->to(split /\s*,\s*/, $email);
		$smtp->data();
		$smtp->datasend("To: $email\n");
		$smtp->datasend('Subject: Notification for: ' . $resource_name . ' from ' . $resource_vendor . "\n");
		defined($CUFTS::Config::CUFTS_MAIL_REPLY_TO) and
			$smtp->datasend("Reply-To: ${CUFTS::Config::CUFTS_MAIL_REPLY_TO}\n");
		$smtp->datasend("\n");
		$smtp->datasend('Notification for: ' . $resource_name . ' from ' . $resource_vendor . "\n");
		$smtp->datasend('This resource is up for renewal on ' . $resource->erm_datescosts_contract_end . "\n");
		$smtp->dataend();
		$smtp->quit();



	}
	
	print "Finished ", $site->name,  "\n";
}	
	


