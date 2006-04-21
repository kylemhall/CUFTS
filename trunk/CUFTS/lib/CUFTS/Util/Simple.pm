package CUFTS::Util::Simple;

use strict;
use Perl6::Export::Attrs;

# Basic string/list utility routines used throughout CUFTS

# is_empty_string - returns 1 if string is not defined or is empty ''

sub is_empty_string :Export( :DEFAULT ) {
    my ($string) = @_;

    return 1 if !defined($string);
    return 1 if $string eq q{};

    return 0;  # Not empty
}

sub not_empty_string :Export( :DEFAULT ) {
    return !is_empty_string(@_);
}

sub ltrim_string :Export( :DEFAULT ) {
    my ($string, $trim) = @_;
    return undef if !defined($string);
    if (!defined($trim) ) {
        $trim = '';
    }
    $string =~ s/^ [\n\s]* $trim? [\n\s]* //xsm;
    return $string;
}

sub rtrim_string :Export( :DEFAULT ) {
    my ($string, $trim) = @_;
    return undef if !defined($string);
    if (!defined($trim) ) {
        $trim = '';
    }
    $string =~ s/ [\n\s]* $trim? [\n\s]* $//xsm;
    return $string;    
}

sub trim_string :Export( :DEFAULT ) {
    my ($string, $trim) = @_;
    return undef if !defined($string);
    $string = ltrim_string($string, $trim);
    $string = rtrim_string($string, $trim);
    return $string;
}

sub dashed_issn :Export( :DEFAULT ) {
    my ($string) = @_;
    return undef if !defined($string);
    if ( length($string) == 8 ) {
        $string = substr( $string, 0, 4 ) . '-' . substr( $string, 4, 4 )
    }
    return $string;
}

1;
