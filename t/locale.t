package main;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2::Locale qw{ __localize __preferred };
use Test::More 0.88;	# Because of done_testing();

{
    local $ENV{ASTRO_APP_SATPASS2_CONFIG_DIR} = 't';
    local $ENV{LC_ALL} = 'fu_BAR';

    is __localize( almanac => 'title', 'name' ),
	'Almanac', q{almanac => 'title'};

    ok ! defined scalar __localize( fu => 'bar', undef ),
	q{fu => 'bar' returns nothing};

    is __localize( fu => 'bar', {
	    fu_BAR	=> {
		fu	=> {
		    bar	=> 'bazzle',
		},
	    },
	},
	'whee',
    ), 'bazzle', q{fu => 'bar' works with manual data};

    is __localize( altitude => 'title', 'Robin' ), 'Batman',
	q{altitude => 'title' from user-specific locale file};

    is_deeply __localize( bearing => 'table', [] ),
	[
	    [ qw{ N E S W } ],
	    [ qw{ N NE E SE S SW W NW } ],
	    [ qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW
		NNW } ],
	],
	q{bearing => 'table' returns the correct array reference};

    is __localize( event => 'title', undef ), 'Event',
	q{event => 'title' returns C value};

    is_deeply __localize( event => 'table', [] ), [
	qw{ Larry Moe Shemp Curley } ],
	q{event => 'table' returns fu_BAR data};

    is __localize( event => table => 2, 'Zeppo' ), 'Shemp',
	q{event => table => 2 returns correct array element};

    is_deeply __localize( phase => 'table', [] ),
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

    is __preferred(), 'fu_BAR', 'Preferred locale';
}

done_testing;

1;

# ex: set textwidth=72 :
