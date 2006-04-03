package CUFTS::JournalsAuth;

use CUFTS::DB::Resources;
use CUFTS::DB::JournalsAuth;
use CUFTS::DB::Journals;
use CUFTS::DB::LocalJournals;
use CJDB::DB::Journals;
use CJDB::DB::Tags;

use strict;

# Utility code for working with JournalsAuth records

sub merge {
    my ( $class, @ids ) = @_;

    return undef if !scalar(@ids);

    # Merge down to the first id passed in
    my $journal_auth = CUFTS::DB::JournalsAuth->retrieve( shift(@ids) );
    
    foreach my $ja_id (@ids) {

        my $old_journal_auth = CUFTS::DB::JournalsAuth->retrieve($ja_id);

        $class->merge_ja_issns(  $journal_auth, $old_journal_auth );
        $class->merge_ja_titles( $journal_auth, $old_journal_auth );

        $class->merge_cjdb_journals( $journal_auth, $old_journal_auth );
        $class->merge_cjdb_tags(     $journal_auth, $old_journal_auth );

        $class->update_journals( $journal_auth, $old_journal_auth );

        $old_journal_auth->delete();
    }

    return $journal_auth;
}

sub update_journals {
    my ( $class, $journal_auth, $old_journal_auth ) = @_;
    
    my @journals = CUFTS::DB::Journals->search( 'journal_auth' => $old_journal_auth->id );
    foreach my $journal ( @journals ) {
        $journal->journal_auth( $journal_auth->id );
        $journal->update();
    }

    @journals = CUFTS::DB::LocalJournals->search( 'journal_auth' => $old_journal_auth->id );
    foreach my $journal ( @journals ) {
        $journal->journal_auth( $journal_auth->id );
        $journal->update();
    }

    return 1;
}


sub merge_ja_issns {
    my ( $class, $journal_auth, $old_journal_auth ) = @_;

    foreach my $issn ( $old_journal_auth->issns ) {
        my $record = { journal_auth => $journal_auth->id, };
        foreach my $column ( $issn->columns ) {
            next if grep { $_ eq $column } qw{ id journal_auth };
            $record->{$column} = $issn->$column();
        }
        CUFTS::DB::JournalsAuthISSNs->find_or_create($record);
        $issn->delete();
    }

    return 1;
}

sub merge_ja_titles {
    my ( $class, $journal_auth, $old_journal_auth ) = @_;

    foreach my $title ( $old_journal_auth->titles ) {

        my $record = { journal_auth => $journal_auth->id, };
        foreach my $column ( $title->columns ) {
            next if grep { $_ eq $column } qw{ id journal_auth };
            $record->{$column} = $title->$column();
        }

        my $existing = CUFTS::DB::JournalsAuthTitles->search(
            {   journal_auth => $record->{journal_auth},
                title        => $record->{title},
            }
        )->first;

        if ($existing) {
            $existing->title_count($existing->title_count() + $record->{title_count});
            $existing->update;
        }
        else {
            CUFTS::DB::JournalsAuthTitles->create($record);
        }

        $title->delete();
    }

    return 1;
}

sub merge_cjdb_journals {
    my ( $class, $journal_auth, $old_journal_auth ) = @_;

    my $site_iter = CUFTS::DB::Sites->retrieve_all();
    while ( my $site = $site_iter->next ) {

        my $cjdb_journal = CJDB::DB::Journals->search(
            {
                site         => $site->id,
                journals_auth => $old_journal_auth->id,
            }
        )->first;
        
        my $old_cjdb_journals_iter = CJDB::DB::Journals->search(
            {
                site         => $site->id,
                journals_auth => $journal_auth->id,
            }
        );
        
        while ( my $old_cjdb_journal = $old_cjdb_journals_iter->next ) {

            if ( defined($cjdb_journal) ) {
                $class->merge_cjdb_titles(       $cjdb_journal, $old_cjdb_journal );
                $class->merge_cjdb_links(        $cjdb_journal, $old_cjdb_journal );
                $class->merge_cjdb_subjects(     $cjdb_journal, $old_cjdb_journal );
                $class->merge_cjdb_issns(        $cjdb_journal, $old_cjdb_journal );
                $class->merge_cjdb_associations( $cjdb_journal, $old_cjdb_journal );
                $class->merge_cjdb_relations(    $cjdb_journal, $old_cjdb_journal );
                
                $old_cjdb_journal->delete();
            }
            else {
                $old_cjdb_journal->journals_auth( $journal_auth->id );
                $old_cjdb_journal->update();

            }
        }
    }

    return 1;
}

sub merge_cjdb_titles {
    my ( $class, $cjdb_journal, $old_cjdb_journal ) = @_;
    
    my @titles = map { $_->search_title } $cjdb_journal->titles;
    foreach my $title ($old_cjdb_journal->titles) {

        if ( grep { $title->search_title eq $_ } @titles ) {
            $title->delete();
        }
        else {
            $title->journal( $cjdb_journal->id );
            $title->update;
        }
        
    }
    
    return 1;
}

sub merge_cjdb_links {
    my ( $class, $cjdb_journal, $old_cjdb_journal ) = @_;

    my @links = map { $_->url } $cjdb_journal->links;
    foreach my $link ($old_cjdb_journal->links) {

        if ( grep { $link->url eq $_ } @links ) {
            $link->delete();
        }
        else {
            $link->journal( $cjdb_journal->id );
            $link->update;
        }
        
    }
    
    return 1;
}


sub merge_cjdb_associations {
    my ( $class, $cjdb_journal, $old_cjdb_journal ) = @_;

    my @associations = map { $_->search_association } $cjdb_journal->associations;
    foreach my $association ($old_cjdb_journal->associations) {

        if ( grep { $association->search_association eq $_ } @associations ) {
            $association->delete();
        }
        else {
            $association->journal( $cjdb_journal->id );
            $association->update;
        }
        
    }
    
    return 1;
}

sub merge_cjdb_subjects {
    my ( $class, $cjdb_journal, $old_cjdb_journal ) = @_;

    my @subjects = map { $_->search_subject } $cjdb_journal->subjects;
    foreach my $subject ($old_cjdb_journal->subjects) {

        if ( grep { $subject->search_subject eq $_ } @subjects ) {
            $subject->delete();
        }
        else {
            $subject->journal( $cjdb_journal->id );
            $subject->update;
        }
        
    }
    
    return 1;
}


sub merge_cjdb_relations {
    my ( $class, $cjdb_journal, $old_cjdb_journal ) = @_;

    my @relations = map { $_->title } $cjdb_journal->relations;
    foreach my $relation ($old_cjdb_journal->relations) {

        if ( grep { $relation->title eq $_ } @relations ) {
            $relation->delete();
        }
        else {
            $relation->journal( $cjdb_journal->id );
            $relation->update;
        }
        
    }
    
    return 1;
}


sub merge_cjdb_issns {
    my ( $class, $cjdb_journal, $old_cjdb_journal ) = @_;

    my @issns = map { $_->issn } $cjdb_journal->issns;
    foreach my $issn ($old_cjdb_journal->issns) {

        if ( grep { $issn->issn eq $_ } @issns ) {
            $issn->delete();
        }
        else {
            $issn->journal( $cjdb_journal->id );
            $issn->update;
        }
        
    }
    
    return 1;
}


sub merge_cjdb_tags {
    my ( $class, $journal_auth, $old_journal_auth ) = @_;
    
    my $tags_iter = CJDB::DB::Tags->search({ journals_auth => $old_journal_auth->id });
    while (my $tag = $tags_iter->next) {
        # Check for existing tag on new journal
        my @existing = CJDB::DB::Tags->search(
            {
                tag          => $tag->tag,
                account      => $tag->account,
                journals_auth => $journal_auth->id,
            }
        );

        if ( scalar(@existing) ) {
            $tag->delete;
        }
        else {
            $tag->journals_auth( $journal_auth->id );
            $tag->update;
        } 
    }
    
    return 1;    
}


1;
