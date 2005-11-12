## CUFTS::Config
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

package CUFTS::Config;

use Exception::Class::DBI;
use CUFTS::BasicConfig;

use strict;

use vars qw(
	$CUFTS_DB_ATTR
	$CUFTS_DB_STRING
	@CUFTS_DB_CONNECT

	$CUFTS_LOG_DIR
	$CUFTS_TITLE_LIST_UPLOAD_DIR

	$CUFTS_MODULE_PREFIX

	$CUFTS_MAIL_REPLY_TO

	$CUFTS_REQUEST_LOG

	$CUFTS_TEMPLATE_DIR

	$CUFTS_SESSION_TYPE
	$CUFTS_SESSION_CONFIG
	$CUFTS_SESSION_DIR
	$CUFTS_INSTALLATION_NAME

	$CJDB_BASE_DIR

	$CJDB_DB_ATTR
	$CJDB_DB_STRING
	@CJDB_DB_CONNECT

	$CJDB_TEMPLATE_DIR
	$CJDB_SITE_TEMPLATE_DIR

	$CJDB_CSS_DIR
	$CJDB_SITE_CSS_DIR

	$CJDB_SITE_DATA_DIR
);



$CUFTS_DB_STRING = "dbi:Pg:dbname=${CUFTS_DB};host=localhost;port=5432";
$CUFTS_DB_ATTR = { 'PrintError' => 0, 'RaiseError' => 0, 'HandleError' => Exception::Class::DBI->handler() };
@CUFTS_DB_CONNECT = ($CUFTS_DB_STRING, $CUFTS_USER, $CUFTS_PASSWORD, $CUFTS_DB_ATTR);

$CUFTS_LOG_DIR = "${CUFTS_BASE_DIR}/logs";
$CUFTS_TITLE_LIST_UPLOAD_DIR = "${CUFTS_BASE_DIR}/uploads";

$CUFTS_MODULE_PREFIX = 'CUFTS::Resources::';

$CUFTS_MAIL_REPLY_TO = $CUFTS_MAIL_FROM;

$CUFTS_REQUEST_LOG = "${CUFTS_LOG_DIR}/requests_log";

$CUFTS_TEMPLATE_DIR = "${CUFTS_BASE_DIR}/templates";

$CUFTS_SESSION_TYPE = 'Apache::Session::File';
$CUFTS_SESSION_CONFIG = undef;
$CUFTS_SESSION_DIR = "${CUFTS::Config::CUFTS_BASE_DIR}/sessions";
$CUFTS_INSTALLATION_NAME = 'CUFTS';

$CJDB_DB_STRING = "dbi:Pg:dbname=${CJDB_DB};host=localhost;port=5432";
$CJDB_DB_ATTR = { 'PrintError' => 0, 'RaiseError' => 0, 'HandleError' => Exception::Class::DBI->handler() };
@CJDB_DB_CONNECT = ($CJDB_DB_STRING, $CJDB_USER, $CJDB_PASSWORD, $CJDB_DB_ATTR);

$CJDB_BASE_DIR = "$CUFTS_BASE_DIR/CJDB";

$CJDB_TEMPLATE_DIR = "${CJDB_BASE_DIR}/root";
$CJDB_SITE_TEMPLATE_DIR = "${CJDB_TEMPLATE_DIR}/sites";

$CJDB_CSS_DIR = "${CJDB_BASE_DIR}/root/static/css";
$CJDB_SITE_CSS_DIR = "${CJDB_CSS_DIR}/sites";

$CJDB_SITE_DATA_DIR = "${CUFTS_BASE_DIR}/data/sites";


1;
