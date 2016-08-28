package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use My::Module::Test::App;

BEGIN {
    eval {
	require DateTime;
	require DateTime::TimeZone;
	1;
    } or do {
	plan skip_all => 'DateTime or DateTime::TimeZone not available';
	exit;
    };

    eval {
	require Time::Local;
	Time::Local->import();
	1;
    } or do {
	plan skip_all => 'Time::Local not available';
	exit;
    };

    require Astro::App::Satpass2::FormatTime::DateTime::Strftime;
}

use constant DATE_TIME_FORMAT => '%Y/%m/%d %H:%M:%S';

class 'Astro::App::Satpass2::FormatTime::DateTime::Strftime';

method 'new', INSTANTIATE, 'Instantiate';

method gmt => 1, TRUE, 'Turn on gmt';

method 'gmt', 1, 'Confirm gmt is on';

my $time = timegm( 50, 0, 0, 1, 3, 111 );	# 1-Apr-2011 00:00:50

method format_datetime => DATE_TIME_FORMAT, $time,
    '2011/04/01 00:00:50', 'Implicit GMT time';

method format_datetime_width => DATE_TIME_FORMAT, 19,
    'Compute width required for format';

method gmt => 0, TRUE, 'Turn off gmt';

method format_datetime => DATE_TIME_FORMAT, $time, 1,
    '2011/04/01 00:00:50', 'Explicit GMT time';

method round_time => 60, TRUE, 'Round to nearest minute';

method format_datetime => DATE_TIME_FORMAT, $time, 1,
    '2011/04/01 00:01:00', 'Explicit GMT time, rounded to minute';

method format_datetime => '%{year_with_christian_era} %{calendar_name}',
    $time, 1, '2011AD Gregorian', 'Explicit GMT year, with calendar';

SKIP: {
    my $tests = 5;

    eval {
	require DateTime::Calendar::Christian;
	1;
    } or skip 'DateTime::Calendar::Christian not available', $tests;


    method 'new', reform_date => 'dflt', gmt => 1, INSTANTIATE, 'Instantiate';

    my $dt = DateTime::Calendar::Christian->new(
	year	=> -43,
	month	=> 3,
	day	=> 15,
	time_zone	=> 'UTC',
    );

    SKIP: {
	$dt->is_julian()
	    or skip 'DateTime::Calendar::Christian 44BC not Julian(?!)', 1;

	method format_datetime =>
	    '%{year_with_christian_era:06}-%m-%d %{calendar_name:t3}',
	    $dt->epoch(), '0044BC-03-15 Jul', 'Julian date, with era';
    }

    $dt = DateTime::Calendar::Christian->new(
	year	=> 1700,
	month	=> 1,
	day	=> 1,
	time_zone	=> 'UTC',
	reform_date	=> 'uk',
    );

    method 'new', reform_date => 'dflt', gmt => 1, reform_date => 'uk',
	INSTANTIATE, 'Instantiate';

    method reform_date => 'uk', 'Get reform date';

    SKIP: {
	$dt->is_julian()
	    or skip 'DateTime::Calendar::Christian 1700 not Julian under UK reform', 1;
	method format_datetime =>
	    '%Y-%m-%d %{calendar_name}',
	    $dt->epoch(), '1700-01-01 Julian', 'UK reform Julian date';
    }
}

done_testing;

1;

# ex: set textwidth=72 :
