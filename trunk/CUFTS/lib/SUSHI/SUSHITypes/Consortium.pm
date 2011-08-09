package SUSHI::SUSHITypes::Consortium;
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(0);

sub get_xmlns { 'http://www.niso.org/schemas/counter' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %Code_of :ATTR(:get<Code>);
my %WellKnownName_of :ATTR(:get<WellKnownName>);

__PACKAGE__->_factory(
    [ qw(        Code
        WellKnownName

    ) ],
    {
        'Code' => \%Code_of,
        'WellKnownName' => \%WellKnownName_of,
    },
    {
        'Code' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'WellKnownName' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
    },
    {

        'Code' => 'Code',
        'WellKnownName' => 'WellKnownName',
    }
);

} # end BLOCK







1;


=pod

=head1 NAME

SUSHI::SUSHITypes::Consortium

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
Consortium from the namespace http://www.niso.org/schemas/counter.

Each report item represents usage for a title. Note: it may have been more appropriate if the element name "ReportItems" was not plural since there can be many "ReportItems" one would expect each one to be a "ReportItem" without the 's'. As it stands there will be many "ReportItems" elements.




=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * Code


=item * WellKnownName




=back


=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # SUSHI::SUSHITypes::Consortium
   Code =>  $some_value, # string
   WellKnownName =>  $some_value, # string
 },




=head1 AUTHOR

Generated by SOAP::WSDL

=cut
