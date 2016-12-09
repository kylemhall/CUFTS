use strict;
use lib qw(lib);

use Data::Dumper;

use CUFTS::Config;
use CUFTS::Schema;
use CUFTS::Util::Simple;

use String::Util qw(hascontent);

my $db_schema = CUFTS::Config->get_schema();

my $licenses_rs = $db_schema->resultset('ERMLicense')->search({ site => 1 }, { order_by => 'id' });

#$licenses_rs = $licenses_rs->search({ id => { '-in' => [ 1006, 1270 ] }});

while ( my $row = <> ) {
  my ($bnum, $erm_id) = split /,/, $row;

  $bnum =~ s/[\s"]//g;
  $erm_id =~ s/[e\s"]//g;

  print $erm_id . ' ' . $bnum . "\n";

  my $erm = $db_schema->resultset('ERMMain')->find($erm_id);
  if ( !$erm ) {
    print "ERM record not found.\n";
    next;
  }

  if ( hascontent($erm->local_bib) ) {
    print "ERM has bnum already\n";
  }

  $erm->local_bib($bnum);
  $erm->update();

}