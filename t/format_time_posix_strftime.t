package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

BEGIN {
    eval {
	require POSIX;
	POSIX->import( 'strftime' );
	1;
    } or do {
	plan skip_all => 'POSIX strftime() not available';
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

    require Astro::App::Satpass2::FormatTime::POSIX::Strftime;
}

use constant DATE_TIME_FORMAT => '%Y/%m/%d %H:%M:%S';

class 'Astro::App::Satpass2::FormatTime::POSIX::Strftime';

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

done_testing;

1;

# ex: set textwidth=72 :
