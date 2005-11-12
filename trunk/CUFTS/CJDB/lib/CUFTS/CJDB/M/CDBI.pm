package CUFTS::CJDB::M::CDBI;

use strict;
use base 'Catalyst::Base';

use CUFTS::DB::DBI;

use CUFTS::DB::Accounts;
use CUFTS::DB::Sites;

use CUFTS::DB::Resources;

use CUFTS::DB::Journals;
use CUFTS::DB::JournalsActive;

use CJDB::DB::DBI;

use CJDB::DB::Accounts;
use CJDB::DB::Associations;
use CJDB::DB::Journals;
use CJDB::DB::LCCSubjects;
use CJDB::DB::Links;
use CJDB::DB::Subjects;
use CJDB::DB::Titles;
use CJDB::DB::Tags;

=head1 NAME

CUFTS::CJDB::M::CDBI - CDBI CUFTS DB Loader

=head1 SYNOPSIS

Loads all the CUFTS DB modules.

=head1 DESCRIPTION

Loads all the CUFTS DB modules.

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;

