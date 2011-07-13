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

plan tests => 9;

require_ok 'Astro::App::Satpass2::Format::Dump';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'new';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'date_format';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'gmt';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'local_coord';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'provider';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'time_format';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'format';

class 'Astro::App::Satpass2::Format::Dump';

SKIP: {

    my $tests = 1;

    eval {
	require Data::Dumper;
	1;
    } or skip 'Data::Dumper not available', $tests ;

    method 'new', INSTANTIATE, 'Instantiate';

}

1;

# ex: set textwidth=72 :
