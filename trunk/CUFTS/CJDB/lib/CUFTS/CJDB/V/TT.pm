package CUFTS::CJDB::V::TT;

use strict;
use base qw/Catalyst::View::TT/;

use Template::Config;
$Template::Config::STASH = 'Template::Stash::XS';

our $VERSION = '0.14';

$Template::Stash::LIST_OPS->{ in } = sub {
	my ($list, $val, $field) = @_;
	return 0 unless scalar(@$list);
	defined($val) or 
		die("Value to match on not passed into 'in' virtual method");
	
	if (defined($field) && $field ne '') {
		no strict 'refs';
		return((grep { (ref($_) eq 'HASH' ?
		                  $_->{$field} :
				  $_->$field()) eq $val} @$list) ? 1 : 0);
	} else {
		return((grep {$_ eq $val} @$list) ? 1 : 0);
	}
};

$Template::Stash::LIST_OPS->{ simple_difference } = sub {
	my ($a, $b) = @_;
	my (%seen, @aonly);
	
	@seen{@$b} = ();  # build lookup table

	foreach my $item (@$a) {
		push(@aonly, $item) unless exists $seen{$item};
	}
	
	return \@aonly;
};

$Template::Stash::SCALAR_OPS->{force_list} = sub {
    return [ shift ];
};

$Template::Stash::LIST_OPS->{force_list} = sub {
    return @_;
};

$Template::Stash::HASH_OPS->{force_list} = sub {
    return [ shift ];
};


$Template::Stash::SCALAR_OPS->{substr} = sub { my ($scalar, $offset, $length) = @_; return defined($length) ? substr($scalar, $offset, $length) : substr($scalar, $offset); };
$Template::Stash::SCALAR_OPS->{ceil} = sub { return (int($_[0]) < $_[0]) ? int($_[0] + 1) : int($_[0]) };  # Cheap
$Template::Stash::LIST_OPS->{map_join} = sub {
	my ($list, $field, $join) = @_;
	return join( $join, map {$_->$field} @$list );
};

$Template::Stash::SCALAR_OPS->{uri_escape} = sub { my $text = shift; $text =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg; return $text; };


=head1 NAME

CUFTS::CJDB::V::TT - TT View Component

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice component.

=head1 AUTHOR

Clever guy

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
