package CUFTS::MaintTool::V::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config->{WRAPPER} = 'layout.tt';

use Template::Stash;

$Template::Stash::HASH_OPS->{ in } = sub {
  return __in( [ shift @_ ], @_ );
};

$Template::Stash::SCALAR_OPS->{ in } = sub {
  return __in( [ shift @_ ], @_ );
};


$Template::Stash::LIST_OPS->{ in } = \&__in;

sub __in {
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
}

$Template::Stash::LIST_OPS->{ simple_difference } = sub {
	my ($a, $b) = @_;
	my (%seen, @aonly);
	
	@seen{@$b} = ();  # build lookup table

	foreach my $item (@$a) {
		push(@aonly, $item) unless exists $seen{$item};
	}
	
	return \@aonly;
};


$Template::Stash::SCALAR_OPS->{substr} = sub { my ($scalar, $offset, $length) = @_; return defined($length) ? substr($scalar, $offset, $length) : substr($scalar, $offset); };
$Template::Stash::SCALAR_OPS->{ceil} = sub { return (int($_[0]) < $_[0]) ? int($_[0] + 1) : int($_[0]) };  # Cheap


=head1 NAME

CUFTS::MaintTool::V::TT - TT View Component

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
