package CUFTS::MaintTool::C::Site::ERM;

use strict;
use base 'Catalyst::Base';

sub auto : Private {
	my ($self, $c) = @_;
	$c->stash->{section} = 'erm';
}

sub edit : Local {
	my ($self, $c) = @_;
	
	$c->stash->{template} = 'site/erm/edit.tt';

}


=head1 NAME

CUFTS::MaintTool::C::Site::ERM - Component for ERM related data

=head1 SYNOPSIS

Handles site editing, changing sites, etc.

=head1 DESCRIPTION

Handles site editing, changing sites, etc.

=head1 AUTHOR

Todd Holbrook

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;

