package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;

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
	plan skip_all =>
	    'Time::y2038 or Time::Local required';
	exit;
    };

    $test_mocktime = eval {
	require Test::MockTime;
	Test::MockTime->import( qw{ restore_time set_fixed_time } );
	1;
    };

    # We have to load My::Module::Test::App this way because it pulls in
    # Astro::App::Satpass2 modules, which in turn may pull in other
    # things (e.g. DateTime) that we want to be affected by
    # Test::MockTime.
    require My::Module::Test::App;
    My::Module::Test::App->import();

}

require_ok 'Astro::App::Satpass2::ParseTime';

class 'Astro::App::Satpass2::ParseTime';

method new => class => 'Astro::App::Satpass2::ParseTime::ISO8601',
    INSTANTIATE, 'Instantiate';

method isa => 'Astro::App::Satpass2::ParseTime::ISO8601', TRUE,
    'Object isa Astro::App::Satpass2::ParseTime::ISO8601';

method isa => 'Astro::App::Satpass2::ParseTime', TRUE,
    'Object isa Astro::App::Satpass2::ParseTime';

method 'delegate',
    'Astro::App::Satpass2::ParseTime::ISO8601',
    'Delegate is Astro::App::Satpass2::ParseTime::ISO8601';


method 'use_perltime', FALSE, 'Does not use perltime';

my $base = timegm( 0, 0, 0, 1, 3, 109 );	# April 1, 2009 GMT;
use constant ONE_DAY => 86400;			# One day, in seconds.
use constant HALF_DAY => 43200;			# 12 hours, in seconds.

method base => $base, TRUE, 'Set base time to 01-Apr-2009 GMT';

method parse => '+0', $base, 'Parse of +0 returns base time';

method parse => '+1', $base + ONE_DAY,
    'Parse of +1 returns one day later than base time';

method parse => '+0', $base + ONE_DAY,
    'Parse of +0 now returns one day later than base time';

method 'reset', TRUE, 'Reset to base time';

method parse => '+0', $base, 'Parse of +0 returns base time again';

method parse => '+0 12', $base + HALF_DAY,
    q{Parse of '+0 12' returns base time plus 12 hours};

method 'reset', TRUE, 'Reset to base time again';

method parse => '-0', $base, 'Parse of -0 returns base time';

method parse => '-0 12', $base - HALF_DAY,
    'Parse of \'-0 12\' returns 12 hours before base time';

method perltime => 1, TRUE, 'Set perltime true';

method parse => '20090101T000000',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000';

method parse => '20090701T000000',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000';

method perltime => 0, TRUE, 'Set perltime false';

method parse => '20090101T000000',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000, no help from perltime';

method parse => '20090701T000000',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000, no help from perltime';

method parse => '20090101T000000Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000Z';

method parse => '20090701T000000Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000Z';

method parse => '20090702162337',
    timelocal( 37, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702162337'};

method parse => '20090702162337Z',
    timegm( 37, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702162337Z'};

method parse => '200907021623',
    timelocal( 0, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '200907021623'};

method parse => '200907021623Z',
    timegm( 0, 23, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '200907021623Z'};

method parse => '2009070216',
    timelocal( 0, 0, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '2009070216'};

method parse => '2009070216Z',
    timegm( 0, 0, 16, 2, 6, 109 ),
    q{Parse ISO-8601 '2009070216Z'};

method parse => '20090702',
    timelocal( 0, 0, 0, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702'};

method parse => '20090702Z',
    timegm( 0, 0, 0, 2, 6, 109 ),
    q{Parse ISO-8601 '20090702Z'};

method parse => '200907',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    q{Parse ISO-8601 '200907'};

method parse => '200907Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    q{Parse ISO-8601 '200907Z'};

method parse => '2009',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009'};

method parse => '2009Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009Z'};

method parse => '19801013T000000Z',
    timegm( 0, 0, 0, 13, 9, 80 ),
    q{Parse ISO-8601 '19801013T000000Z'};

method parse => '20090102162337',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337'};

method parse => '20090102162337Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337Z'};

method parse => '200901021623',
    timelocal( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '200901021623'};

method parse => '200901021623Z',
    timegm( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '200901021623Z'};

method parse => '2009010216',
    timelocal( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009010216'};

method parse => '2009010216Z',
    timegm( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009010216Z'};

method parse => '20090102',
    timelocal( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102'};

method parse => '20090102Z',
    timegm( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102Z'};

method parse => '200901',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '200901'};

method parse => '200901Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '200901Z'};

method parse => '20090102162337+00',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337+00'};

method parse => '20090102162337+0030',
    timegm( 37, 53, 15, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337+0030'};

method parse => '20090102162337+01',
    timegm( 37, 23, 15, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337+01'};

method parse => '20090102162337-0030',
    timegm( 37, 53, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337-0030'};

method parse => '20090102162337-01',
    timegm( 37, 23, 17, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102162337-01'};

method parse => '20090102T162337',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102T162337'};

method parse => '20090102T162337Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '20090102T162337Z'};

method parse => '2009/1/2 16:23:37',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23:37'};

method parse => '2009/1/2 16:23:37 Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23:37 Z'};

method parse => '2009/1/2 16:23',
    timelocal( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23'};

method parse => '2009/1/2 16:23 Z',
    timegm( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16:23 Z'};

method parse => '2009/1/2 16',
    timelocal( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16'};

method parse => '2009/1/2 16 Z',
    timegm( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 16 Z'};

method parse => '2009/1/2',
    timelocal( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2'};

method parse => '2009/1/2 Z',
    timegm( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '2009/1/2 Z'};

method parse => '2009/1',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009/1'};

method parse => '2009/1 Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009/1 Z'};

method parse => '2009',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009'};

method parse => '2009 Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '2009 Z'};

method parse => '09/1/2 16:23:37',
    timelocal( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23:37'};

method parse => '09/1/2 16:23:37 Z',
    timegm( 37, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23:37 Z'};

method parse => '09/1/2 16:23',
    timelocal( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23'};

method parse => '09/1/2 16:23 Z',
    timegm( 0, 23, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16:23 Z'};

method parse => '09/1/2 16',
    timelocal( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16'};

method parse => '09/1/2 16 Z',
    timegm( 0, 0, 16, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 16 Z'};

method parse => '09/1/2',
    timelocal( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2'};

method parse => '09/1/2 Z',
    timegm( 0, 0, 0, 2, 0, 109 ),
    q{Parse ISO-8601 '09/1/2 Z'};

method parse => '09/1',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '09/1'};

method parse => '09/1 Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    q{Parse ISO-8601 '09/1 Z'};

method parse => '12/1/1 fubar',
    undef,
    q{Parse ISO-8601 '12/1/1 fubar' should fail};

SKIP: {

    my $tests = 12;

    $test_mocktime
	or skip 'Unable to load Test::MockTime', $tests;

    set_fixed_time('2009-07-01T06:00:00Z');

    method parse => 'yesterday Z',
	timegm( 0, 0, 0, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday Z'};

    method parse => 'yesterday 9:30Z',
	timegm( 0, 30, 9, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday 9:30Z'};

    method parse => 'today Z',
	timegm( 0, 0, 0, 1, 6, 109 ),
	q{Parse ISO-8601 'today Z'};

    method parse => 'today 9:30Z',
	timegm( 0, 30, 9, 1, 6, 109 ),
	q{Parse ISO-8601 'today 9:30Z'};

    method parse => 'tomorrow Z',
	timegm( 0, 0, 0, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow Z'};

    method parse => 'tomorrow 9:30Z',
	timegm( 0, 30, 9, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow 9:30Z'};

    restore_time();

    set_fixed_time( timelocal( 0, 0, 6, 1, 6, 109 ) );

    method parse => 'yesterday',
	timelocal( 0, 0, 0, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday'};

    method parse => 'yesterday 9:30',
	timelocal( 0, 30, 9, 30, 5, 109 ),
	q{Parse ISO-8601 'yesterday 9:30'};

    method parse => 'today',
	timelocal( 0, 0, 0, 1, 6, 109 ),
	q{Parse ISO-8601 'today'};

    method parse => 'today 9:30',
	timelocal( 0, 30, 9, 1, 6, 109 ),
	q{Parse ISO-8601 'today 9:30'};

    method parse => 'tomorrow',
	timelocal( 0, 0, 0, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow'};

    method parse => 'tomorrow 9:30',
	timelocal( 0, 30, 9, 2, 6, 109 ),
	q{Parse ISO-8601 'tomorrow 9:30'};

    restore_time();

}

SKIP: {
    my $tests = 5;

    load_or_skip 'DateTime', $tests;

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

    method parse => '10661014Z', $dt->epoch(),
	q{Parse ISO-8601 '10661014Z'};

    method parse => '1066ad1014Z', $dt->epoch(),
	q{Parse ISO-8601-ish '1066ad1014Z'};

    $dt = DateTime->new(	# Great fire of Rome
	year	=> 64,
	month	=> 7,
	day	=> 19,
	time_zone	=> 'UTC',
    );

    method parse => '64CE-7-19 Z', $dt->epoch(),
	q{Parse ISO-8601-ish '64CE-7-19 Z'};

    $dt = DateTime->new(	# Asassination of J. Caesar
	year	=> -43,
	month	=> 3,
	day	=> 15,
	time_zone	=> 'UTC',
    );

    method parse => '44BC/3/15 ut', $dt->epoch(),
	q{Parse ISO-8601-ish '44BC/3/15 ut'};

    method parse => '44bce 3 15 gmt', $dt->epoch(),
	q{Parse ISO-8601-ish '44bce 3 15 gmt'};

}

SKIP: {
    my $tests = 6;

    load_or_skip 'DateTime::Calendar::Christian';

    note <<'EOD';

We only do the following if DateTime::Calendar::Christian can be loaded.

EOD

    method new =>
	class		=> 'Astro::App::Satpass2::ParseTime::ISO8601',
	back_end	=> 'Christian',
	INSTANTIATE, 'Instantiate';

    my $dt = DateTime::Calendar::Christian->new(	# Battle of Hastings
	year	=> 1066,
	month	=> 10,
	day	=> 14,
	time_zone	=> 'UTC',
    );

    method parse => '10661014Z', $dt->epoch(),
	q{Parse ISO-8601 '10661014Z'};

    method parse => '1066ad1014Z', $dt->epoch(),
	q{Parse ISO-8601-ish '1066ad1014Z'};

    $dt = DateTime::Calendar::Christian->new(	# Great fire of Rome
	year	=> 64,
	month	=> 7,
	day	=> 19,
	time_zone	=> 'UTC',
    );

    method parse => '64CE-7-19 Z', $dt->epoch(),
	q{Parse ISO-8601-ish '64CE-7-19 Z'};

    $dt = DateTime::Calendar::Christian->new(	# Asassination of J. Caesar
	year	=> -43,	# Year 0 is 1 BC, so 44 BC is year -43.
	month	=> 3,
	day	=> 15,
	time_zone	=> 'UTC',
    );

    method parse => '44 BC/3/15 ut', $dt->epoch(),
	q{Parse ISO-8601-ish '44BC/3/15 ut'};

    method parse => '44bce 3 15 gmt', $dt->epoch(),
	q{Parse ISO-8601-ish '44bce 3 15 gmt'};
	# 1582-10-15T00:00:00

    method new =>
	class		=> 'Astro::App::Satpass2::ParseTime::ISO8601',
	back_end	=> 'Christian,reform_date=uk',
	INSTANTIATE, 'Instantiate';
}


done_testing;

1;

# ex: set textwidth=72 :
