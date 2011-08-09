package SUSHI::SUSHITypes::Contact;
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

my %Contact_of :ATTR(:get<Contact>);
my %E_mail_of :ATTR(:get<E_mail>);

__PACKAGE__->_factory(
    [ qw(        Contact
        E_mail

    ) ],
    {
        'Contact' => \%Contact_of,
        'E_mail' => \%E_mail_of,
    },
    {
        'Contact' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'E_mail' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
    },
    {

        'Contact' => 'Contact',
        'E_mail' => 'E-mail',
    }
);

} # end BLOCK







1;


=pod

=head1 NAME

SUSHI::SUSHITypes::Contact

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
Contact from the namespace http://www.niso.org/schemas/counter.

Details of a person to contact.




=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * Contact


=item * E_mail

Note: The name of this property has been altered, because it didn't match
perl's notion of variable/subroutine names. The altered name is used in
perl code only, XML output uses the original name:

 E-mail




=back


=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # SUSHI::SUSHITypes::Contact
   Contact =>  $some_value, # string
   E_mail =>  $some_value, # string
 },




=head1 AUTHOR

Generated by SOAP::WSDL

=cut
