use Test::More tests => 2;
use_ok( Catalyst::Test, 'CUFTS::CJDB' );

ok( request('/')->is_success );
