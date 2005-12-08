## CJDB::DB::DBI
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
##
## This file is part of CJDB.
##
## CJDB is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 2 of the License, or (at your option)
## any later version.
## 
## CJDB is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CJDB; if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CJDB::DB::DBI;

use base 'Class::DBI::Sweet';
use Exception::Class::DBI;
use CUFTS::Exceptions;
use CUFTS::Config;
use SQL::Abstract;
use Class::DBI::AbstractSearch;
use Class::DBI::Iterator;
use Class::DBI::Plugin::CountSearch;

use strict;

#
# Override the Class::DBI _croak() method to throw an exception instead of croaking
#

sub _croak {
	my ($self, $message, %info) = @_;

	CUFTS::Exception::DB->throw(message => $message, info => \%info);

	return; 
}

__PACKAGE__->set_db('Main', @CUFTS::Config::CJDB_DB_CONNECT);

##
## Experimental and untested
##

sub retrieve_all_limit {
	my ($class, $limit, $offset) = @_;
	
	my $sql = '';
	$sql .= 'LIMIT $limit' if defined($limit);
	$sql .= 'OFFSET $offset' if defined($offset);
	
	return $class->retrieve_from_sql($sql); 
}

__PACKAGE__->set_sql('now' => 'SELECT NOW()');

sub get_now {
	my ($class) = @_;

	my $sth;
	my $val = eval {
		$sth = $class->sql_now();
		$sth->execute;
		my @row = $sth->fetchrow_array;
		$sth->finish;
		$row[0];
	};
	if ($@) {
		return $class->_croak(
			"Can't select for $class using '$sth->{Statement}': $@",
			err => $@);
	}
	return $val;
}

# override default to avoid using Ima::DBI closure
sub db_Main {
    my $dbh;
    if ( $ENV{'MOD_PERL'} and !$Apache::ServerStarting ) {
        $dbh = Apache->request()->pnotes('dbh');
    }
    if ( !$dbh ) {
        # $config is my config object. replace with your own settings...
        $dbh = DBI->connect_cached(
            $CUFTS::Config::CJDB_DB_STRING,  $CUFTS::Config::CJDB_USER,
            $CUFTS::Config::CJDB_PASSWORD, $CUFTS::Config::CJDB_DB_ATTR
        );
        __PACKAGE__->_remember_handle('Main'); # so dbi_commit works
        if ( $ENV{'MOD_PERL'} and !$Apache::ServerStarting ) {
            Apache->request()->pnotes( 'dbh', $dbh );
        }
    }
    return $dbh;
}

1;
