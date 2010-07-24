package main;

use strict;
use warnings;

use lib qw{ inc };

use App::Satpass2::Test::Format;

my $tst = App::Satpass2::Test::Format->new( 'App::Satpass2::Format' );

$tst->plan( tests => 19 );

$tst->require_ok();

$tst->can_ok( 'new' );
$tst->can_ok( 'date_format' );
$tst->can_ok( 'desired_equinox_dynamical' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'local_coord' );
$tst->can_ok( 'provider' );
$tst->can_ok( 'time_format' );
$tst->can_ok( 'tz' );

$tst->new_ok();		# Works only from App::Satpass2::Test.
$tst->method_is( date_format => '%Y-%m-%d',
    q{Default date_format is '%Y-%m-%d'} );
$tst->method_equals( desired_equinox_dynamical => 0,
    'Default desired_equinox_dynamical is 0' );
$tst->method_equals( gmt => 1,
    'Test framework sets gmt to 1' );
$tst->method_is( local_coord => 'azel_rng',
    q{Default local_coord is 'azel_rng' } );
$tst->method_is( provider => 'App::Satpass2::Test::Format',
    q{Test framework sets provider to 'App::Satpass2::Test::Format'} );
$tst->method_is( time_format => '%H:%M:%S',
    q{Default time_format is '%H:%M:%S'} );
$tst->method_is( tz => undef, 'Default time zone is undefined' );
$tst->method_ok( tz => 'est5edt', 'Set time zone' );
$tst->method_is( tz => 'est5edt', 'Got back same time zone' );

1;

# ex: set textwidth=72 :
