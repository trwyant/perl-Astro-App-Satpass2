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
}

require_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' => 'new';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' => 'attribute_names';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' => 'copy';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' => 'gmt';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' => 'format_datetime';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' =>
	'format_datetime_width';

can_ok 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' => 'tz';

class 'Astro::App::Satpass2::FormatTime::POSIX::Strftime';

method 'new', INSTANTIATE, 'Instantiate';

method gmt => 1, TRUE, 'Turn on gmt';

method 'gmt', 1, 'Confirm gmt is on';

my $time = timegm( 0, 0, 0, 1, 3, 111 );	# midnight 1-Apr-2011

method format_datetime => '%Y/%m/%d %H:%M:%S', $time,
    '2011/04/01 00:00:00', 'Implicit GMT time';

method format_datetime_width => '%Y/%m/%d %H:%M:%S', 19,
    'Compute width required for format';

method gmt => 0, TRUE, 'Turn off gmt';

method format_datetime => '%Y/%m/%d %H:%M:%S', $time, 1,
    '2011/04/01 00:00:00', 'Explicit GMT time';

done_testing;

1;

# ex: set textwidth=72 :
