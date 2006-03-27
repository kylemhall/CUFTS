package CUFTS::CJDB::Authentication::LDAP;
use Net::LDAPS;

use strict;

sub authenticate {
    my ( $class, $site, $user, $password ) = @_;

    my $auth_server = $site->cjdb_authentication_server
        or die("No authentication server set while attempting LDAP authentication");

    my $ldap = Net::LDAPS->new($auth_server)
        or die("Unable to connect to LDAP server");

    # Get bind string and replace user variables if necessary
    my $bind_string = $site->cjdb_authentication_string1
        or die("No bind string set in LDAP authentication");
    $bind_string =~ s/\$user/$user/g;

    my $mesg = $ldap->bind( $bind_string, password => $password );

    if ( $mesg->code != $Net::LDAP::Constants::LDAP_SUCCESS ) {
        die("Unable to bind user '$user', probably bad password");
    }

    # Get base and filter strings and replace user variables if necessary
    my $base_string = $site->cjdb_authentication_string2
        or die("No base string set in LDAP authentication");
    $base_string =~ s/\$user/$user/g;

    my $filter_string = $site->cjdb_authentication_string3
        or die("No base string set in LDAP authentication");
    $filter_string =~ s/\$user/$user/g;

    # Search for the user record 

    my $result = $ldap->search(
        base   => $base_string,
        filter => $filter_string
    );
    $ldap->unbind;

    if (    $result->code  != $Net::LDAP::Constants::LDAP_SUCCESS
         || $result->count != 1 )
    {
        die("Unable to retrieve user record.");
    }

    $result = $result->first_entry;

    if ( my $level100_string = $site->cjdb_authentication_level100 ) {
        my ($field, $regex) = split('=', $level100_string, 2);
        my $value = $result->get_value($field);
        warn($value);
        if ( $value =~ /$regex/ ) {
            return 100;
        }
    }

    if ( my $level50_string = $site->cjdb_authentication_level50 ) {
        my ($field, $regex) = split('=', $level50_string, 2);
        my $value = $result->get_value($field);
        warn($value);
        warn($regex);
        if ($value =~ /$regex/) {
            return 50;
        }
    }

    return 0;
}

1;