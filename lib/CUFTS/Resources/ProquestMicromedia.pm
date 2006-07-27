## CUFTS::Resources::ProquestMicromedia
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
##
## This file is part of CUFTS.
##
## CUFTS is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 2 of the License, or (at your option)
## any later version.
##
## CUFTS is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CUFTS; if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CUFTS::Resources::ProquestMicromedia;

use base qw(CUFTS::Resources::Base::Journals);

use CUFTS::Exceptions;
use CUFTS::Util::Simple;

use strict;

my $base_url = 'http://openurl.proquest.com/in?';

sub title_list_fields {
    return [
        qw(
            id
            title
            issn
            ft_start_date
            ft_end_date
            embargo_days
        )
    ];
}

sub overridable_resource_details {
    return undef;
}

sub clean_data {
    my ( $class, $record ) = @_;
    my @errors;

    if ( defined( $record->{ft_start_date} ) ) {
        $record->{ft_start_date} =~ s{ (\d+) / (\d+) / (\d+) }{$3-$1-$2}xsm;
    }

    if ( defined( $record->{ft_end_date} ) ) {
        $record->{ft_end_date} =~ s{ (\d+) / (\d+) / (\d+) }{$3-$1-$2}xsm;
    }

    return \@errors;

}

sub title_list_field_map {
    return {
        'title'          => 'title',
        'issn'           => 'issn',
        'fulltext_start' => 'ft_start_date',
        'fulltext_end'   => 'ft_end_date',
        'embargo_days'   => 'embargo_days',
        'db_identifier'  => 'db_identifier',
    };
}

sub can_getFulltext {
    my ( $class, $request ) = @_;

    return 0 if is_empty_string( $request->spage );
    
    return $class->SUPER::can_getFulltext($request);
}

sub build_linkFulltext {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkFulltext');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkFulltext');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkFulltext');

    my @results;

    foreach my $record (@$records) {
        next if is_empty_string( $record->issn );

        my @params = ('service=pq');
        defined( $request->volume )
            and push @params, 'volume=' . $request->volume;
        defined( $request->issue )
            and push @params, 'issue=' . $request->issue;
        defined( $request->date )
            and push @params, 'date=' . $request->date;

        push @params, 'issn=' . $record->issn;
        push @params, 'spage='. $request->spage;

        my $url = $base_url;
        $url .= join '&', @params;

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub build_linkTOC {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkJournal');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkJournal');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkJournal');

    my @results;

    foreach my $record (@$records) {
        next if is_empty_string( $record->issn );

        my @params = ('service=pq');
        defined( $request->volume )
            and push @params, 'volume=' . $request->volume;
        defined( $request->issue )
            and push @params, 'issue=' . $request->issue;
        defined( $request->date )
            and push @params, 'date=' . $request->date;

        push @params, 'issn=' . $record->issn;

        my $url = $base_url;
        $url .= join '&', @params;

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

sub build_linkJournal {
    my ( $class, $records, $resource, $site, $request ) = @_;

    defined($records) && scalar(@$records) > 0
        or return [];
    defined($resource)
        or CUFTS::Exception::App->throw('No resource defined in build_linkJournal');
    defined($site)
        or CUFTS::Exception::App->throw('No site defined in build_linkJournal');
    defined($request)
        or CUFTS::Exception::App->throw('No request defined in build_linkJournal');

    my @results;

    foreach my $record (@$records) {
        next if is_empty_string( $record->issn );
        my @params = ('service=pq');

        push @params, 'issn=' . $record->issn;

        my $url = $base_url;
        $url .= join '&', @params;

        my $result = new CUFTS::Result($url);
        $result->record($record);

        push @results, $result;
    }

    return \@results;
}

1;
