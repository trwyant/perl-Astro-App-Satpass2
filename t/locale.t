package main;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2::Locale qw{ __localize __preferred };
use Test::More 0.88;	# Because of done_testing();

{
    local $ENV{ASTRO_APP_SATPASS2_CONFIG_DIR} = 't';
    my @lang_env = qw{ LC_ALL LC_MESSAGE LANG LANGUAGE };
    local @ENV{ @lang_env } = ( 'fu_BAR' ) x scalar @lang_env;

    is scalar __localize( almanac => 'title', 'name' ),
	'Almanac', q{almanac => 'title'};

    ok ! defined scalar __localize( fu => 'bar', undef ),
	q{fu => 'bar' returns nothing};

    is scalar __localize( fu => 'bar', {
	    fu_BAR	=> {
		fu	=> {
		    bar	=> 'bazzle',
		},
	    },
	},
	'whee',
    ), 'bazzle', q{fu => 'bar' works with manual data};

    is scalar __localize( altitude => 'title', 'Robin' ), 'Batman',
	q{altitude => 'title' from user-specific locale file};

    is_deeply [ __localize( altitude => 'title', 'Robin' ) ],
	[ 'Batman', 'Altitude', 'Robin' ],
	q{altitude => 'title' in list context};

    is_deeply scalar __localize( bearing => 'table', [] ),
	[
	    [ qw{ N E S W } ],
	    [ qw{ N NE E SE S SW W NW } ],
	    [ qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW
		NNW } ],
	],
	q{bearing => 'table' returns the correct array reference};

    is scalar __localize( event => 'title', undef ), 'Event',
	q{event => 'title' returns C value};

    is_deeply scalar __localize( event => 'table', [] ), [
	qw{ Larry Moe Shemp Curley } ],
	q{event => 'table' returns fu_BAR data};

    is scalar __localize( event => table => 2, 'Zeppo' ), 'Shemp',
	q{event => table => 2 returns correct array element};

    is_deeply scalar __localize( phase => 'table', [] ),
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

    is scalar __preferred(), 'fu_BAR', 'Preferred locale';

    note <<'EOD';

It appears from CPAN Testers results that under Perl 5.20 and MSWin32
the array returned by __preferred() in list context is ( 'fu_BAR', 'C').
This seems wrong to me, but since I have no way to trouble shoot it I
will simply have to live with it.
EOD

    my @pref = __preferred();

    is $pref[0], 'fu_BAR', q<First preferred locale is 'fu_BAR'>;

    @pref > 2
	and is $pref[1], 'fu', q<Second preferred locale is 'fu'>;

    is $pref[-1], 'C', q<Last preferred locale is 'C'>;
}

done_testing;

1;

# ex: set textwidth=72 :
