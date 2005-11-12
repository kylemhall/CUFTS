use Class::Accessor;
use Class::DBI;
use Class::DBI::AbstractSearch;
use SQL::Abstract;
use Exception::Class;
use Exception::Class::DBI;
use LWP::UserAgent ();
use Apache::DBI ();
use DBI ();
use URI::Escape;
use Apache::Session;
use Template;

use lib ('/home/tholbroo/CUFTS/MaintTool/lib', '/home/tholbroo/CUFTS/lib');
use CUFTS::MaintTool;

warn "Starting up...";

1;