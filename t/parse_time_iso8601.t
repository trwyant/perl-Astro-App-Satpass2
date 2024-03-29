package main;

use strict;
use warnings;

# NOTE that this must be loaded BEFORE anything that might actually use
# the time.
use constant TEST_MOCKTIME	=> do {
    local $@ = undef;

    eval {
	require Test::MockTime;
	Test::MockTime->import( qw{ restore_time set_fixed_time } );
	1;
    } || 0;

};

use Astro::App::Satpass2::ParseTime;
use Test2::V0;

use lib qw{ inc };

use My::Module::Test::App;

# >>>> THIS MUST BE DONE BEFORE ANY TESTS <<<<
#
# Note that we rely on check_datetime_timezone_local() returning a true
# value if we're using POSIX rather than DateTime.
check_datetime_timezone_local()
    or skip_all 'Cannot determine local time zone';

dump_zones_init();

klass( 'Astro::App::Satpass2::ParseTime' );

call_m( new => class => 'Astro::App::Satpass2::ParseTime::ISO8601',
    INSTANTIATE, 'Instantiate' );

isa_ok invocant, 'Astro::App::Satpass2::ParseTime::ISO8601';

isa_ok invocant, 'Astro::App::Satpass2::ParseTime';

call_m( 'delegate',
    'Astro::App::Satpass2::ParseTime::ISO8601',
    'Delegate is Astro::App::Satpass2::ParseTime::ISO8601' );


call_m( 'use_perltime', FALSE, 'Does not use perltime' );

my $base = any_greg_time_gm( 0, 0, 0, 1, 3, 2009 );	# April 1, 2009 GMT;
use constant ONE_DAY => 86400;			# One day, in seconds.
use constant HALF_DAY => 43200;			# 12 hours, in seconds.

call_m( base => $base, TRUE, 'Set base time to 01-Apr-2009 GMT' );

call_m( parse => '+0', $base, 'Parse of +0 returns base time' );

call_m( parse => '+1', $base + ONE_DAY,
    'Parse of +1 returns one day later than base time' );

call_m( parse => '+0', $base + ONE_DAY,
    'Parse of +0 now returns one day later than base time' );

call_m( 'reset', TRUE, 'Reset to base time' );

call_m( parse => '+0', $base, 'Parse of +0 returns base time again' );

call_m( parse => '+0 12', $base + HALF_DAY,
    q{Parse of '+0 12' returns base time plus 12 hours} );

call_m( 'reset', TRUE, 'Reset to base time again' );

call_m( parse => '-0', $base, 'Parse of -0 returns base time' );

call_m( parse => '-0 12', $base - HALF_DAY,
    'Parse of \'-0 12\' returns 12 hours before base time' );

call_m( perltime => 1, TRUE, 'Set perltime true' );

my $time_local = any_greg_time_local( 0, 0, 0, 1, 0, 2009 );
call_m( parse => '20090101T000000',
    $time_local,
    'Parse ISO-8601 20090101T000000' )
    or dump_zones( $time_local );

$time_local = any_greg_time_local( 0, 0, 0, 1, 6, 2009 );
call_m( parse => '20090701T000000',
    $time_local,
    'Parse ISO-8601 20090701T000000' )
    or dump_zones( $time_local );

call_m( perltime => 0, TRUE, 'Set perltime false' );

$time_local = any_greg_time_local( 0, 0, 0, 1, 0, 2009 );
call_m( parse => '20090101T000000',
    $time_local,
    'Parse ISO-8601 20090101T000000, no help from perltime' )
    or dump_zones( $time_local );

$time_local = any_greg_time_local( 0, 0, 0, 1, 6, 2009 );
call_m( parse => '20090701T000000',
    $time_local,
    'Parse ISO-8601 20090701T000000, no help from perltime' )
    or dump_zones( $time_local );

my $time_gm = any_greg_time_gm( 0, 0, 0, 1, 0, 2009 );
call_m( parse => '20090101T000000Z',
    $time_gm,
    'Parse ISO-8601 20090101T000000Z' )
    or dump_zones( $time_gm );

$time_gm = any_greg_time_gm( 0, 0, 0, 1, 6, 2009 );
call_m( parse => '20090701T000000Z',
    $time_gm,
    'Parse ISO-8601 20090701T000000Z' )
    or dump_zones( $time_gm );

$time_local = any_greg_time_local( 37, 23, 16, 2, 6, 2009 );
call_m( parse => '20090702T162337',
    $time_local,
    q{Parse ISO-8601 '20090702162337'} )
    or dump_zones( $time_local );

$time_gm = any_greg_time_gm( 37, 23, 16, 2, 6, 2009 );
call_m( parse => '20090702162337Z',
    $time_gm,
    q{Parse ISO-8601 '20090702162337Z'} )
    or dump_zones( $time_gm );

$time_local = any_greg_time_local( 0, 23, 16, 2, 6, 2009 );
call_m( parse => '200907021623',
    $time_local,
    q{Parse ISO-8601 '200907021623'} )
    or dump_zones( $time_local );

call_m( parse => '200907021623Z',
    any_greg_time_gm( 0, 23, 16, 2, 6, 2009 ),
    q{Parse ISO-8601 '200907021623Z'} );

call_m( parse => '2009070216',
    any_greg_time_local( 0, 0, 16, 2, 6, 2009 ),
    q{Parse ISO-8601 '2009070216'} );

call_m( parse => '2009070216Z',
    any_greg_time_gm( 0, 0, 16, 2, 6, 2009 ),
    q{Parse ISO-8601 '2009070216Z'} );

call_m( parse => '20090702',
    any_greg_time_local( 0, 0, 0, 2, 6, 2009 ),
    q{Parse ISO-8601 '20090702'} );

call_m( parse => '20090702Z',
    any_greg_time_gm( 0, 0, 0, 2, 6, 2009 ),
    q{Parse ISO-8601 '20090702Z'} );

call_m( parse => '200907',
    any_greg_time_local( 0, 0, 0, 1, 6, 2009 ),
    q{Parse ISO-8601 '200907'} );

call_m( parse => '200907Z',
    any_greg_time_gm( 0, 0, 0, 1, 6, 2009 ),
    q{Parse ISO-8601 '200907Z'} );

call_m( parse => '2009',
    any_greg_time_local( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '2009'} );

call_m( parse => '2009Z',
    any_greg_time_gm( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '2009Z'} );

call_m( parse => '19801013T000000Z',
    any_greg_time_gm( 0, 0, 0, 13, 9, 1980 ),
    q{Parse ISO-8601 '19801013T000000Z'} );

call_m( parse => '20090102162337',
    any_greg_time_local( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337'} );

call_m( parse => '20090102162337Z',
    any_greg_time_gm( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337Z'} );

call_m( parse => '200901021623',
    any_greg_time_local( 0, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '200901021623'} );

call_m( parse => '200901021623Z',
    any_greg_time_gm( 0, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '200901021623Z'} );

call_m( parse => '2009010216',
    any_greg_time_local( 0, 0, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009010216'} );

call_m( parse => '2009010216Z',
    any_greg_time_gm( 0, 0, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009010216Z'} );

call_m( parse => '20090102',
    any_greg_time_local( 0, 0, 0, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102'} );

call_m( parse => '20090102Z',
    any_greg_time_gm( 0, 0, 0, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102Z'} );

call_m( parse => '200901',
    any_greg_time_local( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '200901'} );

call_m( parse => '200901Z',
    any_greg_time_gm( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '200901Z'} );

call_m( parse => '20090102162337+00',
    any_greg_time_gm( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337+00'} );

call_m( parse => '20090102162337+0030',
    any_greg_time_gm( 37, 53, 15, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337+0030'} );

call_m( parse => '20090102162337+01',
    any_greg_time_gm( 37, 23, 15, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337+01'} );

call_m( parse => '20090102162337-0030',
    any_greg_time_gm( 37, 53, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337-0030'} );

call_m( parse => '20090102162337-01',
    any_greg_time_gm( 37, 23, 17, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102162337-01'} );

call_m( parse => '20090102T162337',
    any_greg_time_local( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102T162337'} );

call_m( parse => '20090102T162337Z',
    any_greg_time_gm( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '20090102T162337Z'} );

call_m( parse => '2009/1/2 16:23:37',
    any_greg_time_local( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 16:23:37'} );

call_m( parse => '2009/1/2 16:23:37 Z',
    any_greg_time_gm( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 16:23:37 Z'} );

call_m( parse => '2009/1/2 16:23',
    any_greg_time_local( 0, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 16:23'} );

call_m( parse => '2009/1/2 16:23 Z',
    any_greg_time_gm( 0, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 16:23 Z'} );

call_m( parse => '2009/1/2 16',
    any_greg_time_local( 0, 0, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 16'} );

call_m( parse => '2009/1/2 16 Z',
    any_greg_time_gm( 0, 0, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 16 Z'} );

call_m( parse => '2009/1/2',
    any_greg_time_local( 0, 0, 0, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2'} );

call_m( parse => '2009/1/2 Z',
    any_greg_time_gm( 0, 0, 0, 2, 0, 2009 ),
    q{Parse ISO-8601 '2009/1/2 Z'} );

call_m( parse => '2009/1',
    any_greg_time_local( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '2009/1'} );

call_m( parse => '2009/1 Z',
    any_greg_time_gm( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '2009/1 Z'} );

call_m( parse => '2009',
    any_greg_time_local( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '2009'} );

call_m( parse => '2009 Z',
    any_greg_time_gm( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '2009 Z'} );

call_m( parse => '09/1/2 16:23:37',
    any_greg_time_local( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 16:23:37'} );

call_m( parse => '09/1/2 16:23:37 Z',
    any_greg_time_gm( 37, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 16:23:37 Z'} );

call_m( parse => '09/1/2 16:23',
    any_greg_time_local( 0, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 16:23'} );

call_m( parse => '09/1/2 16:23 Z',
    any_greg_time_gm( 0, 23, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 16:23 Z'} );

call_m( parse => '09/1/2 16',
    any_greg_time_local( 0, 0, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 16'} );

call_m( parse => '09/1/2 16 Z',
    any_greg_time_gm( 0, 0, 16, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 16 Z'} );

call_m( parse => '09/1/2',
    any_greg_time_local( 0, 0, 0, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2'} );

call_m( parse => '09/1/2 Z',
    any_greg_time_gm( 0, 0, 0, 2, 0, 2009 ),
    q{Parse ISO-8601 '09/1/2 Z'} );

call_m( parse => '09/1',
    any_greg_time_local( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '09/1'} );

call_m( parse => '09/1 Z',
    any_greg_time_gm( 0, 0, 0, 1, 0, 2009 ),
    q{Parse ISO-8601 '09/1 Z'} );

SKIP: {

    my $tests = 12;

    if ( TEST_MOCKTIME ) {

	set_fixed_time('2009-07-01T06:00:00Z');

	call_m( parse => 'yesterday Z',
	    any_greg_time_gm( 0, 0, 0, 30, 5, 2009 ),
	    q{Parse ISO-8601 'yesterday Z'} );

	call_m( parse => 'yesterday 9:30Z',
	    any_greg_time_gm( 0, 30, 9, 30, 5, 2009 ),
	    q{Parse ISO-8601 'yesterday 9:30Z'} );

	call_m( parse => 'today Z',
	    any_greg_time_gm( 0, 0, 0, 1, 6, 2009 ),
	    q{Parse ISO-8601 'today Z'} );

	call_m( parse => 'today 9:30Z',
	    any_greg_time_gm( 0, 30, 9, 1, 6, 2009 ),
	    q{Parse ISO-8601 'today 9:30Z'} );

	call_m( parse => 'tomorrow Z',
	    any_greg_time_gm( 0, 0, 0, 2, 6, 2009 ),
	    q{Parse ISO-8601 'tomorrow Z'} );

	call_m( parse => 'tomorrow 9:30Z',
	    any_greg_time_gm( 0, 30, 9, 2, 6, 2009 ),
	    q{Parse ISO-8601 'tomorrow 9:30Z'} );

	restore_time();

	set_fixed_time( any_greg_time_local( 0, 0, 6, 1, 6, 2009 ) );

	call_m( parse => 'yesterday',
	    any_greg_time_local( 0, 0, 0, 30, 5, 2009 ),
	    q{Parse ISO-8601 'yesterday'} );

	call_m( parse => 'yesterday 9:30',
	    any_greg_time_local( 0, 30, 9, 30, 5, 2009 ),
	    q{Parse ISO-8601 'yesterday 9:30'} );

	call_m( parse => 'today',
	    any_greg_time_local( 0, 0, 0, 1, 6, 2009 ),
	    q{Parse ISO-8601 'today'} );

	call_m( parse => 'today 9:30',
	    any_greg_time_local( 0, 30, 9, 1, 6, 2009 ),
	    q{Parse ISO-8601 'today 9:30'} );

	call_m( parse => 'tomorrow',
	    any_greg_time_local( 0, 0, 0, 2, 6, 2009 ),
	    q{Parse ISO-8601 'tomorrow'} );

	call_m( parse => 'tomorrow 9:30',
	    any_greg_time_local( 0, 30, 9, 2, 6, 2009 ),
	    q{Parse ISO-8601 'tomorrow 9:30'} );

	restore_time();

    } else {

	skip 'Unable to load Test::MockTime', $tests;

    }

}

SKIP: {
    my $tests = 5;

    load_or_skip( 'DateTime', $tests );

    note <<'EOD';

We only do the following if DateTime can be loaded, because Time::Local
does strange things with long-past dates.

Yes, we're using the Gregorian calendar for dates that really should be
Julian, but for the moment we're stuck with that.

EOD

    my $dt = DateTime->new(	# Battle of Hastings
	year	=> 1066,
	month	=> 10,
	day	=> 14,
	time_zone	=> 'UTC',
    );

    call_m( parse => '10661014Z', $dt->epoch(),
	q{Parse ISO-8601 '10661014Z'} );

    call_m( parse => '1066ad1014Z', $dt->epoch(),
	q{Parse ISO-8601-ish '1066ad1014Z'} );

    $dt = DateTime->new(	# Great fire of Rome
	year	=> 64,
	month	=> 7,
	day	=> 19,
	time_zone	=> 'UTC',
    );

    call_m( parse => '64CE-7-19 Z', $dt->epoch(),
	q{Parse ISO-8601-ish '64CE-7-19 Z'} );

    $dt = DateTime->new(	# Asassination of J. Caesar
	year	=> -43,
	month	=> 3,
	day	=> 15,
	time_zone	=> 'UTC',
    );

    call_m( parse => '44BC/3/15 ut', $dt->epoch(),
	q{Parse ISO-8601-ish '44BC/3/15 ut'} );

    call_m( parse => '44bce 3 15 gmt', $dt->epoch(),
	q{Parse ISO-8601-ish '44bce 3 15 gmt'} );

}

SKIP: {
    my $tests = 6;

    load_or_skip( 'DateTime::Calendar::Christian', $tests );

    note <<'EOD';

We only do the following if DateTime::Calendar::Christian can be loaded.

EOD

    call_m( new =>
	class		=> 'Astro::App::Satpass2::ParseTime::ISO8601',
	back_end	=> 'Christian',
	INSTANTIATE, 'Instantiate' );

    my $dt = DateTime::Calendar::Christian->new(	# Battle of Hastings
	year	=> 1066,
	month	=> 10,
	day	=> 14,
	time_zone	=> 'UTC',
    );

    call_m( parse => '10661014Z', $dt->epoch(),
	q{Parse ISO-8601 '10661014Z'} );

    call_m( parse => '1066ad1014Z', $dt->epoch(),
	q{Parse ISO-8601-ish '1066ad1014Z'} );

    $dt = DateTime::Calendar::Christian->new(	# Great fire of Rome
	year	=> 64,
	month	=> 7,
	day	=> 19,
	time_zone	=> 'UTC',
    );

    call_m( parse => '64CE-7-19 Z', $dt->epoch(),
	q{Parse ISO-8601-ish '64CE-7-19 Z'} );

    $dt = DateTime::Calendar::Christian->new(	# Asassination of J. Caesar
	year	=> -43,	# Year 0 is 1 BC, so 44 BC is year -43.
	month	=> 3,
	day	=> 15,
	time_zone	=> 'UTC',
    );

    call_m( parse => '44 BC/3/15 ut', $dt->epoch(),
	q{Parse ISO-8601-ish '44BC/3/15 ut'} );

    call_m( parse => '44bce 3 15 gmt', $dt->epoch(),
	q{Parse ISO-8601-ish '44bce 3 15 gmt'} );
	# 1582-10-15T00:00:00

    call_m( new =>
	class		=> 'Astro::App::Satpass2::ParseTime::ISO8601',
	back_end	=> 'Christian,reform_date=uk',
	INSTANTIATE, 'Instantiate' );
}


done_testing;

1;

# ex: set textwidth=72 :
