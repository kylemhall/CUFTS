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
    my ($string) = @_;
    $string =~ s/^ \s+ //xsm;
    return $string;
}

sub rtrim_string :Export( :DEFAULT ) {
    my ($string) = @_;
    $string =~ s/ \s+ $//xsm;
    return $string;    
}

sub trim_string :Export( :DEFAULT ) {
    my ($string) = @_;
    $string =~ s/^ \s+ //xsm;
    $string =~ s/ \s+ $//xsm;
    return $string;    
}

1;
