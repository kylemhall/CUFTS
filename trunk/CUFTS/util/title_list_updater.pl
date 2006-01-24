#!/usr/local/bin/perl

##
## NOTE: This must be run from the base CUFTS directory using a relative
## path like: util/title_list_updater.pl or you will get module loading
## errors
##

##
## Copyright Todd Holbrook - Simon Fraser University (2003)
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

use lib qw(lib);

use CUFTS::Config;
use CUFTS::Exceptions;

use CUFTS::DB::Resources;
use CUFTS::DB::LocalResources;
use CUFTS::DB::Accounts;
use CUFTS::DB::ResourceTypes;
use CUFTS::DB::Sites;
use CUFTS::Util::Simple;

use CUFTS::Resources;

use Net::SMTP;
use MIME::Lite;

use strict;

my $title_list_dir = $CUFTS::Config::CUFTS_TITLE_LIST_UPLOAD_DIR;

opendir LIST_DIR, $title_list_dir or
	_error("Unable to open directory '$title_list_dir' for reading");

my @dat_files = grep /\.CUFTSdat$/, readdir LIST_DIR;

foreach my $dat_file_name (@dat_files) {
	open DAT_FILE, "$title_list_dir/$dat_file_name" or
		_error("Unable to open title list dat file '$dat_file_name' for reading");

	print "Reading dat file: $dat_file_name\n";
		
	my $resource_id = <DAT_FILE>;
	chomp $resource_id;
	$resource_id = int($resource_id);
	defined($resource_id) && $resource_id > 0 or
		_error("Unable to determine resource id from dat file '$dat_file_name'");

	my $account_id = <DAT_FILE>;
	chomp $account_id;
	$account_id = int($account_id);
	defined($account_id) && $account_id > 0 or
		_error("Unable to determine resource id from dat file '$dat_file_name'");
	
	close DAT_FILE;

	(my $title_list_file_name = $dat_file_name) =~ s/\.CUFTSdat$//;
	-e "$title_list_dir/$title_list_file_name" or
		_error("Title list file does not exist '$title_list_dir/$title_list_file_name'");

	my $resource = CUFTS::DB::Resources->retrieve($resource_id) or
		_error("Unable to retrieve resource '$resource_id' for title list updating");

	my $account = CUFTS::DB::Accounts->retrieve($account_id) or
		CUFTS::Exceptin::App->throw("Unable to retrieve account '$account_id' for title list updating");

	my $module = $resource->module or
		_error("Module not defined in resource '$resource_id'");
	
	$module = CUFTS::Resources::__module_name($module);

	eval "require $module";
	
	my $results = $module->load_global_title_list($resource, "$title_list_dir/$title_list_file_name");
	
	##
	## Email the person who submitted the job request.
	##

	my $email = $account->email;
	if ( not_empty_string($email) ) {
		my $host = defined($CUFTS::Config::CUFTS_SMTP_HOST) ? $CUFTS::Config::CUFTS_SMTP_HOST : 'localhost';
		my $smtp = Net::SMTP->new($host);
		if (defined($smtp)) {
    		$smtp->mail($CUFTS::Config::CUFTS_MAIL_FROM);
    		$smtp->to(split /\s*,\s*/, $email);
    		$smtp->data();
    		$smtp->datasend("To: $email\n");
    		$smtp->datasend("Subject: Updated global CUFTS list: " . $resource->name . "\n");
    		if ( defined($CUFTS::Config::CUFTS_MAIL_REPLY_TO) ) {
    			$smtp->datasend("Reply-To: ${CUFTS::Config::CUFTS_MAIL_REPLY_TO}\n");
    		}
    		$smtp->datasend("\n");
    		$smtp->datasend('Resource: ' . $resource->name . "\n");
    		$smtp->datasend('Processed: ' . $results->{'processed_count'} . "\n");
    		$smtp->datasend('Errors: ' . $results->{'error_count'} . "\n");
    		$smtp->datasend('New: ' . $results->{'new_count'} . "\n");
    		$smtp->datasend('Modified: ' . $results->{'modified_count'} . "\n");
    		$smtp->datasend('Deleted: ' . $results->{'deleted_count'} . "\n");
    		$smtp->datasend('Update Timestamp: ' . $results->{'timestamp'} . "\n\nErrors\n-------\n");
    		foreach my $error (@{$results->{'errors'}}) {
    			$smtp->datasend("$error\n");
    		}
    		$smtp->datasend("-------\n");
    		$smtp->dataend();
    		$smtp->quit();
    	}
    	else {
    	    warn('Unable to create Net::SMTP object.');
    	}
	}	

	##
	## Email all the sites who have this resource active.
	##

	my @local_resources = CUFTS::DB::LocalResources->search('active' => 't', 'resource' => $resource_id, 'auto_activate' => 'f');
	foreach my $local_resource  (@local_resources) {
		my $site = $local_resource->site;
		next if is_empty_string($site->email);

		my $local_resource_id = $local_resource->id;

		my $site_id = $site->id;
		my $host = defined($CUFTS::Config::CUFTS_SMTP_HOST) ? $CUFTS::Config::CUFTS_SMTP_HOST : 'localhost';
		my $msg = MIME::Lite->new(
			From    => $CUFTS::Config::CUFTS_MAIL_FROM,
			To      => $site->email,
			Subject => "CUFTS UPDATE ALERT: " . $resource->name,
			Type    => 'multipart/mixed',
		);
		
		if ( defined($msg) ) {

    		$msg->attach(
    			Type => 'TEXT',
    			Data => 'You have received this message because one of your CUFTS local resources has been updated. Please read the attached list to see if any of the titles you have enabled in CUFTS have changed. This may require re-enabling individual titles to ensure continued linking for your users. If you have any questions, please contact researcher-support@sfu.ca.' . "\n\n" .
    				'Resource: ' . $resource->name . "\n" .
    				'Processed: ' . $results->{'processed_count'} . "\n" .
    				'New: ' . $results->{'new_count'} . "\n" .
    				'Modified: ' . $results->{'modified_count'} . "\n" . 
    				'Deleted: ' . $results->{'deleted_count'} . "\n"
    		) or CUFTS::Exception::App->throw("Unable to attach text message to MIME::Lite object: $!");
		
    		my $filename = ($CUFTS::Config::CUFTS_TTILES_LOG_DIR || '/tmp/') . "new_titles_${resource_id}_" . substr($results->{'timestamp'}, 0, 19);
    		if (-e "$filename") {
    			$msg->attach(
    				Type => 'text/plain',
    				Path => $filename,
    				Filename => "new_titles_${resource_id}_" . substr($results->{'timestamp'}, 0, 19),
    				Disposition => 'attachment'
    			) or CUFTS::Exception::App->throw("Unable to attach new titles file to MIME::Lite object: $!");
    		}
		
    		$filename = ($CUFTS::Config::CUFTS_TTILES_LOG_DIR || '/tmp/') . "modified_titles_local_${local_resource_id}_${site_id}_" . substr($results->{'timestamp'}, 0, 19);
    		print "$filename\n";
    		if (-e "$filename") {
    			print "found\n";
    			$msg->attach(
    				Type => 'text/plain',
    				Path => $filename,
    				Filename => "modified_titles_local_${local_resource_id}_${site_id}_" . substr($results->{'timestamp'}, 0, 19),
    				Disposition => 'attachment'
    			) or CUFTS::Exception::App->throw("Unable to attach modified titles file to MIME::Lite object: $!");
    		}

    		$filename = ($CUFTS::Config::CUFTS_TTILES_LOG_DIR || '/tmp/') . "deleted_titles_local_${local_resource_id}_${site_id}_" . substr($results->{'timestamp'}, 0, 19);
    		print STDERR "$filename\n";
    		if (-e "$filename") {
    			print STDERR "found\n";
    			$msg->attach(
    				Type => 'text/plain',
    				Path => $filename,
    				Filename => "deleted_titles_local_${local_resource_id}_${site_id}_" . substr($results->{'timestamp'}, 0, 19),
    				Disposition => 'attachment'
    			) or CUFTS::Exception::App->throw("Unable to attach deleted titles file to MIME::Lite object: $!");
    		}
			
    		MIME::Lite->send('smtp', $host);
    		$msg->send;
    	}
    	else {
    	    warn("Unable to create MIME::Lite object: $!");
    	}
	}

	CUFTS::DB::DBI->dbi_commit;

	rename("$title_list_dir/$title_list_file_name", "$title_list_dir/completed/$title_list_file_name") or
		_error("Unable to move title list file to completed directory: $!: '$title_list_dir/$title_list_file_name $title_list_dir/completed/$title_list_file_name'");
	rename("$title_list_dir/$dat_file_name", "$title_list_dir/completed/$dat_file_name") or
		_error("Unable to move title list dat file to completed directory: $!: '$title_list_dir/$dat_file_name $title_list_dir/completed/$dat_file_name'");

	print 'Resource: ' . $resource->name . "\n";
	print 'Processed: ' . $results->{'processed_count'} . "\n";
	print 'Errors: ' . $results->{'error_count'} . "\n";
	print 'New: ' . $results->{'new_count'} . "\n";
	print 'Modified: ' . $results->{'modified_count'} . "\n";
	print 'Deleted: ' . $results->{'deleted_count'} . "\n";
	print 'Update Timestamp: ' . $results->{'timestamp'} . "\n\nErrors\n-------\n";
	foreach my $error (@{$results->{'errors'}}) {
		print "$error\n";
	}
	print "-------\n";
}


sub _error {
	my $msg = shift;
	
	CUFTS::Exception::App->throw($msg);
}

