## CUFTS::BasicConfig
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
##
## This file is normally written by the install script, but can be modified by
## hand if necessary later.
##
package CUFTS::Config;

use strict;

use vars qw(
	$CUFTS_BASE_DIR

	$CUFTS_DB
	$CUFTS_USER
	$CUFTS_PASSWORD

	$CUFTS_SMTP_HOST
	$CUFTS_MAIL_FROM

	$CJDB_DB
	$CJDB_USER
	$CJDB_PASSWORD

);

$CUFTS_BASE_DIR = '/usr/local/devel/CUFTS';

$CUFTS_DB = 'CUFTS_2';
$CUFTS_USER = 'tholbroo';
$CUFTS_PASSWORD = '';

$CUFTS_SMTP_HOST = 'localhost';
$CUFTS_MAIL_FROM = 'tholbroo@sfu.ca';

$CJDB_DB = 'CJDB_2';
$CJDB_USER = 'tholbroo';
$CJDB_PASSWORD = '';


1;

