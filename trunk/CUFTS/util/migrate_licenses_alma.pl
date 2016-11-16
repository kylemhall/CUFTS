use strict;
use lib qw(lib);

use Data::Dumper;
use XML::Compile::Schema;

use CUFTS::Config;
use CUFTS::Schema;
use CUFTS::Util::Simple;

my $xml_schema = XML::Compile::Schema->new('data/ERM_license.xsd');

my $db_schema = CUFTS::Config->get_schema();


my $licenses_rs = $db_schema->resultset('ERMLicense')->search({ site => 1 }, { order_by => 'id' });

$licenses_rs = $licenses_rs->search({}, { rows => 1 });

while ( my $license = $licenses_rs->next() ) {
  print $license->id . ' ' . $license->key, "\n";

  my $data = { # all of license_details, term_list, note_list,
    license_details => {
      ownered_entity => {
        created_by => "tholbroo",
      },

      license_code => $license->id,
      license_name => $license->key,
      license_status => "ACTIVE",
      # licensor_code => "example",
      start_date => "20160101",
      review_status => "ACCEPTED",

      # is a xs:string
      # Enum: ADDENDUM LICENSE NEGOTIATION
      type => "LICENSE",
    },

    # is a x0:note_list
    # is optional
    note_list =>
    { # sequence of note

      # is a x0:note
      # occurs 1 <= # <= unbounded times
      note =>
      [ { # all of ownered_entity, content

          # is a x0:ownered_entity
          # complex structure shown above
          ownered_entity => {},

          # is a xs:string
          content => "example", }, ], },
  };


  my @terms;

  if ( defined $license->allows_coursepacks ) {
    push @terms, create_term( 'COURSEPACKPRINT', $license->allows_coursepacks ? 'PERMITTED' : 'PROHIBITED' );
    push @terms, create_term( 'COURSEPACKELEC', $license->allows_coursepacks ? 'PERMITTED' : 'PROHIBITED' );
  }
  if ( defined $license->coursepack_notes ) {
    push @terms, create_term( 'COURSEPACKN', $license->coursepack_notes );
  }

  if ( defined $license->allows_distance_ed ) {
    push @terms, create_term( 'DISTANCE', $license->allows_distance_ed ? 'PERMITTED' : 'PROHIBITED' );
  }

  if ( defined $license->allows_ereserves ) {
    push @terms, create_term( 'COURSERES', $license->allows_ereserves ? 'PERMITTED' : 'PROHIBITED' );
  }
  if ( defined $license->ereserves_notes ) {
    push @terms, create_term( 'COURSERESNOTE', $license->ereserves_notes );
  }

  if ( defined $license->allows_ill ) {
    push @terms, create_term( 'ILLELEC', $license->allows_ill ? 'PERMITTED' : 'PROHIBITED' );
  }
  if ( defined $license->ill_notes ) {
    push @terms, create_term( 'ILLN', $license->ill_notes );
  }

  if ( defined $license->allows_remote_access ) {
    push @terms, create_term( 'REMOTE', $license->allows_remote_access ? 'PERMITTED' : 'PROHIBITED' );
  }
  if ( defined $license->allows_walkins ) {
    push @terms, create_term( 'WALKIN', $license->allows_walkins ? 'PERMITTED' : 'PROHIBITED' );
  }

  if ( defined $license->citation_requirements ) {
    push @terms, create_term( 'CITREQD', $license->citation_requirements );
  }



  $data->{term_list}->{term} = \@terms;

  my $doc    = XML::LibXML::Document->new('1.0', 'UTF-8');
  my $write  = $xml_schema->compile(WRITER => '{http://com/exlibris/urm/repository/migration/license/xmlbeans}license');
  my $xml    = $write->($doc, $data);

  $doc->setDocumentElement($xml);

  print $doc->toString(1);
}

sub create_term {
  my ( $term, $value ) = @_;
  return {
    term_code => $term,
    term_value => $value
  }
}