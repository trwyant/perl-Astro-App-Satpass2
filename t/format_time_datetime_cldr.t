package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

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
}

require_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' => 'new';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' => 'attribute_names';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' => 'copy';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' => 'gmt';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' => 'format_datetime';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' =>
	'format_datetime_width';

can_ok 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' => 'tz';

class 'Astro::App::Satpass2::FormatTime::DateTime::Cldr';

method 'new', INSTANTIATE, 'Instantiate';

method gmt => 1, TRUE, 'Turn on gmt attribute';

method 'gmt', 1, 'The gmt attribute is on';

my $time = timegm( 0, 0, 0, 1, 3, 111 );	# midnight 1-Apr-2011

method format_datetime => 'yyyy/MM/dd HH:mm:SS', $time,
    '2011/04/01 00:00:00', 'Implicit GMT time';

method format_datetime_width => 'yyyy/MM/dd HH:mm:SS', 19,
    'Compute width required for format';

method gmt => 0, TRUE, 'Turn off gmt';

method format_datetime => 'yyyy/MM/dd HH:mm:SS', $time, 1,
    '2011/04/01 00:00:00', 'Explicit GMT time';

done_testing;

1;

# ex: set textwidth=72 :
