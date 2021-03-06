## This overrides the standard SOAP::WSDL::Deserializer::XSD to
## give us some control of tweaking the response before trying to XML parse
## it. Solves some issues with servers spitting out errors or other stuff
## before the XML response.

package SUSHI::Deserializer::XSD;
use strict;
use warnings;
use Class::Std::Fast::Storable;
use SOAP::WSDL::SOAP::Typelib::Fault11;
use SOAP::WSDL::Expat::MessageParser;

our $VERSION = 3.003;

my %class_resolver_of   :ATTR(:name<class_resolver> :default<()>);
my %strict_of           :ATTR(:get<strict> :init_arg<strict> :default<1>);
my %parser_of           :ATTR();

sub set_strict {
    undef $parser_of{${$_[0]}};
    $strict_of{${$_[0]}} = $_[1];
}

sub BUILD {
    my ($self, $ident, $args_of_ref) = @_;

    # ignore all options except 'class_resolver'
    for (keys %{ $args_of_ref }) {
        next if $_ eq 'strict';
        next if $_ eq 'class_resolver';
        delete $args_of_ref->{ $_ };
    }
}

sub deserialize {
    my ($self, $content) = @_;

    $parser_of{ ${ $self } } = SOAP::WSDL::Expat::MessageParser->new({
        strict => $strict_of{ ${ $self } }
    })
        if not $parser_of{ ${ $self } };
    $parser_of{ ${ $self } }->class_resolver( $class_resolver_of{ ${ $self } } );

    # warn( substr( $content, 0, 200 ) );

    $content =~ s{^.+?<soap:Env}{<soap:Env}xsm;
    $content =~ s{^<\?xml version="1.0" *\?>}{};  # XML::Parser::Expat apparently doesn't like this.

    # warn( substr( $content, 0, 200 ) );

    eval { $parser_of{ ${ $self } }->parse_string( $content ) };
    if ($@) {
        warn($@);
        return $self->generate_fault({
            code => 'SOAP-ENV:Server',
            role => 'urn:localhost',
            message => "Error deserializing message: $@. \n"
                . "Message was: \n$content"
        });
    }

    return ( $parser_of{ ${ $self } }->get_data(), $parser_of{ ${ $self } }->get_header() );
}

sub generate_fault {
    my ($self, $args_from_ref) = @_;
    return SOAP::WSDL::SOAP::Typelib::Fault11->new({
            faultcode => $args_from_ref->{ code } || 'SOAP-ENV:Client',
            faultactor => $args_from_ref->{ role } || 'urn:localhost',
            faultstring => $args_from_ref->{ message } || "Unknown error"
    });
}

1;

__END__

=head1 NAME

SOAP::WSDL::Deserializer::XSD - Deserializer SOAP messages into SOAP::WSDL::XSD::Typelib:: objects

=head1 DESCRIPTION

Default deserializer for SOAP::WSDL::Client and interface classes generated by
SOAP::WSDL. Converts SOAP messages to SOAP::WSDL::XSD::Typlib:: based objects.

Needs a class_resolver typemap either passed by the generated interface
or user-provided.

SOAP::WSDL::Deserializer classes implement the API described in
L<SOAP::WSDL::Factory::Deserializer>.

=head1 USAGE

Usually you don't need to do anything to use this package - it's the default
deserializer for SOAP::WSDL::Client and interface classes generated by
SOAP::WSDL.

If you want to use the XSD serializer from SOAP::WSDL, set the outputtree()
property and provide a class_resolver.

=head1 OPTIONS

=over

=item * strict

Enables/disables strict XML processing. Strict processing is enabled by
default. To disable strict XML processing pass the following to the
constructor or use the C<set_strict> method:

 strict => 0

=back

=head1 METHODS

=head2 deserialize

Deserializes the message.

=head2 generate_fault

Generates a L<SOAP::WSDL::SOAP::Typelib::Fault11|SOAP::WSDL::SOAP::Typelib::Fault11>
object and returns it.

=head2 set_strict

Enable/disable strict XML parsing. Default is enabled.

=head1 LICENSE AND COPYRIGHT

Copyright 2004-2007 Martin Kutter.

This file is part of SOAP-WSDL. You may distribute/modify it under
the same terms as perl itself.

=head1 AUTHOR

Martin Kutter E<lt>martin.kutter fen-net.deE<gt>

=head1 REPOSITORY INFORMATION

 $Rev: 851 $
 $LastChangedBy: kutterma $
 $Id: XSD.pm 851 2009-05-15 22:45:18Z kutterma $
 $HeadURL: https://soap-wsdl.svn.sourceforge.net/svnroot/soap-wsdl/SOAP-WSDL/trunk/lib/SOAP/WSDL/Deserializer/XSD.pm $

=cut
