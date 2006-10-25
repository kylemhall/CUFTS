package CUFTS::CJDB::V::TT;

use strict;
use base qw/Catalyst::Base/;
use Template;
use Template::Timer;
use CUFTS::CJDB::Template::Provider;

our $VERSION = '0.12';

__PACKAGE__->mk_accessors('template');


__PACKAGE__->config->{WRAPPER} = 'layout.tt';
#__PACKAGE__->config->{COMPILE_DIR} = '/tmp/CJDB_template_cache';

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
 


sub new {
    my $self = shift;
    my $c    = shift;
    $self = $self->NEXT::new(@_);
    my $root   = $c->config->{root};
    $Template::Config::STASH = 'Template::Stash::XS';
    my %config = (
        EVAL_PERL    => 0,
        LOAD_TEMPLATES => [ CUFTS::CJDB::Template::Provider->new({INCLUDE_PATH => [ $root, "$root/base" ],}) ],
        %{ $self->config() }
    );

#    if ( $c->debug && not exists $config{CONTEXT} ) {
#       $config{CONTEXT} = Template::Timer->new(%config);
#    }

    $self->template( Template->new( \%config ) );    

    return $self;
}


sub process {
	my $self = shift;
	my $c    = shift;

	my $root = $c->config->{root};

	$self->template->context->load_templates->[0]->include_path([ $root . $c->stash->{site_template_dir}, $root, "$root/base"]);

    my $template = $c->stash->{template} || $c->request->match;

    unless ($template) {
        $c->log->debug('No template specified for rendering') if $c->debug;
        return 0;
    }

    if ($c->debug) {
        $c->log->debug('Template include path: ' . join(',', @{$self->template->context->load_templates->[0]->include_path}));
        $c->log->debug(qq/Rendering template "$template"/);
    }
    
    my $output;


    unless (
        $self->template->process(
            $template,
            {
                base => $c->req->base,
                c    => $c,
                name => $c->config->{name},
                %{ $c->stash }
            },
            \$output
        )
      )
    {
        my $error = $self->template->error;
        $error = qq/Couldn't render template "$error"/;
        $c->log->error($error);
        $c->error($error);
        return 0;
    }
    
    unless ( $c->response->content_type ) {
        $c->response->content_type('text/html; charset=utf-8');
    }

    $c->response->body($output);

    return 1;
}


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
