package main;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2;
use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::Utils qw{ deg2rad greg_time_gm };
use Test::More 0.88;	# Because of done_testing();

use constant CLASS	=> 'Astro::App::Satpass2';

my $greenwich = Astro::Coord::ECI->new()->geodetic(
    deg2rad( 51.4772 ),
    deg2rad( 0 ),
    0,
);
my @tle = Astro::Coord::ECI::TLE->parse(
    slurp( 't/data.tle' ),
);
$_->set( station => $greenwich ) for @tle;
my $sun = $tle[0]->get( 'illum' );

my $pass = {
    body	=> $tle[0],
    time	=> greg_time_gm( 0, 0, 0, 1, 3, 2023 ),
};
my @almanac_am = (
    {
	body	=> $sun,
	status	=> 'begin twilight',
	time	=> greg_time_gm( 23, 2, 5, 1, 3, 2023 ),
    },
    {
	body	=> $sun,
	status	=> 'Sunrise',
	time	=> greg_time_gm( 10, 36, 5, 1, 3, 2023 ),
    },
);
my @almanac_pm = (
    {
	body	=> $sun,
	status	=> 'Sunset',
	time	=> greg_time_gm( 47, 32, 18, 1, 3, 2023 ),
    },
    {
	body	=> $sun,
	status	=> 'end twilight',
	time	=> greg_time_gm( 42, 6, 19, 1, 3, 2023 ),
    },
);

my $sp = CLASS->new();
$sp->get( 'formatter' )->gmt( 1 );

is_deeply [ $sp->__pass_almanac( $pass ) ],
[ @almanac_am, @almanac_pm ],
'Almanac for Greenwich, 01-Apr-2023';

is_deeply [ $sp->__pass_almanac( $pass, {
	    am	=> 1,
	    pm	=> 1,
	},
    ) ],
[ @almanac_am, @almanac_pm ],
'Almanac for Greenwich, AM and PM, 01-Apr-2023';

is_deeply [ $sp->__pass_almanac( $pass, {
	    am	=> 1,
	    pm	=> 0,
	},
    ) ],
[ @almanac_am ],
'Almanac for Greenwich, AM only, 01-Apr-2023';

is_deeply [ $sp->__pass_almanac( $pass, {
	    am	=> 0,
	    pm	=> 1,
	},
    ) ],
[ @almanac_pm ],
'Almanac for Greenwich, PM only, 01-Apr-2023';

done_testing;

sub slurp {
    my ( $fn ) = @_;
    open my $fh, '<', $fn
	or die "Failed to open $fn: $!\n";
    local $/ = undef;
    return <$fh>;
}

1;

# ex: set textwidth=72 :
