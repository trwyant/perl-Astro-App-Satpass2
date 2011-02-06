package main;

use strict;
use warnings;

use lib qw{ inc };

BEGIN {

    eval {
	require Astro::App::Satpass2::Test::ParseTime;
	Astro::App::Satpass2::Test::ParseTime->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 or greater not available\n";
	exit;
    };

}

my $test_mocktime;

BEGIN {

    # The idea here is that the given directory is assumed to contain a
    # Date::Manip v5 installation that we can use to test the v5 logic
    # on a system with v6 installed in Perl. But we don't want to look
    # in this directory if we're using Test::Without::Module to block
    # Date::Manip, because if we do we will defeat the blockage.

    if ( -d 'date_manip_v5' ) {
	my $forbidden = eval {
	    require Test::Without::Module;
	    Test::Without::Module::get_forbidden_list();
	} || {};

	if ( ! exists $forbidden->{ 'Date::Manip' } ) {
	    require lib;
	    lib->import( 'date_manip_v5' );
	}
    }

    eval {
	require Date::Manip;
	1;
    } or do {
	plan( skip_all => 'Date::Manip not available' );
	exit;
    };

    my $ver = Date::Manip->VERSION();
    Date::Manip->import();
    ( my $test = $ver ) =~ s/ _ //smxg;
    $test < 6 or do {
	plan( skip_all =>
	    "Date::Manip $ver installed; this test is for 5.54 or less"
	);
	exit;
    };

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

plan( tests => 22 );

require_ok( 'Astro::App::Satpass2::ParseTime' );

my $pt = eval {
    Astro::App::Satpass2::ParseTime->new( 'Astro::App::Satpass2::ParseTime::Date::Manip' );
} or diag( 'Failed to instantiate Astro::App::Satpass2::ParseTime: ' . $@ );

isa_ok( $pt, 'Astro::App::Satpass2::ParseTime::Date::Manip::v5' );

isa_ok( $pt, 'Astro::App::Satpass2::ParseTime' );

is( $pt->delegate(),
    'Astro::App::Satpass2::ParseTime::Date::Manip::v5',
    'Delegate is Astro::App::Satpass2::ParseTime::Date::Manip::v5'
);

ok( $pt->use_perltime(), 'Uses perltime' );

time_is( $pt, parse => '20100202T120000Z',
    timegm( 0, 0, 12, 2, 1, 110 ),
    'Parse noon on Groundhog Day 2010', );

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

time_is( $pt, parse => '20090101T000000Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000Z' );

time_is( $pt, parse => '20090701T000000Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000Z' );

1;

# ex: set textwidth=72 :
