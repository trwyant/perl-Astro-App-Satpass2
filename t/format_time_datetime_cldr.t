package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.52 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.52 required\\n";
	exit;
    }
}

BEGIN {
    eval {
	require lib;
	lib->import( 'inc' );
	require Astro::App::Satpass2::Test::App;
	Astro::App::Satpass2::Test::App->import();
	1;
    } or do {
	plan skip_all => 'Astro::App::Satpass2::Test::App not available';
	exit;
    };
}

BEGIN {
    eval {
	require DateTime;
	require DateTime::TimeZone;
	1;
    } or do {
	plan skip_all => 'DateTime or DateTime::TimeZone not available';
	exit;
    };
}

BEGIN {
    eval {
	require Time::Local;
	Time::Local->import();
	1;
    } or do {
	plan skip_all => 'Time::Local not available';
	exit;
    };
}

plan tests => 15;

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

method 'new', undef, 'Instantiate';

method gmt => 1, undef, 'Turn on gmt attribute';

method 'gmt', 1, 'The gmt attribute is on';

my $time = timegm( 0, 0, 0, 1, 3, 111 );	# midnight 1-Apr-2011

method format_datetime => 'yyyy/MM/dd HH:mm:SS', $time,
    '2011/04/01 00:00:00', 'Implicit GMT time';

method format_datetime_width => 'yyyy/MM/dd HH:mm:SS', 19,
    'Compute width required for format';

method gmt => 0, undef, 'Turn off gmt';

method format_datetime => 'yyyy/MM/dd HH:mm:SS', $time, 1,
    '2011/04/01 00:00:00', 'Explicit GMT time';

1;

# ex: set textwidth=72 :
