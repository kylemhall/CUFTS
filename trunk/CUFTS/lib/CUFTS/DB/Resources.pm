## CUFTS::DB::Resources
##
## Copyright Todd Holbrook, Simon Fraser University (2003)
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

package CUFTS::DB::Resources;

use strict;
use base 'CUFTS::DB::DBI';

use CUFTS::DB::ResourceDetails;
use CUFTS::DB::Resources_Services;
use CUFTS::DB::ResourceTypes;
use CUFTS::DB::LocalResources;

use Class::DBI::Relationship::HasDetails;

__PACKAGE__->table('resources');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw(
	id
	key
	name

	provider
	resource_type

	module

	resource_identifier
	database_url
	auth_name
	auth_passwd
	url_base
	proxy_suffix

	active
		
	title_list_scanned

	title_count

	created
	modified
));                                                                                                        
__PACKAGE__->columns(Essential => __PACKAGE__->columns);

__PACKAGE__->sequence('resources_id_seq');

__PACKAGE__->has_a('resource_type' => 'CUFTS::DB::ResourceTypes');

__PACKAGE__->has_many('services', ['CUFTS::DB::Resources_Services' => 'service'], 'resource');
__PACKAGE__->has_many('local_resources' => 'CUFTS::DB::LocalResources');

__PACKAGE__->has_details('details', 'CUFTS::DB::ResourceDetails' => 'resource');
__PACKAGE__->details_columns(qw/
	notes_for_local
	cjdb_note
/);

__PACKAGE__->add_trigger('before_delete' => \&delete_titles);

sub delete_titles {
	my ($self) = @_;
	
	return $self->do_module('delete_title_list', $self->id, 0);
}


sub record_count {
	my ($self, @other) = @_;
	
	my $module = $CUFTS::Config::CUFTS_MODULE_PREFIX . $self->module;

	eval "use $module";
	die if $@;
	
	if ($module->has_title_list) {
		my $titles_module = $module->global_db_module;
		return $titles_module->count_search('resource' => $self->id, @other);
	}

	return undef;
}


sub do_module {
	my ($self, $method, @args) = @_;
	
	my $module = $CUFTS::Config::CUFTS_MODULE_PREFIX . $self->module;
	
	eval "use $module";
	die($@) if $@;

	no strict 'refs';
	return $module->$method(@args);
}	
	


sub is_local_resource {
	return 0;
}


1;

