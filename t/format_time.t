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

plan tests => 13;

require_ok 'Astro::App::Satpass2::FormatTime';

can_ok 'Astro::App::Satpass2::FormatTime' => 'new';

can_ok 'Astro::App::Satpass2::FormatTime' => 'attribute_names';

can_ok 'Astro::App::Satpass2::FormatTime' => 'copy';

can_ok 'Astro::App::Satpass2::FormatTime' => 'gmt';

can_ok 'Astro::App::Satpass2::FormatTime' => 'format_datetime_width';

can_ok 'Astro::App::Satpass2::FormatTime' => 'tz';

class 'Astro::App::Satpass2::FormatTime';

method 'new', undef, 'Instantiate Astro::App::Satpass2::FormatTime';

method gmt => 1, undef, 'Turn on gmt';

method 'gmt', 1, 'Confirm gmt is on';

method format_datetime_width => '', 0, 'Width of null template';

method format_datetime_width => 'foo', 3,
    'Width of constant template';

method format_datetime_width => 'foo%%bar', 7,
    'Width of template with literal percent';

1;

# ex: set textwidth=72 :
