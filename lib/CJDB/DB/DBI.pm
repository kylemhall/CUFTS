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

use base 'Class::DBI';
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


##
## Try to implement a has_details() type system
##

__PACKAGE__->mk_classdata('__details');

sub has_details {
	my ($class, $accessor, $f_class, $f_key, $map_local, $args) = @_;
	return $class->_croak("has_details needs an accessor name") unless $accessor;
	return $class->_croak("has_details needs a foreign class")  unless $f_class;
	$class->can($accessor)
		and return $class->_carp("$accessor method already exists in $class\n");

	my @f_method = ();
	if (ref $f_class eq "ARRAY") {
		($f_class, @f_method) = @$f_class;
	}
	_require_class($f_class);

	if (ref $f_key eq "HASH") {    # didn't supply f_key, this is really $args
		$args  = $f_key;
		$f_key = "";
	}

	$f_key ||= $class->table_alias;

	if (ref $f_key eq "ARRAY") {
		return $class->_croak("Multiple foreign keys not implemented")
			if @$f_key > 1;
		$f_key = $f_key->[0];
	}

	$class->_extend_class_data(__details => $accessor => $f_class);

	{
		no strict 'refs';
		
		*{"$class\::$accessor"} = sub {
			my($self) = shift;
			if (ref($self->{_details}->{$accessor})) {
				return $self->{_details}->{$accessor};
			} else {
				$self->{_details}->{$accessor} = $f_class->new($f_key, $self->id());
				return $self->{_details}->{$accessor};
			}
		}

	}

	$class->add_trigger(before_update => _details_update($accessor));
	$class->add_trigger(before_delete => _details_delete($accessor));

	# Map details columns to local accessor methods

	if ($map_local) {
		foreach my $method ($f_class->columns) {
			next if !defined($method) || $method eq 'id';
			$class->can($method) and
				return $class->_carp("$method already exists in base object while mapping details methods");
			
			{
				no strict 'refs';
				*{"$class\::$method"} = sub {return shift->$accessor->$method(@_);};
			}
		}	
	}

	return $class;
}
                        	
sub details_columns {
	my $proto = shift;
	my $class = ref $proto || $proto;
	return undef unless defined($class->__details);
	return keys %{$class->__details};
}

sub has_details_column {
	my ($proto, $col) = @_;
	my $class = ref $proto || $proto;
	return 0 unless defined($class->__details);
	return exists $class->__details->{$col};
}	

sub details_module {
	my ($proto, $col) = @_;
	my $class = ref $proto || $proto;
	return undef unless defined($class->__details);
	return $class->__details->{$col};
}

sub _details_update {
	my $col = shift;
	return sub {shift->$col->_update};
}

sub _details_delete {
	my $col = shift;
	return sub {shift->$col->_delete};
}

sub set {
	my ($self) = shift;
	my $column_values = {@_};

	my @local_cols;
	while (my ($column, $value) = each %$column_values) {
		if (my $col = $self->find_column($column)) {
			push @local_cols, $column, $value;
		} else {
			my $set = 0;
			foreach my $details ($self->details_columns) {
				if (grep {$_ eq $column} $self->$details->columns) {
					if (defined($value)) {
						$self->$details->set($column, $value);
					} else {
						my $method = "delete_$column";
						$self->$details->$method;
					}
					$set = 1;
				}		
			}
			$set or
				$self->_croak('Unable to find matching column in object: ' . $column);
		}
	}
	scalar(@local_cols) and
		$self->SUPER::set(@local_cols);
}


sub _require_class {
	my $class = shift;

	# return quickly if class already exists
	no strict 'refs';
	return if exists ${"$class\::"}{ISA};
	return if eval "require $class";

	# Only ignore "Can't locate" errors from our eval require.
	# Other fatal errors (syntax etc) must be reported (as per base.pm).
	return if $@ =~ /^Can't locate .*? at \(eval /;
	chomp $@;
	Carp::croak($@);
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


1;
