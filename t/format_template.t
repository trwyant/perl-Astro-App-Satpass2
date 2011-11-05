package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;

use Astro::App::Satpass2::Format::Template;
use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Astro::Coord::ECI::Sun;
use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::TLE::Iridium;
use Astro::Coord::ECI::Utils qw{ deg2rad };
use Time::Local;

my $sta = Astro::Coord::ECI->new()->geodetic(
    deg2rad( 38.898748 ),
    deg2rad( -77.037684 ),
    16.68 / 1000,
)->set( name => '1600 Pennsylvania Ave NW Washington DC 20502' );
my $sun = Astro::Coord::ECI::Sun->new();
my $moon = Astro::Coord::ECI::Moon->new();
# The following TLE is from
# SPACETRACK REPORT NO. 3
# Models for Propagation of NORAD Element Sets
# Felix R. Hoots and Ronald L. Roehrich
# December 1980
# Compiled by TS Kelso
# 31 December 1988
# Obtained from celestrak.com
# NASA line added by T. R. Wyant
my ( $sat ) = Astro::Coord::ECI::TLE->parse( <<'EOD' );
None
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
EOD

$sat->rebless( 'iridium' );

my $ft = Astro::App::Satpass2::Format::Template->new()->gmt( 1 );

ok $ft, 'Instantiate Astro::App::Satpass2::Format::Template';

is $ft->format(
    template	=> 'almanac',
    data	=> [ {
		almanac	=> {
		    description	=> 'Moon rise',
		    detail		=> 1,
		    event		=> 'horizon',
		},
		body	=> $moon,
		station	=> $sta,
		time	=> timegm( 8, 38, 9, 1, 3, 111 ),
	    },
	    {
		almanac	=> {
		    description	=> 'Moon transits meridian',
		    detail		=> 1,
		    event		=> 'transit',
		},
		body	=> $moon,
		station	=> $sta,
		time	=> timegm( 20, 46, 15, 1, 3, 111 ),
	    },
	    {
		almanac	=> {
		    description	=> 'Moon set',
		    detail		=> 0,
		    event		=> 'horizon',
		},
		body	=> $moon,
		station	=> $sta,
		time	=> timegm( 40, 2, 22, 1, 3, 111 ),
	    },
	] ), <<'EOD', 'Almanac';
2011-04-01 09:38:08 Moon rise
2011-04-01 15:46:20 Moon transits meridian
2011-04-01 22:02:40 Moon set
EOD

is $ft->format(
    template	=> 'flare',
    data	=> [
	    {
		angle => 0.262059013150469,
		appulse => {
		    angle => 1.02611236331053,
		    body => $sun,
		},
		area => 5.01492326975883e-12,
		azimuth => 2.2879991425019,
		body => $sat,
		center => {
		    body => Astro::Coord::ECI->new()->eci(
			-239.816850881829,
			4844.88846601786,
			4147.86073518313,
		    ),
		    magnitude => -9.19948076848716,
		},
		elevation => 0.494460647040746,
		magnitude => 3.92771062285379,
		mma => 0,
		range => 410.943432358706,
		specular => 0,
		station => $sta,
		status => '',
		time => timegm( 44, 7, 10, 13, 9, 80 ) + .606786,
		type => 'am',
		virtual_image => Astro::Coord::ECI->new()->eci(
		    -126704974.030369,
		    66341250.3306362,
		    -42588590.3666171,
		),
	    },
	] ), <<'EOD', 'Flare';
Time     Name         Eleva  Azimuth      Range Magn Degre   Center Center
                                                      From  Azimuth  Range
                                                       Sun
1980-10-13
10:07:45 None          28.3 131.1 SE      410.9  3.9 night 300.8 NW  412.5
EOD

is $ft->format(
    template	=> 'list',
    data	=> [ $sat ]
), <<'EOD', 'List';
   OID Name                     Epoch               Period
 88888 None                     1980-10-01 23:41:24 01:29:37
EOD

is $ft->format(
    template	=> 'location',
    data	=> $sta
), <<'EOD', 'Location';
Location: 1600 Pennsylvania Ave NW Washington DC 20502
          Latitude 38.8987, longitude -77.0377, height 17 m
EOD

is $ft->format(
    template	=> 'pass',
    data	=> [
	    {
		body	=> $sat,
		events	=> [
		    {
			azimuth => 2.72679983099103,
			body => $sat,
			elevation => 0.350867451859261,
			event => PASS_EVENT_RISE,
			illumination => PASS_EVENT_LIT,
			range => 537.930341183133,
			station => $sta,
			time	=> timegm( 14, 7, 10, 13, 9, 80 ),
		    },
		    {
			azimuth => 1.95627424522813,
			body => $sat,
			elevation => 0.535869703007124,
			event => PASS_EVENT_MAX,
			illumination => PASS_EVENT_LIT,
			range => 385.864099675914,
			station => $sta,
			time => timegm( 0, 8, 10, 13, 9, 80 ),
		    },
		    {
			azimuth => 0.988652345285029,
			body => $sat,
			elevation => 0.344817448574959,
			event => PASS_EVENT_SET,
			illumination => PASS_EVENT_LIT,
			range => 552.731309464471,
			station => $sta,
			time => timegm( 56, 8, 10, 13, 9, 80 ),
		    },
		],
		time => timegm( 0, 8, 10, 13, 9, 80 ),
	    },
	] ), <<'EOD', 'Pass';
    Time Eleva  Azimuth      Range Latitude Longitude Altitud Illum Event

1980-10-13     88888 - None
10:07:14  20.1 156.2 SE      537.9  34.8367  -74.8798   204.0 lit   rise
10:08:00  30.7 112.1 E       385.9  37.7599  -73.6545   205.2 lit   max
10:08:56  19.8  56.6 NE      552.7  41.2902  -72.0053   207.0 lit   set
EOD

is $ft->format(
    template	=> 'pass_events',
    data	=> [
	    {
		body	=> $sat,
		events	=> [
		    {
			azimuth => 2.72679983099103,
			body => $sat,
			elevation => 0.350867451859261,
			event => PASS_EVENT_RISE,
			illumination => PASS_EVENT_LIT,
			range => 537.930341183133,
			station => $sta,
			time	=> timegm( 14, 7, 10, 13, 9, 80 ),
		    },
		    {
			azimuth => 1.95627424522813,
			body => $sat,
			elevation => 0.535869703007124,
			event => PASS_EVENT_MAX,
			illumination => PASS_EVENT_LIT,
			range => 385.864099675914,
			station => $sta,
			time => timegm( 0, 8, 10, 13, 9, 80 ),
		    },
		    {
			azimuth => 0.988652345285029,
			body => $sat,
			elevation => 0.344817448574959,
			event => PASS_EVENT_SET,
			illumination => PASS_EVENT_LIT,
			range => 552.731309464471,
			station => $sta,
			time => timegm( 56, 8, 10, 13, 9, 80 ),
		    },
		],
		time => timegm( 0, 8, 10, 13, 9, 80 ),
	    },
	] ), <<'EOD', 'Pass';
Date       Time     OID    Event Illum Eleva  Azimuth      Range
1980-10-13 10:07:14  88888 rise  lit    20.1 156.2 SE      537.9
1980-10-13 10:08:00  88888 max   lit    30.7 112.1 E       385.9
1980-10-13 10:08:56  88888 set   lit    19.8  56.6 NE      552.7
EOD

$moon->universal( timegm( 0, 0, 4, 1, 3, 111 ) );
is $ft->format(
    template	=> 'phase',
    data	=> [ { body => $moon, time => $moon->universal() } ]
), <<'EOD', 'Phase';
      Date     Time     Name Phas Phase             Lit
2011-04-01 04:00:00     Moon  333 waning crescent     5%
EOD

is $ft->format(
    template	=> 'position',
    data	=> {
	    bodies	=> [ $sat, $moon ],
	    station	=> $sta,
	    time	=> timegm( 45, 7, 10, 13, 9, 80 ),
	} ), <<'EOD', 'Position';
1980-10-13 10:07:45
            Name Eleva  Azimuth      Range               Epoch Illum
            None  28.4 130.7 SE      409.9 1980-10-01 23:41:24 lit
                                           MMA 0 mirror angle 15.0 magnitude 3.9
                                           MMA 1 Geometry does not allow reflection
                                           MMA 2 Geometry does not allow reflection
            Moon -55.8  59.2 NE   406685.1
EOD

$ft->local_coord( 'azel' );
is $ft->format(
    template	=> 'position',
    data	=> {
	    bodies	=> [ $sat, $moon ],
	    station	=> $sta,
	    time	=> timegm( 45, 7, 10, 13, 9, 80 ),
	} ), <<'EOD', 'Position, local_coord = azel';
1980-10-13 10:07:45
            Name Eleva  Azimuth               Epoch Illum
            None  28.4 130.7 SE 1980-10-01 23:41:24 lit
                                MMA 0 mirror angle 15.0 magnitude 3.9
                                MMA 1 Geometry does not allow reflection
                                MMA 2 Geometry does not allow reflection
            Moon -55.8  59.2 NE
EOD

$ft->local_coord( 'az_rng' );
is $ft->format(
    template	=> 'position',
    data	=> {
	    bodies	=> [ $sat, $moon ],
	    station	=> $sta,
	    time	=> timegm( 45, 7, 10, 13, 9, 80 ),
	} ), <<'EOD', 'Position, local_coord = az_rng';
1980-10-13 10:07:45
            Name  Azimuth      Range               Epoch Illum
            None 130.7 SE      409.9 1980-10-01 23:41:24 lit
                                     MMA 0 mirror angle 15.0 magnitude 3.9
                                     MMA 1 Geometry does not allow reflection
                                     MMA 2 Geometry does not allow reflection
            Moon  59.2 NE   406685.1
EOD

$ft->local_coord( 'equatorial' );
is $ft->format(
    template	=> 'position',
    data	=> {
	    bodies	=> [ $sat, $moon ],
	    station	=> $sta,
	    time	=> timegm( 45, 7, 10, 13, 9, 80 ),
	} ), <<'EOD', 'Position, local_coord = azel';
1980-10-13 10:07:45
            Name    Right Decli               Epoch Illum
                 Ascensio
            None 09:17:51  -8.5 1980-10-01 23:41:24 lit
                                MMA 0 mirror angle 15.0 magnitude 3.9
                                MMA 1 Geometry does not allow reflection
                                MMA 2 Geometry does not allow reflection
            Moon 16:26:42 -17.2
EOD

$ft->local_coord( 'equatorial_rng' );
is $ft->format(
    template	=> 'position',
    data	=> {
	    bodies	=> [ $sat, $moon ],
	    station	=> $sta,
	    time	=> timegm( 45, 7, 10, 13, 9, 80 ),
	} ), <<'EOD', 'Position, local_coord = azel';
1980-10-13 10:07:45
            Name    Right Decli      Range               Epoch Illum
                 Ascensio
            None 09:17:51  -8.5      409.9 1980-10-01 23:41:24 lit
                                           MMA 0 mirror angle 15.0 magnitude 3.9
                                           MMA 1 Geometry does not allow reflection
                                           MMA 2 Geometry does not allow reflection
            Moon 16:26:42 -17.2   406685.1
EOD

is $ft->format(
	arg	=> [ qw{ sailor } ],
	template => \"Hello, [% arg.0 %]!\n",
    ), <<'EOD', 'Report';
Hello, sailor!
EOD

# NOTE: At this point, the local coordinates are equatorial_rng. We do
# not use them for subsequent tests, but if we do will probably need to
# reset them.

is $ft->format(
    template	=> 'tle',
    data	=> [ $sat ],
), <<'EOD', 'Tle';
None
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
EOD

is $ft->format(
    template	=> 'tle_verbose',
    data	=> [ $sat ],
), <<'EOD', 'Tle verbose';
OID: 88888
    Name: None
    International Launch Designator:
    Epoch: 1980-10-01 23:41:24 GMT
    Effective Date: <none> GMT
    Classification: U
    Mean Motion: 4.01456130 degrees/minute
    First Derivative: 1.26899306e-07 degrees/minute squared
    Second Derivative: 1.66908e-11 degrees/minute cubed
    B Star Drag: 6.68160e-05
    Ephemeris Type: 0
    Inclination: 72.8435 degrees
    Ascending Node: 07:43:53 in right ascension
    Eccentricity: 0.0086731
    Argument Of Perigee: 52.6988 degrees from ascending node
    Mean Anomaly: 110.5714 degrees
    Element Number: 8
    Revolutions At Epoch: 105
    Period: 01:29:37
    Semimajor Axis: 6634.0 kilometers
    Perigee: 198.3 kilometers
    Apogee: 313.4 kilometers
EOD

done_testing;

1;

# ex: set textwidth=72 :
