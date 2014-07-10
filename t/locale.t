package main;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2::Locale qw{ __locale };
use Test::More 0.88;	# Because of done_testing();

{
    local $ENV{ASTRO_APP_SATPASS2_CONFIG_DIR} = 't';
    local $ENV{LC_ALL} = 'fu_BAR';

    is __locale( almanac => 'title' ), 'Almanac', q{almanac => 'title'};

    ok ! defined scalar __locale( fu => 'bar' ),
	q{fu => 'bar' returns nothing};

    is __locale( fu => 'bar', {
	    fu_BAR	=> {
		fu	=> {
		    bar	=> 'bazzle',
		},
	    },
	},
    ), 'bazzle', q{fu => 'bar' works with manual data};

    ok ! defined scalar __locale( fu => 'bar', undef ),
	q{fu => 'bar' ignores non-hash extra arguments};

    is __locale( altitude => 'title' ), 'Batman',
	q{altitude => 'title' from user-specific locale file};

    is_deeply __locale( bearing => 'table' ),
	[
	    [ qw{ N E S W } ],
	    [ qw{ N NE E SE S SW W NW } ],
	    [ qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW
		NNW } ],
	],
	q{bearing => 'table' returns the correct array reference};

    is __locale( event => 'title' ), 'Event',
	q{event => 'title' returns C value};

    is_deeply __locale( event => 'table' ), [
	qw{ Larry Moe Shemp Curley } ],
	q{event => 'table' returns fu_BAR data};

    is_deeply __locale( phase => 'table' ),
	[
	    [ 6.1	=> 'new' ],
	    [ 83.9	=> 'waxing crescent' ],
	    [ 96.1	=> 'first quarter' ],
	    [ 173.9	=> 'waxing gibbous' ],
	    [ 186.1	=> 'full' ],
	    [ 263.9	=> 'waning gibbous' ],
	    [ 276.1	=> 'last quarter' ],
	    [ 353.9	=> 'waning crescent' ],
	],
	q{phase => 'table' returns the correct array reference};
}

done_testing;

1;

# ex: set textwidth=72 :
