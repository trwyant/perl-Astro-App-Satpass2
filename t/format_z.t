package main;

use strict;
use warnings;

use lib qw{ inc };

use Astro::App::Satpass2::Test::Format;

my $tst = Astro::App::Satpass2::Test::Format->new( 'Astro::App::Satpass2::Format' );

$tst->plan( tests => 21 );

$tst->require_ok();

$tst->can_ok( 'new' );
$tst->can_ok( 'date_format' );
$tst->can_ok( 'desired_equinox_dynamical' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'local_coord' );
$tst->can_ok( 'provider' );
$tst->can_ok( 'time_format' );
$tst->can_ok( 'tz' );

$tst->new_ok();		# Works only from Astro::App::Satpass2::Test.
$tst->method_is( date_format => '%Y-%m-%d',
    q{Default date_format is '%Y-%m-%d'} );
$tst->method_equals( desired_equinox_dynamical => 0,
    'Default desired_equinox_dynamical is 0' );
$tst->method_equals( gmt => 1,
    'Test framework sets gmt to 1' );
$tst->method_is( local_coord => 'azel_rng',
    q{Default local_coord is 'azel_rng' } );
$tst->method_is( provider => 'Astro::App::Satpass2::Test::Format',
    q{Test framework sets provider to 'Astro::App::Satpass2::Test::Format'} );
$tst->method_is( time_format => '%H:%M:%S',
    q{Default time_format is '%H:%M:%S'} );
$tst->method_is( tz => undef, 'Default time zone is undefined' );
$tst->method_ok( tz => 'est5edt', 'Set time zone' );
$tst->method_is( tz => 'est5edt', 'Got back same time zone' );

my $expect_time_formatter = eval {
    require DateTime;
    require DateTime::TimeZone;
    'Astro::App::Satpass2::FormatTime::DateTime::Strftime';
} || 'Astro::App::Satpass2::FormatTime::POSIX::Strftime';

$tst->method_is( config => decode => 1,
    [
	[ date_format			=> '%Y-%m-%d' ],
	[ desired_equinox_dynamical	=> 0 ],
	[ gmt				=> 1 ],
	[ header			=> 1 ],
	[ local_coord			=> 'azel_rng' ],
	[ provider			=> 'Astro::App::Satpass2::Test::Format' ],
	[ time_format			=> '%H:%M:%S' ],
	[ time_formatter		=> $expect_time_formatter ],
	[ tz				=> 'est5edt' ],
    ],
    'Dump configuration' );
$tst->method_is( config => decode => 1, changes => 1,
    [
	[ gmt				=> 1 ],
	[ provider			=> 'Astro::App::Satpass2::Test::Format' ],
	[ time_formatter		=> $expect_time_formatter ],
	[ tz				=> 'est5edt' ],
    ],
    'Dump configuration changes' );

1;

# ex: set textwidth=72 :
