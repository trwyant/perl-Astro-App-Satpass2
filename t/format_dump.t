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

plan tests => 18;

require_ok 'Astro::App::Satpass2::Format::Dump';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'new';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'date_format';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'gmt';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'local_coord';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'provider';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'time_format';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'almanac';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'flare';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'list';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'location';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'pass';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'pass_events';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'phase';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'position';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'tle';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'tle_verbose';

class 'Astro::App::Satpass2::Format::Dump';

SKIP: {

    my $tests = 1;

    eval {
	require Data::Dumper;
	1;
    } or skip 'Data::Dumper not available', $tests ;

    method 'new', undef, 'Instantiate';

}

1;

# ex: set textwidth=72 :
