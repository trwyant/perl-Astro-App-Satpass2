package main;

use strict;
use warnings;

use lib qw{ inc };

BEGIN {
    eval {
	require App::Satpass2::Test::ParseTime;
	App::Satpass2::Test::ParseTime->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 or greater not available\n";
	exit;
    };

}

my $test_mocktime;

BEGIN {

    local $@;

    eval {
	require Time::y2038;
	Time::y2038->import( qw{ timegm timelocal } );
	1;
    } or eval {
	require Time::Local;
	Time::Local->import( qw{ timegm timelocal } );
	1;
    } or do {
	plan( skip_all =>
	    'Time::y2038 or Time::Local required' );
	exit;
    };

    $test_mocktime = eval {
	require Test::MockTime;
	Test::MockTime->import( qw{ restore_time set_fixed_time } );
	1;
    };

}

plan( tests => 84 );

require_ok( 'App::Satpass2::ParseTime' );

my $pt = eval {
    App::Satpass2::ParseTime->new( 'App::Satpass2::ParseTime::ISO8601' );
} or diag( 'Failed to instantiate App::Satpass2::ParseTime: ' . $@ );

isa_ok( $pt, 'App::Satpass2::ParseTime::ISO8601' );

isa_ok( $pt, 'App::Satpass2::ParseTime' );

my $base = timegm( 0, 0, 0, 1, 3, 109 );	# April 1, 2009 GMT;
use constant ONE_DAY => 86400;			# One day, in seconds.
use constant HALF_DAY => 43200;			# 12 hours, in seconds.

time_ok( $pt, base => $base, 'Set base time to 01-Apr-2009 GMT' );

time_is( $pt, parse => '+0', $base, 'Parse of +0 returns base time' );

time_is( $pt, parse => '+1', $base + ONE_DAY,
    'Parse of +1 returns one day later than base time' );

time_is( $pt, parse => '+0', $base + ONE_DAY,
    'Parse of +0 now returns one day later than base time' );

time_ok( $pt, 'reset', 'Reset to base time' );

time_is( $pt, parse => '+0', $base, 'Parse of +0 returns base time again' );

time_is( $pt, parse => '+0 12', $base + HALF_DAY,
    q{Parse of '+0 12' returns base time plus 12 hours} );

time_ok( $pt, 'reset', 'Reset to base time again' );

time_is( $pt, parse => '-0', $base, 'Parse of -0 returns base time' );

time_is( $pt, parse => '-0 12', $base - ONE_DAY / 2,
    'Parse of \'-0 12\' returns 12 hours before base time' );

time_ok( $pt, perltime => 1, 'Set perltime true' );

time_is( $pt, parse => '20090101T000000',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000' );

time_is( $pt, parse => '20090701T000000',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000' );

time_ok( $pt, perltime => 0, 'Set perltime false' );

time_is( $pt, parse => '20090101T000000',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000, no help from perltime' );

time_is( $pt, parse => '20090701T000000',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000, no help from perltime' );

time_is( $pt, parse => '20090101T000000Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000Z' );

time_is( $pt, parse => '20090701T000000Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000Z' );

time_is( $pt, parse => '20090702162337',
    timelocal( 37, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702162337'} );
time_is( $pt, parse => '20090702162337Z',
    timegm( 37, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702162337Z'} );
time_is( $pt, parse => '200907021623',
    timelocal( 0, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '200907021623'} );
time_is( $pt, parse => '200907021623Z',
    timegm( 0, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '200907021623Z'} );
time_is( $pt, parse => '2009070216',
    timelocal( 0, 0, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '2009070216'} );
time_is( $pt, parse => '2009070216Z',
    timegm( 0, 0, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '2009070216Z'} );
time_is( $pt, parse => '20090702',
    timelocal( 0, 0, 0, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702'} );
time_is( $pt, parse => '20090702Z',
    timegm( 0, 0, 0, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702Z'} );
time_is( $pt, parse => '200907',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    q{Parse ISO-8601 '200907'} );
time_is( $pt, parse => '200907Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    q{Parse ISO-8601 '200907Z'} );
time_is( $pt, parse => '2009',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009'} );
time_is( $pt, parse => '2009Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009Z'} );

time_is( $pt, parse => '20090102162337',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337'} );
time_is( $pt, parse => '20090102162337Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337Z'} );
time_is( $pt, parse => '200901021623',
    timelocal( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '200901021623'} );
time_is( $pt, parse => '200901021623Z',
    timegm( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '200901021623Z'} );
time_is( $pt, parse => '2009010216',
    timelocal( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009010216'} );
time_is( $pt, parse => '2009010216Z',
    timegm( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009010216Z'} );
time_is( $pt, parse => '20090102',
    timelocal( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102'} );
time_is( $pt, parse => '20090102Z',
    timegm( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102Z'} );
time_is( $pt, parse => '200901',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '200901'} );
time_is( $pt, parse => '200901Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '200901Z'} );

time_is( $pt, parse => '20090102162337+00',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337+00'} );
time_is( $pt, parse => '20090102162337+0030',
    timegm( 37, 53, 15, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337+0030'} );
time_is( $pt, parse => '20090102162337+01',
    timegm( 37, 23, 15, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337+01'} );
time_is( $pt, parse => '20090102162337-0030',
    timegm( 37, 53, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337-0030'} );
time_is( $pt, parse => '20090102162337-01',
    timegm( 37, 23, 17, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337-01'} );

time_is( $pt, parse => '20090102T162337',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102T162337'} );
time_is( $pt, parse => '20090102T162337Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102T162337Z'} );

time_is( $pt, parse => '2009/1/2 16:23:37',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23:37'} );
time_is( $pt, parse => '2009/1/2 16:23:37 Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23:37 Z'} );
time_is( $pt, parse => '2009/1/2 16:23',
    timelocal( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23'} );
time_is( $pt, parse => '2009/1/2 16:23 Z',
    timegm( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23 Z'} );
time_is( $pt, parse => '2009/1/2 16',
    timelocal( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16'} );
time_is( $pt, parse => '2009/1/2 16 Z',
    timegm( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16 Z'} );
time_is( $pt, parse => '2009/1/2',
    timelocal( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2'} );
time_is( $pt, parse => '2009/1/2 Z',
    timegm( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 Z'} );
time_is( $pt, parse => '2009/1',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009/1'} );
time_is( $pt, parse => '2009/1 Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009/1 Z'} );
time_is( $pt, parse => '2009',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009'} );
time_is( $pt, parse => '2009 Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009 Z'} );

time_is( $pt, parse => '09/1/2 16:23:37',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23:37'} );
time_is( $pt, parse => '09/1/2 16:23:37 Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23:37 Z'} );
time_is( $pt, parse => '09/1/2 16:23',
    timelocal( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23'} );
time_is( $pt, parse => '09/1/2 16:23 Z',
    timegm( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23 Z'} );
time_is( $pt, parse => '09/1/2 16',
    timelocal( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16'} );
time_is( $pt, parse => '09/1/2 16 Z',
    timegm( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16 Z'} );
time_is( $pt, parse => '09/1/2',
    timelocal( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2'} );
time_is( $pt, parse => '09/1/2 Z',
    timegm( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 Z'} );
time_is( $pt, parse => '09/1',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '09/1'} );
time_is( $pt, parse => '09/1 Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '09/1 Z'} );

SKIP: {

    $test_mocktime or skip( 'Unable to load Test::MockTime', 12 );

    set_fixed_time('2009-07-01T06:00:00Z');

    time_is( $pt, parse => 'yesterday Z',
	timegm( 0, 0, 0, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday Z'} );
    time_is( $pt, parse => 'yesterday 9:30Z',
	timegm( 0, 30, 9, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday 9:30Z'} );
    time_is( $pt, parse => 'today Z',
	timegm( 0, 0, 0, 1, 6, 109 ),
	q{Parse ISO-8601 'today Z'} );
    time_is( $pt, parse => 'today 9:30Z',
	timegm( 0, 30, 9, 1, 6, 109 ),
	q{Parse ISO-8601 'today 9:30Z'} );
    time_is( $pt, parse => 'tomorrow Z',
	timegm( 0, 0, 0, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow Z'} );
    time_is( $pt, parse => 'tomorrow 9:30Z',
	timegm( 0, 30, 9, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow 9:30Z'} );

    restore_time();
    set_fixed_time( timelocal( 0, 0, 6, 1, 6, 109 ) );

    time_is( $pt, parse => 'yesterday',
	timelocal( 0, 0, 0, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday'} );
    time_is( $pt, parse => 'yesterday 9:30',
	timelocal( 0, 30, 9, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday 9:30'} );
    time_is( $pt, parse => 'today',
	timelocal( 0, 0, 0, 1, 6, 109 ),
	q{Parse ISO-8601 'today'} );
    time_is( $pt, parse => 'today 9:30',
	timelocal( 0, 30, 9, 1, 6, 109 ),
	q{Parse ISO-8601 'today 9:30'} );
    time_is( $pt, parse => 'tomorrow',
	timelocal( 0, 0, 0, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow'} );
    time_is( $pt, parse => 'tomorrow 9:30',
	timelocal( 0, 30, 9, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow 9:30'} );

    restore_time();

}

1;

# ex: set textwidth=72 :
