package CUFTS::MaintTool::C::ERM::Statistics;

use strict;
use base 'Catalyst::Base';

use JSON::XS qw( encode_json );
use DateTime;
use DateTime::Format::ISO8601;
use Chart::OFC;

use Data::Dumper;

use CUFTS::Util::Simple;

use CUFTS::DB::ERMMain;

my @chart_colours = (
    'red',
    'blue',
    'green',
    'purple',
    'yellow',
    'black',
);

sub auto : Private {
    my ( $self, $c ) = @_;

    my @resources;
    if ( $c->session->{selected_erm_main} && scalar( @{$c->session->{selected_erm_main}} ) ) {
        @resources = CUFTS::DB::ERMMain->search(
            {
                id => { '-in' => $c->session->{selected_erm_main} },
                site => $c->stash->{current_site}->id,
            },
            {
                sql_method => 'with_name',
                order_by => 'result_name'
            }
        );
    }

    my @standard_fields = qw( start_date end_date granularity format );
    
    $c->stash->{report_config} = {
        clickthroughs => {
            id     => 'clickthroughs',
            fields => \@standard_fields,
            uri    => $c->stash->{url_base} . '/erm/statistics/clickthroughs',
        },
        usage_cost => {
            id     => 'usage_cost',
            fields => [ qw( start_date end_date format ) ],
            uri    => $c->stash->{url_base} . '/erm/statistics/clickthroughs',
        },
    };

    $c->stash->{resources} = \@resources;

    return 1;
}


sub default : Private {
    my ( $self, $c ) = @_;
    
    $c->stash->{template} = "erm/statistics/menu.tt";
}



sub clickthroughs : Local {
    my ( $self, $c ) = @_;   
    
    $c->form({
        optional => [ qw( run_report ) ],
        required => [ qw( selected_resources start_date end_date granularity format ) ],
        constraints => {
            start_date  => qr/^\d{4}-\d{1,2}-\d{1,2}/,
            end_date    => qr/^\d{4}-\d{1,2}-\d{1,2}/,
        },
    });
    
    if ( $c->form->has_missing || $c->form->has_invalid || $c->form->has_unknown ) {
        return $c->forward('default');
    }

    my $format      = $c->form->{valid}->{format};
    my $granularity = $c->form->{valid}->{granularity};
    my $start_date  = $c->form->{valid}->{start_date};
    my $end_date    = $c->form->{valid}->{end_date};
        
    my @resource_ids = split(',', $c->form->{valid}->{selected_resources} );
    
    my $uses = CUFTS::DB::ERMUses->count_grouped( $granularity, $start_date, $end_date, \@resource_ids );

    my @resource_names = CUFTS::DB::ERMNames->search( { erm_main => {'-in' => \@resource_ids}, main => 1 }, { order_by => 'search_name'} );
    $c->stash->{resources} = [ map { { id => $_->erm_main, name => $_->name } } @resource_names ];

    my $dates = _build_granulated_dates( $start_date, $end_date, $granularity );

    # Build two hashes of the results, one keyed on date the other on resource

    my ( %date_hash, %resource_hash, $max );
    foreach my $use ( @$uses ) {
        my ( $resource_id, $count, $date ) = @$use;
        $resource_hash{$resource_id}->{$date} = $count;
        $date_hash{$date}->{$resource_id} = $count;
        if ( $count > $max ) {
            $max = $count;
        }
    }

    $c->stash->{resources_hash}   = \%resource_hash;
    $c->stash->{dates_hash}       = \%date_hash;
    $c->stash->{clickthrough_max} = $max;

    $c->stash->{dates}         = $dates;
    $c->stash->{start_date}    = $c->form->valid->{start_date};
    $c->stash->{end_date}      = $c->form->valid->{end_date};
    
    if ( $format eq 'html' ) {
        $c->stash->{template} = 'erm/statistics/clickthroughs/html.tt';
    }
    elsif ( $format eq 'tab' ) {
        $c->response->content_type('text/plain');
        $c->stash->{template} = 'erm/statistics/clickthroughs/tab.tt';
    }
    elsif ( $format eq 'graph' ) {
        $c->forward( 'clickthrough_ofc' );
    }
}


sub clickthrough_ofc : Private {
    my ( $self, $c ) = @_;


    my $stash = $c->stash;

    my $x_axis = Chart::OFC::XAxis->new(
        axis_label  => 'Date',
        labels      => [ map { $_->{display} } @{$stash->{dates}} ],
    );
    my $y_axis = Chart::OFC::YAxis->new(
        axis_label  => 'Clickthroughs',
        max         => $stash->{clickthrough_max},
        label_steps => 1,
    );

    my @dates = map { $_->{date} } @{$stash->{dates}};
    
    my @chart_data;
    my $count = 0;
    foreach my $resource ( @{$stash->{resources}} ) {
        push @chart_data, Chart::OFC::Dataset::LineWithDots->new(
            color       => $chart_colours[$count++],
            label       => $resource->{name},
            solid_dots  => 1,
            values      => [ map { $stash->{resources_hash}->{$resource->{id}}->{$_} } @dates ],
        );
    }
    
    my $grid = Chart::OFC::Grid->new(
        title       => 'ERM Clickthroughs',
        datasets    => \@chart_data,
        x_axis      => $x_axis,
        y_axis      => $y_axis,
    );
    
    $c->flash->{ofc} = $grid->as_ofc_data;

    # Calculate a width/height that will allow all data points to be seen (hopefully)
    
    $c->stash->{chart_width} = scalar( @{$stash->{dates}} ) * 60;
    
    $c->stash->{template} = 'erm/statistics/ofc.tt';
    $c->stash->{data_url} = $c->uri_for('ofc_flash');
}


sub ofc_flash : Local {
    my ( $self, $c ) = @_;

    $c->response->body( $c->flash->{ofc} );
}


# Builds a list of dates based on the start/end date and granularity.  Dates produced are in "YYYY-MM-DD HH:mm:ss" format

sub _build_granulated_dates {
    my ( $start_date, $end_date, $granularity ) = @_;
    
    my $add_granularity = "${granularity}s";  # week => weeks.  make this more complex if we hit something that's not a trivial map
    my $start_dt = DateTime::Format::ISO8601->parse_datetime($start_date);
    my $end_dt   = DateTime::Format::ISO8601->parse_datetime($end_date);

    my @list = ();
    for (my $dt = $start_dt->clone(); $dt <= $end_dt; $dt->add($add_granularity => 1) ) {
        my $trunc_dt = $dt->clone()->truncate( to => $granularity );
        push @list, { date => ($trunc_dt->ymd . ' ' . $trunc_dt->hms), display => _truncate_date($trunc_dt, $granularity) };
    }

    return \@list;
}

# Truncates a DateTime for display based on granularity.

sub _truncate_date {
    my ( $date, $granularity ) = @_;

    if ( $granularity eq 'year' ) {
        return $date->year;
    }
    elsif ( $granularity eq 'month' ) {
        return $date->strftime('%Y-%m');
    }
    elsif ( $granularity eq 'day' ) {
        return $date->ymd;
    }
    else {
        return $date->ymd . ' ' . $date->hms
    }
}


1;
