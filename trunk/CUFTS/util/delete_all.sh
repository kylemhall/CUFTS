#!/bin/tcsh

echo 'delete from subjects' | psql $1
echo 'delete from links' | psql $1
echo 'delete from journals' | psql $1
echo 'delete from associations' | psql $1
echo 'delete from titles' | psql $1

