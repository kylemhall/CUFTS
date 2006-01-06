#!/bin/tcsh

echo 'delete from cjdb_subjects' | psql $1
echo 'delete from cjdb_links' | psql $1
echo 'delete from cjdb_journals' | psql $1
echo 'delete from cjdb_associations' | psql $1
echo 'delete from cjdb_titles' | psql $1
echo 'delete from cjdb_issns' | psql $1