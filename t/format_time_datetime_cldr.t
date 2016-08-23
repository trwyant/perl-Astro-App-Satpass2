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

    require Astro::App::Satpass2::FormatTime::DateTime::Cldr;
}

use constant DATE_TIME_FORMAT => 'yyyy/MM/dd HH:mm:ss';

class 'Astro::App::Satpass2::FormatTime::DateTime::Cldr';

method 'new', INSTANTIATE, 'Instantiate';

method gmt => 1, TRUE, 'Turn on gmt attribute';

method 'gmt', 1, 'The gmt attribute is on';

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

method format_datetime => q<'%{calendar_name}'>, 1,
    'Gregorian', 'Calendar name';

SKIP: {
    my $tests = 2;

    eval {
	require DateTime::Calendar::Christian;
	1;
    } or skip 'DateTime::Calendar::Christian not available', 1;

    method 'new', reform_date => 'dflt', gmt => 1, INSTANTIATE, 'Instantiate';

    SKIP: {

	my $dt = DateTime::Calendar::Christian->new(
	    year		=> -43,
	    month		=> 3,
	    day		=> 15,
	    time_zone	=> 'UTC',
	);

	$dt->is_julian()
	    or skip 'DateTime::Calendar::Christian thinks date is not Julian', $tests;

	method format_datetime =>
	    q<'%{year_with_christian_era:06}'-MM-dd '%{calendar_name:t3}'>,
	    $dt->epoch(), '0044BC-03-15 Jul',
	    'Method and Julian calendar name';
    }

}

done_testing;

1;

# ex: set textwidth=72 :
