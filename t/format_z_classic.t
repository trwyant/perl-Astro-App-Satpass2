package main;

use strict;
use warnings;

use lib qw{ inc };

use App::Satpass2::Test::Format;
use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Astro::Coord::ECI::Sun;
use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::Utils qw{ deg2rad };
use Time::Local;

my $sun = Astro::Coord::ECI::Sun->new();
my $sta = Astro::Coord::ECI->new(
    name => '1600 Pennsylvania Ave NW, Washington DC 20502'
)->geodetic(
    deg2rad( 38.898748 ),
    deg2rad( -77.037684 ),
    16.68 / 1000,
);
my $moon = Astro::Coord::ECI::Moon->new();

# Note that the following are _not_ real Keplerian elements for the
# International Space Station, or in fact any other orbiting body. The
# only data known to be real are the id, the name, and the internatinal
# launch designator. Instead of doing an actual position calculation, we
# simply set the model to 'null', and then set the ECI position we want.

my $time = 1223594621;	# 09-Oct-2008 23:23:41
my $epoch = 1223549582;	# 09-Oct-2008 10:53:02

my $body = Astro::Coord::ECI::TLE->new(
    model => 'null',
    id => 25544,
    name => 'ISS',
    classification => 'U',
    effective => $epoch - 1800,
    epoch => $epoch,
    meanmotion => &deg2rad(3.930270155),
    eccentricity => 0.0004029,
    inclination => &deg2rad(51.6426),
    international => '98067A',
    firstderivative => &deg2rad(1.23456789e-8),
    secondderivative => &deg2rad(1.23456789e-20),
    bstardrag => 8.2345e-5,
    ephemeristype => 0,
    ascendingnode => &deg2rad(159.8765),
    argumentofperigee => &deg2rad(198.7654),
    meananomaly => &deg2rad(279.8765),
    elementnumber => 456,
    revolutionsatepoch => 56789,
)->geodetic(&deg2rad(34.0765), &deg2rad(-74.2084), 353.9
)->universal($time);


my $tst = App::Satpass2::Test::Format->new( 'App::Satpass2::Format::Classic' );

$tst->plan( tests => 414 );

$tst->require_ok();

$tst->can_ok( 'new' );

$tst->can_ok( 'date_format' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'local_coord' );
$tst->can_ok( 'provider' );
$tst->can_ok( 'time_format' );
$tst->can_ok( 'tz' );

$tst->can_ok( 'almanac' );
$tst->can_ok( 'flare' );
$tst->can_ok( 'list' );
$tst->can_ok( 'location' );
$tst->can_ok( 'pass' );
$tst->can_ok( 'phase' );
$tst->can_ok( 'position' );
$tst->can_ok( 'tle' );
$tst->can_ok( 'tle_verbose' );

$tst->new_ok();

my @almanac = ( {	# almanac
	almanac => {
	    event => 'horizon',
	    detail => 1,
	    description => 'Sunrise',
	},
	body => $sun,
	station => $sta,
	time => 1238583151,	# Wed Apr 1 10:52:31 2009 GMT
    } );

$tst->note( '%almanac' );
$tst->format_setup( almanac => almanac => @almanac );

$tst->format_is( '%-almanac;', 'Sunrise', 'Almanac description' );
$tst->format_is( '%-almanac(units=event);', 'horizon', 'Almanac event' );
$tst->format_is( '%-almanac(units=detail);', '1', 'Almanac detail' );
$tst->format_fail( '%almanac(appulse);', '%almanac(appulse) is not allowed',
    'Appulse almanac is not allowed' );
$tst->format_fail( '%almanac(center);', '%almanac(center) is not allowed',
    'Center almanac is not allowed' );
$tst->format_fail( '%almanac(station);', '%almanac(station) is not allowed',
    'Station almanac is not allowed' );

my @pass = ( {		# pass
##	body => $body,
	events => [
	    {		# appulse with Moon
		appulse => {
		    angle => 0.0506145483078356,
		    body => $moon->universal( $time ),
		},
		body => $body,
		event => 7,
		illumination => 2,
		station => $sta,
		time => $time,
	    },
	],
    } );

$tst->method( template => pass_oid => '' );	# Supress OID and date.
$tst->method( template => pass_appulse => '' );	# Supress appulse.
$tst->method( 'pass' );				# Initialize

$tst->format_setup( pass => pass => @pass );

$tst->note( '%altitude;' );

$tst->format_is( '%altitude;', '  353.9',
    'Altitude of satellite (no effector args)' );
$tst->format_is( '%altitude();', '  353.9',
    'Altitude of satellite (empty effector args)' );
$tst->format_is( '%*altitude();', '353.9',
    'Altitude of satellite (glob field width)' );
$tst->format_is( '%*.*altitude();', '353.9',
    'Altitude of satellite (glob field width and decimal places)' );
$tst->format_is( '%altitude(body);', '  353.9',
    q{Altitude of satellite (explicit 'body')} );
$tst->format_is( '%altitude(center);', '',
    'Altitude of flare center (unavailable)' );
$tst->format_is( '%*altitude(center);', '',
    'Altitude of flare center (glob field width, still unavailable)' );
$tst->format_is( '%*altitude(center);', '',
    'Altitude of flare center (glob field width and decimal places, ditto)' );
$tst->format_is( '%*altitude(center,missing=unavailable);', 'unavailable',
    q{Altitude of flare center ('missing=unavailable')} );
$tst->format_is( '%8altitude(appulse);', '385877.8',
    'Altitude of appulsed body' );
$tst->format_is( '%altitude(station);', '    0.0',
    'Altitude of station' );
$tst->format_is( '%.0altitude(station,units=meters);', '     17',
    'Altitude of station in meters' );

$tst->note( '%angle;' );

# TODO test mirror angle (when it is actually available)

$tst->format_is( '%angle', '', 'Mirror angle unavailable' );
$tst->format_is( '%angle(appulse);', ' 2.9', 'Appulse angle' );
$tst->format_fail( '%angle(center);', '%angle(center) is not allowed',
    'Center angle is not allowed');
$tst->format_fail( '%angle(station);', '%angle(station) is not allowed',
    'Station angle is not allowed');

$tst->note( '%apoapsis;' );

$tst->format_is('%apoapsis;', '   356', 'Apoapsis of satellite');
$tst->format_is('%apoapsis(center);', '',
    'Apoapsis of flare center (unavailable)');
$tst->format_is('%apoapsis(appulse);', '',
    'Apoapsis of appulsed body (unavailable)');
$tst->format_is('%apoapsis(station);', '', 'Apoapsis of station (unavailable)');
$tst->format_is('%apoapsis(earth);', '  6734',
    'Apoapsis of satellite from center of Earth');
$tst->format_is('%apoapsis(center,earth);', '',
    'Apoapsis of flare center from center of Earth (unavailable)');
$tst->format_is('%apoapsis(appulse,earth);', '',
    'Apoapsis of appulsed body from center of Earth (unavailable)');
$tst->format_is('%apoapsis(station,earth);', '',
    'Apoapsis of station from center of Earth (unavailable)');

$tst->note( '%apogee;' );

$tst->format_is('%apogee;', '   356', 'Apogee of satellite');
$tst->format_is('%apogee(center);', '',
    'Apogee of flare center (unavailable)');
$tst->format_is('%apogee(appulse);', '',
    'Apogee of appulsed body (unavailable)');
$tst->format_is('%apogee(station);', '', 'Apogee of station (unavailable)');
$tst->format_is('%apogee(earth);', '  6734',
    'Apogee of satellite from center of Earth');
$tst->format_is('%apogee(center,earth);', '',
    'Apogee of flare center from center of Earth (unavailable)');
$tst->format_is('%apogee(appulse,earth);', '',
    'Apogee of appulsed body from center of Earth (unavailable)');
$tst->format_is('%apogee(station,earth);', '',
    'Apogee of station from center of Earth (unavailable)');

$tst->note( '%argumentofperigee;' );

$tst->format_is('%argumentofperigee;', ' 198.7654',
    'Argument of perigee of satellite');
$tst->format_is('%argumentofperigee(center);', '',
    'Argument of perigee of center (unavailable)');
$tst->format_is('%argumentofperigee(appulse);', '',
    'Argument of perigee of appulse (unavailable)');
$tst->format_is('%argumentofperigee(station);', '',
    'Argument of perigee of station (unavailable)');

$tst->note( '%ascendingnode;' );
$tst->format_is('%ascendingnode;', '10:39:30.36',
    'Ascending node of satellite');
$tst->format_is('%9.4ascendingnode(units=degrees);', ' 159.8765',
    'Ascending node of satellite (degrees)');
$tst->format_is('%ascendingnode(center);', '',
    'Ascending node of center (unavailable)');
$tst->format_is('%ascendingnode(appulse);', '',
    'Ascending node of appulse (unavailable)');
$tst->format_is('%ascendingnode(station);', '',
    'Ascending node of station (unavailable)');

$tst->note( '%azimuth;' );

$tst->format_is('%azimuth;', '153.8', 'Azimuth of satellite');
$tst->format_is('%azimuth(bearing);', '153.8 SE',
    'Azimuth of satellite, with bearing');
$tst->format_is('%azimuth(bearing=3);', '153.8 SSE',
    'Azimuth of satellite, with three-character bearing');
$tst->format_is('%2azimuth(units=bearing);', 'SE',
    'Azimuth of satellite, as bearing');
$tst->format_is('%azimuth(center);', '', 'Azimuth of center (unavailable)');
$tst->format_is('%azimuth(center,bearing);', '',
    'Azimuth of center, with bearing (unavailable)');
$tst->format_is('%azimuth(appulse);', '151.2', 'Azimuth of appulsed body');
$tst->format_is('%azimuth(appulse,bearing);', '151.2 SE',
    'Azimuth of appulsed body, with bearing');
$tst->format_is('%azimuth(station);', '335.5',
    'Azimuth of station from satellite');
$tst->format_is('%azimuth(station,bearing);', '335.5 NW',
    'Azimuth of station from satellite, with bearing');

$tst->note( '%bstardrag;' );

$tst->format_is('%bstardrag;', ' 8.2345e-05', 'B* drag of satellite');
$tst->format_is('%bstardrag(center);', '', 'B* drag of center (unavailable)');
$tst->format_is('%bstardrag(appulse);', '', 'B* drag of appulse (unavailable)');
$tst->format_is('%bstardrag(station);', '', 'B* drag of station (unavailable)');

$tst->note( '%classification;' );

$tst->format_is('%classification;', 'U', 'Classification of satellite');
$tst->format_is('%classification(center);', '',
    'Classification of flare center (unavailable)');
$tst->format_is('%classification(appulse);', '',
    'Classification of appulsed body (unavailable)');
$tst->format_is('%classification(station);', '',
    'Classification of station (unavailable)');

$tst->note( '%date;' );

$tst->format_is('%date(units=gmt);', '2008-10-09', 'Date');
$tst->format_is('%*.5date(units=julian);', '2454749.47478',
    'Date as Julian day');
$tst->format_is('%*.5date(units=days_since_epoch);',
    sprintf('%.5f', ($time - $epoch)/86400),
    'Date as days since epoch');
$tst->format_is('%date(appulse,units=gmt);', '2008-10-09',
    'Date(appulse) is normally the same as date');
$tst->format_is('%date(appulse,units=days_since_epoch)', '',
    'Date(appulse,units=days_since_epoch is blank, since no appulse epoch');
$tst->format_fail('%date(center);', '%date(center) is not allowed',
    'Center date is not allowed');
$tst->format_fail('%date(station);', '%date(station) is not allowed',
    'Station date is not allowed');

$tst->note( '%declination;' );

$tst->format_is('%declination(earth);', ' 33.9',
    'Declination, from center of Earth');
$tst->format_is('%declination;', '-19.2', 'Declination, from station');
$tst->format_is('%declination(center,earth);', '',
    'Declination of flare center, from center of Earth');
$tst->format_is('%declination(center);', '',
    'Declination of flare center, from station');
$tst->format_is('%declination(appulse,earth);', '-16.1',
    'Declination of appulsed, from center of Earth');
$tst->format_is('%declination(appulse);', '-16.8',
    'Declination of appulsed, from station');
$tst->format_is('%declination(station,earth);', ' 38.7',
    'Declination of station, from center of Earth');
$tst->format_is('%declination(station);', ' 19.2',
    'Declination of station, from satellite');

$tst->note( '%eccentricity' );

$tst->format_is('%eccentricity;', ' 0.00040', 'Eccentricity of satellite');
$tst->format_is('%eccentricity(center);', '',
    'Eccentricity of center (unavailable)');
$tst->format_is('%eccentricity(appulse);', '',
    'Eccentricity of appulse (unavailable)');
$tst->format_is('%eccentricity(station);', '',
    'Eccentricity of station (unavailable)');

$tst->note( '%eci_x;' );

$tst->format_is('%eci_x;', '    2416.6', 'Satellite Earth-centered inertial X');
$tst->format_is('%eci_x(center);', '',
    'Center Earth-centered inertial X (unavailable)');
$tst->format_is('%eci_x(appulse);',
    '  282759.2', 'Appulse Earth-centered inertial X');
$tst->format_is('%eci_x(station);',
    '    1928.2', 'Station Earth-centered inertial X');
$tst->format_is('%eci_y;', '   -5031.4', 'Satellite Earth-centered inertial Y');
$tst->format_is('%eci_y(center);', '',
    'Center Earth-centered inertial Y (unavailable)');
$tst->format_is('%eci_y(appulse);', ' -249276.5',
    'Appulse Earth-centered inertial Y');
$tst->format_is('%eci_y(station);', '   -4581.2',
    'Station Earth-centered inertial Y');
$tst->format_is('%eci_z;', '    3751.8', 'Satellite Earth-centered inertial Z');
$tst->format_is('%eci_z(center);', '',
    'Center Earth-centered inertial Z (unavailable)');
$tst->format_is('%eci_z(appulse);', ' -108498.3',
    'Appulse Earth-centered inertial Z');
$tst->format_is('%eci_z(station);', '    3983.6',
    'Station Earth-centered inertial Z');

$tst->note( '%effective' );

$tst->format_is('%effective(units=zulu);', '2008-10-09 10:23:02',
    q{Effective date of satellite data (using 'zulu' as alias for 'gmt')});
$tst->format_is('%*.5effective(units=julian);', '2454748.93266',
    'Effective date of satellite data as Julian day');
$tst->format_is('%-effective(units=days_since_epoch);',
    '-0.020833',
    'Effective date as days since epoch');
$tst->format_is('%effective(center);', '',
    'Effective date of center (unavailable)');
$tst->format_is('%effective(appulse);', '',
    'Effective date of appulsed body (unavailable)');
$tst->format_is('%effective(station);', '',
    'Effective date of station (unavailable)');

$tst->note( '%elementnumber' );

$tst->format_is('%elementnumber;', ' 456', 'Element set number of satellite');
$tst->format_is('%elementnumber(center);', '',
    'Element set number of center (unavailable)');
$tst->format_is('%elementnumber(appulse);', '',
    'Element set number of appulse (unavailable)');
$tst->format_is('%elementnumber(station);', '',
    'Element set number of station (unavailable)');

$tst->note( '%elevation' );

$tst->format_is('%elevation;', ' 27.5', 'Elevation of satellite');
$tst->format_is('%elevation(center);', '',
    'Elevation of flare center (unavailable)');
$tst->format_is('%elevation(appulse);', ' 29.2',
    'Elevation of appulsed body');
$tst->format_is('%elevation(station);', '-32.8',
    'Elevation of station, from satellite');

$tst->note( '%ephemeristype;' );

$tst->format_is('%ephemeristype;', '0', 'Ephemeris type of satellite');
$tst->format_is('%ephemeristype(center);', '',
    'Ephemeris type of center (unavailable)');
$tst->format_is('%ephemeristype(appulse);', '',
    'Ephemeris type of appulse (unavailable)');
$tst->format_is('%ephemeristype(station);', '',
    'Ephemeris type of station (unavailable)');

$tst->note( '%epoch;' );

$tst->format_is('%epoch(units=zulu);', '2008-10-09 10:53:02',
    q{Epoch of satellite data (using 'zulu' as alias for 'gmt')});
$tst->format_is('%*.5epoch(units=julian);', '2454748.95350',
    'Epoch of satellite data as Julian day');
$tst->format_fail('%epoch(units=days_since_epoch);',
    q{%epoch units 'days_since_epoch' not valid},
    'Epoch(units=days_since_epoch) forbidden (since it is always 0)');
$tst->format_is('%epoch(center);', '', 'Epoch of center (unavailable)');
$tst->format_is('%epoch(appulse);', '', 'Epoch of appulsed body (unavailable)');
$tst->format_is('%epoch(station);', '', 'Epoch of station (unavailable)');

$tst->note( '%event;' );

# Note that the following directly manipulates data inside the formatter
# object, using the references used to set that data. The author will
# not be responsible for what happens if anyone other than the author
# writes code that does this.

$tst->format_is('%event;', ' apls', 'Event');
$pass[0]{events}[0]{event} = 0;
$tst->format_is('%event;', '', 'Event (0)');
$pass[0]{events}[0]{event} = 1;
$tst->format_is('%event;', ' shdw', 'Event (1)');
$pass[0]{events}[0]{event} = 2;
$tst->format_is('%event;', '  lit', 'Event (2)');
$pass[0]{events}[0]{event} = 3;
$tst->format_is('%event;', '  day', 'Event (3)');
$pass[0]{events}[0]{event} = 4;
$tst->format_is('%event;', ' rise', 'Event (4)');
$pass[0]{events}[0]{event} = 5;
$tst->format_is('%event;', '  max', 'Event (5)');
$pass[0]{events}[0]{event} = 6;
$tst->format_is('%event;', '  set', 'Event (6)');
$pass[0]{events}[0]{event} = 7;
$tst->format_is('%event;', ' apls', 'Event (7)');
$tst->format_fail('%event(appulse);', '%event(appulse) is not allowed',
    'Appulse event is not allowed');
$tst->format_fail('%event(center);', '%event(center) is not allowed',
    'Center event is not allowed');
$tst->format_fail('%event(station);', '%event(station) is not allowed',
    'Station event is not allowed');

$tst->note( '%firstderivative;' );

$tst->format_is('%firstderivative;', ' 1.2345678900e-08',
    'First derivative of satellite (degrees/minute**2)');
$tst->format_is('%firstderivative(center);', '',
    'First derivative of center (unavailable)');
$tst->format_is('%firstderivative(appulse);', '',
    'First derivative of appulse (unavailable)');
$tst->format_is('%firstderivative(station);', '',
    'First derivative of station (unavailable)');

$tst->note( '%fraction_lit;' );

$tst->format_is('%fraction_lit;', '',
    'Fraction of object illuminated (unavailable)');
$tst->format_is('%fraction_lit(center);', '',
    'Fraction of flare center illuminated (unavailable)');
$tst->format_is('%fraction_lit(appulse);', '0.74',
    'Fraction of appulsed body illuminated');
$tst->format_is('%.0fraction_lit(appulse,units=percent);', '  74%',
    'Percent of appulsed body illuminated');
$tst->format_is('%fraction_lit(station);', '',
    'Fraction of station illuminated (unavailable)');

$tst->note( '%id;' );

$tst->format_is('%id;', ' 25544', 'OID of satellite');
$tst->format_is('%id(center);', '', 'OID of flare center (unavailable)');
$tst->format_is('%id(appulse);', '  Moon', 'OID of appulsed body');
$tst->format_is('%id(station);', '', 'OID of station');

$tst->note( '%illumination;' );

$tst->format_is('%illumination;', '  lit', 'Illumination (lit/shdw/day)');
$tst->format_fail('%illumination(appulse);',
    '%illumination(appulse) is not allowed',
    'Appulse illumination is not allowed');
$tst->format_fail('%illumination(center);',
    '%illumination(center) is not allowed',
    'Center illumination is not allowed');
$tst->format_fail('%illumination(station);',
    '%illumination(station) is not allowed',
    'Station illumination is not allowed');

$tst->note( '%inclination;' );

$tst->format_is('%inclination;', ' 51.6426',
    'Inclination of satellite (degrees)');
$tst->format_is('%inclination(center);', '',
    'Inclination of center (unavailable)');
$tst->format_is('%inclination(appulse);', '',
    'Inclination of appulse (unavailable)');
$tst->format_is('%inclination(station);', '',
    'Inclination of station (unavailable)');

$tst->note( '%international;' );

$tst->format_is('%international;', '  98067A',
    'International launch designator');
$tst->format_is('%international(center);', '',
    'Int\'l launch desig of center (unavailable)');
$tst->format_is('%international(appulse);', '',
    'Int\'l launch desig of appulse (unavailable)');
$tst->format_is('%international(station);', '',
    'Int\'l launch desig of station (unavailable)');

$tst->note( '%latitude;' );

$tst->format_is('%latitude;', ' 34.0765', 'Latitude of satellite');
$tst->format_is('%latitude(center);', '', 'Latitude of center (unavailable)');
$tst->format_is('%latitude(appulse);', '-16.0592', 'Latitude of appulsed body');
$tst->format_is('%latitude(station);', ' 38.8987', 'Latitude of station');

$tst->note( '%longitude;' );

$tst->format_is('%longitude;', ' -74.2084', 'Longitude of satellite');
$tst->format_is('%longitude(center);', '',
    'Longitude of flare center (unavailable)');
$tst->format_is('%longitude(appulse);', ' -51.2625',
    'Longitude of appulsed body');
$tst->format_is('%longitude(station);', ' -77.0377', 'Longitude of station');

$tst->note( '%magnitude;' );

# TODO flare magnitude, flare center magnitude.

$tst->format_is('%magnitude;', '', 'Magnitude (unavailable)');
$tst->format_fail('%magnitude(appulse);', '%magnitude(appulse) is not allowed',
    'Appulse magnitude is not allowed');
$tst->format_fail('%magnitude(station);', '%magnitude(station) is not allowed',
    'Station magnitude is not allowed');

$tst->note( '%meananomaly;' );

$tst->format_is('%meananomaly;', ' 279.8765',
    'Mean anomaly of satellite (degrees)');
$tst->format_is('%meananomaly(center);', '',
    'Mean anomaly of center (unavailable)');
$tst->format_is('%meananomaly(appulse);', '',
    'Mean anomaly of appulse (unavailable)');
$tst->format_is('%meananomaly(station);', '',
    'Mean anomaly of station (unavailable)');

$tst->note( '%meanmotion' );

$tst->format_is('%meanmotion;', '3.9302701550',
    'Mean motion of satellite (degrees/minute)');
$tst->format_is('%meanmotion(center);', '',
    'Mean motion of center (unavailable)');
$tst->format_is('%meanmotion(appulse);', '',
    'Mean motion of appulse (unavailable)');
$tst->format_is('%meanmotion(station);', '',
    'Mean motion of station (unavailable)');

$tst->note( '%mma;' );

# TODO actual flaring MMA from flare structure.

$tst->format_is('%mma;', '', 'MMA or other flare source (unavailable)');
$tst->format_fail('%mma(appulse);', '%mma(appulse) is not allowed',
    'Appulse mma is not allowed');
$tst->format_fail('%mma(center);', '%mma(center) is not allowed',
    'Center mma is not allowed');
$tst->format_fail('%mma(station);', '%mma(station) is not allowed',
    'Station mma is not allowed');

$tst->note( '%name;' );

$tst->format_is('%-name;', 'ISS', 'Name of object');
$tst->format_is('%name(center);', '', 'Name of center (unavailable)');
$tst->format_is('%-name(appulse);', 'Moon', 'Name of appulsed body');
$tst->format_is('%-24name(station);', '1600 Pennsylvania Ave NW',
    'Name of station');

$tst->note( '%operational;' );

# TODO operational status of Iridium satellite

$tst->format_is('%operational;', '',
    'Operational status of satellite (unavailable)');
$tst->format_is('%operational(center);', '',
    'Operational status of center (unavailable)');
$tst->format_is('%operational(appulse);', '',
    'Operational status of appulse (unavailable)');
$tst->format_is('%operational(station);', '',
    'Operational status of station (unavailable)');

$tst->note( '%percent;' );

$tst->format_is('%percent;', '%', 'Literal percent');
$tst->format_fail('%percent(appulse);', '%percent(appulse) is not allowed',
    'Appulse percent is not allowed');
$tst->format_fail('%percent(center);', '%percent(center) is not allowed',
    'Center percent is not allowed');
$tst->format_fail('%percent(station);', '%percent(station) is not allowed',
    'Station percent is not allowed');

$tst->note( '%periapsis;' );

$tst->format_is('%periapsis;', '   351', 'Periapsis of satellite');
$tst->format_is('%periapsis(center);', '',
    'Periapsis of flare center (unavailable)');
$tst->format_is('%periapsis(appulse);', '',
    'Periapsis of appulsed body (unavailable)');
$tst->format_is('%periapsis(station);', '',
    'Periapsis of station (unavailable)');
$tst->format_is('%periapsis(earth);', '  6729',
    'Periapsis of satellite from center of Earth');
$tst->format_is('%periapsis(center,earth);', '',
    'Periapsis of flare center from center of Earth (unavailable)');
$tst->format_is('%periapsis(appulse,earth);', '',
    'Periapsis of appulsed body from center of Earth (unavailable)');
$tst->format_is('%periapsis(station,earth);', '',
    'Periapsis of station from center of Earth (unavailable)');

$tst->note( '%perigee;' );

$tst->format_is('%perigee;', '   351', 'Perigee of satellite');
$tst->format_is('%perigee(center);', '',
    'Perigee of flare center (unavailable)');
$tst->format_is('%perigee(appulse);', '',
    'Perigee of appulsed body (unavailable)');
$tst->format_is('%perigee(station);', '', 'Perigee of station (unavailable)');
$tst->format_is('%perigee(earth);', '  6729',
    'Perigee of satellite from center of Earth');
$tst->format_is('%perigee(center,earth);', '',
    'Perigee of flare center from center of Earth (unavailable)');
$tst->format_is('%perigee(appulse,earth);', '',
    'Perigee of appulsed body from center of Earth (unavailable)');
$tst->format_is('%perigee(station,earth);', '',
    'Perigee of station from center of Earth (unavailable)');

$tst->note( '%period;' );

$tst->format_is('%period;', '    01:31:36', 'Period of satellite');
$tst->format_is('%*.0period(units=seconds);', '5496',
    'Period of satellite in seconds');
$tst->format_is('%*.2period(units=minutes);', '91.61',
    'Period of satellite in minutes');
$tst->format_is('%*.3period(units=hours);', '1.527',
    'Period of satellite in hours');
$tst->format_is('%*.5period(units=days);', '0.06362',
    'Period of satellite in days');
$tst->format_is('%period(center);', '', 'Period of center (unavailable)');
$tst->format_is('%period(appulse);', ' 27 07:43:12', 'Period of appulsed body');
$tst->format_is('%period(station);', '', 'Period of station (unavailable)');

$tst->note( '%phase;' );

$tst->format_is('%phase;', '', 'Phase of satellite (unavailable)');
$tst->format_is('%phase(units=phase);', '',
    'Phase of satellite as string (unavailable)');
$tst->format_is('%phase(center);', '', 'Phase of center (unavailable)');
$tst->format_is('%phase(center,units=phase);', '',
    'Phase of center as string (unavailable)');
$tst->format_is('%phase(appulse);', ' 119', 'Phase of appulsed body');
$tst->format_is('%-24phase(appulse,units=phase);', 'waxing gibbous',
    'Phase of appulsed body as string');
$tst->format_is('%phase(station);', '', 'Phase of station (unavailable)');
$tst->format_is('%phase(station,units=phase);', '',
    'Phase of station as string (unavailable)');

# TODO %provider;

$tst->note( '%range;' );

$tst->format_is('%range;', '     703.5', 'Range of satellite');
$tst->format_is('%.0range(units=meters);', '    703549',
    'Range of satellite in meters');
$tst->format_is('%range(center);', '', 'Range of center (unavailable)');
$tst->format_is('%range(appulse);', '  389093.9', 'Range of appulsed body');
$tst->format_is('%range(station);', '     703.5',
    'Range of station (from satellite)');

$tst->note( '%revolutionsatepoch;' );

$tst->format_is('%revolutionsatepoch;', ' 56789',
    'Revolutions at epoch of satellite');
$tst->format_is('%revolutionsatepoch(center);', '',
    'Revolutions at epoch of center (unavailable)');
$tst->format_is('%revolutionsatepoch(appulse);', '',
    'Revolutions at epoch of appulse (unavailable)');
$tst->format_is('%revolutionsatepoch(station);', '',
    'Revolutions at epoch of station (unavailable)');

$tst->note( '%right_ascension;' );

$tst->format_is('%right_ascension(earth);', '19:42:37',
    'Right ascension, from center of Earth');
$tst->format_is('%right_ascension;', '21:09:19',
    'Right ascension, from station');
$tst->format_is('%right_ascension(center,earth);', '',
    'Right ascension of flare center, from center of Earth');
$tst->format_is('%right_ascension(center);', '',
    'Right ascension of flare center, from station');
$tst->format_is('%right_ascension(appulse,earth);', '21:14:24',
    'Right ascension of appulsed, from center of Earth');
$tst->format_is('%right_ascension(appulse);', '21:15:44',
    'Right ascension of appulsed, from station');
$tst->format_is('%right_ascension(station,earth);', '19:31:18',
    'Right ascension of station, from center of Earth');
$tst->format_is('%right_ascension(station);', '09:09:19',
    'Right ascension of station, from satellite');

$tst->note( '%secondderivative;' );

$tst->format_is('%secondderivative;', ' 1.2345678900e-20',
    'Second derivative of satellite (degrees/minute**3)');
$tst->format_is('%secondderivative(center);', '',
    'Second derivative of center (unavailable)');
$tst->format_is('%secondderivative(appulse);', '',
    'Second derivative of appulse (unavailable)');
$tst->format_is('%secondderivative(station);', '',
    'Second derivative of station (unavailable)');

$tst->note( '%semimajor;' );

$tst->format_is('%semimajor;', '  6732', 'Semimajor axis of satellite');
$tst->format_is('%semimajor(center);', '',
    'Semimajor axis of flare center (unavailable)');
$tst->format_is('%semimajor(appulse);', '',
    'Semimajor axis of appulsed body (unavailable)');
$tst->format_is('%semimajor(station);', '',
    'Semimajor axis of station (unavailable)');

$tst->note( '%semiminor;' );

$tst->format_is('%semiminor;', '  6732', 'Semiminor axis of satellite');
$tst->format_is('%semiminor(center);', '',
    'Semiminor axis of flare center (unavailable)');
$tst->format_is('%semiminor(appulse);', '',
    'Semiminor axis of appulsed body (unavailable)');
$tst->format_is('%semiminor(station);', '',
    'Semiminor axis of station (unavailable)');

$tst->note( '%space;' );

$tst->format_is('%space;.', ' .', 'A single space');
$tst->format_is('%3space;.', '   .', 'Three spaces');
$tst->format_fail('%space(appulse);', '%space(appulse) is not allowed',
    'Appulse space is not allowed');
$tst->format_fail('%space(center);', '%space(center) is not allowed',
    'Center space is not allowed');
$tst->format_fail('%space(station);', '%space(station) is not allowed',
    'Station space is not allowed');

$tst->note( '%status;' );

# TODO test actual Iridium status.

$tst->format_is('%status;', '', 'Status of satellite (unavailable)');
$tst->format_fail('%status(appulse);', '%status(appulse) is not allowed',
    'Appulse status is not allowed');
$tst->format_fail('%status(center);', '%status(center) is not allowed',
    'Center status is not allowed');
$tst->format_fail('%status(station);', '%status(station) is not allowed',
    'Station status is not allowed');

$tst->note( '%time;' );

$tst->format_is('%time(units=gmt);', '23:23:41', 'Time of day');
$tst->format_is('%*.5time(units=julian);', '2454749.47478',
    'Time as Julian day (same as %date;)');
$tst->format_is('%time;', '23:23:41', 'Time of day');	# gmt should
							# already be set
$tst->method_is( effectors_used => 'pass', { time => 1 },
    'Format effectors used by pass (right now)' );
$tst->format_is('%time(appulse,units=gmt);', '23:23:41',
    'Time(appulse) is usually the same as time');
$tst->format_fail('%time(center);', '%time(center) is not allowed',
    'Center time is not allowed');
$tst->format_fail('%time(station);', '%time(station) is not allowed',
    'Station time is not allowed');
$tst->method_ok( gmt => 0, 'Can turn off gmt' );
$tst->method_ok( tz => 'EST5EDT', 'Can zet zone to Eastern US' );
$tst->format_is( '%time', '19:23:41', 'Time of day (Eastern US)' );
$tst->method_ok( gmt => 1, 'Can turn gmt back on' );
$tst->method_ok( tz => undef, 'Can make zone undef' );
$tst->format_is('%time;', '23:23:41', 'Time of day (round trip on tz)');

SKIP: {

    eval { Astro::Coord::ECI::TLE->VERSION( 0.015 ); 1 }
	or $tst->skip(
	'Test requires Astro::Coord::ECI::TLE v0.015 or above', 1 );

    $tst->format_is('%tle;', <<'EOD', 'TLE of satellite');
ISS --effective 2008/283/10:23:02.000
1 25544U 98067A   08283.45349537  .00007111 10240-12  82345-4 0  4565
2 25544  51.6426 159.8765 0004029 198.7654 279.8765 15.72108062567893
EOD

}

$tst->method_ok( format_effector =>
    status => missing => '<none>',
    'Set new missing text for %status' );
$tst->format_is('%-status;', '<none>', 'Status of satellite ("<none>")');
$tst->method_ok( format_effector =>
    status => missing => undef,
    'Restore default missing text for %status' );
$tst->format_is('%status;', '', 'Status of satellite ("")');

$tst->method_ok( format_effector =>
    perigee => places => 1,
    'Set new decimal places for %perigee' );
$tst->format_is('%perigee;', ' 350.7',
    'Perigee of satellite (1 decimal place)');
$tst->method_ok( format_effector =>
    perigee => places => undef,
    'Restore default decimal places for %perigee' );
$tst->format_is('%perigee;', '   351',
    'Perigee of satellite (default decimal places)');

$tst->method_ok( format_effector =>
    perigee => units => 'miles',
    'Set new units for %perigee' );
$tst->format_is('%perigee;', '   218',
    'Perigee of satellite (in miles)');
$tst->method_ok( format_effector =>
    perigee => units => undef,
    'Restore default units for %perigee' );
$tst->format_is('%perigee;', '   351',
    'Perigee of satellite (default units)');
$tst->format_is('%perigee(units=miles);', '   218',
    'Perigee of satellite (explicitly in miles)' );

$tst->method_ok( format_effector =>
    perigee => width => 8,
    'Set new field width for %perigee' );
$tst->format_is('%perigee;', '     351',
    'Perigee of satellite (field width 8)');
$tst->method_ok( format_effector =>
    perigee => width => undef,
    'Restore default decimal width for %perigee' );
$tst->format_is('%perigee;', '   351',
    'Perigee of satellite (default field width)');

$tst->note( 'titles' );

# The title tests are better adapted to the position() method.

$tst->format_setup( position => 'position' );

$tst->format_is('%-almanac;', 'almanac', 'Title of almanac description');

$tst->format_is('%altitude;', 'altitud', 'Title of satellite altitude');
$tst->format_is('%altitude();', 'altitud', 'Title of satellite altitude ()');
$tst->format_is('%*altitude();', 'altitude', 'Title of satellite altitude (*)');
$tst->format_is('%*.*altitude();', 'altitude',
    'Title of satellite altitude (*.*)');
$tst->format_is('%altitude(body);', 'altitud',
    'Title of satellite altitude (body)');
$tst->format_is('%altitude(center);', " center\naltitud",
    'Title of flare center altitude');
$tst->format_is('%*altitude(center);', 'center altitude',
    'Title of flare center altitude (*)');
$tst->format_is('%8altitude(appulse);', " appulse\naltitude",
    'Title of appulsed body altitude');
$tst->format_is('%altitude(station);', "station\naltitud",
    'Title of station altitude');
$tst->format_is('%altitude(title=How high);', "    How\n   high",
    'Title of satellite altitude (title=How high)');
$tst->format_is('%altitude(center,title=How high is the center);',
    "    How\nhigh is\n    the\n center",
    'Title of center altitude (title=How high is the center)');
$tst->format_is('%-altitude(center,title=How high is the center);',
    "How\nhigh is\nthe\ncenter",
    'Title of center altitude (ditto, left-justified)');

$tst->format_is('%angle;', 'angl', 'Title of angle');
$tst->format_is('%angle(appulse);', "appu\nangl", 'Title of appulse angle');

$tst->format_is('%apoapsis;', 'apoaps', 'Title of apoapsis');

$tst->format_is('%apogee;', 'apogee', 'Title of apogee');

$tst->format_is('%argumentofperigee;', " argument\n       of\n  perigee",
    'Title of argument of perigee');

$tst->format_is('%ascendingnode;', "  ascending\n       node",
    'Title of ascending node');

$tst->format_is('%azimuth;', 'azimu', 'Title of azimuth');

$tst->format_is('%bstardrag;', '    B* drag', 'Title of B* drag');

$tst->format_is('%classification;', '', 'Title of classification');

$tst->format_is('%date;', '      date', 'Title of date');

$tst->format_is('%declination;', 'decli', 'Title of declination');

$tst->format_is('%eccentricity;', 'eccentri', 'Title of eccentricity');

$tst->format_is('%eci_x;', '     eci x', 'Title of ECI X');

$tst->format_is('%eci_y;', '     eci y', 'Title of ECI Y');

$tst->format_is('%eci_z;', '     eci z', 'Title of ECI Z');

$tst->format_is('%effective;', '     effective date',
    'Title of effective date');

$tst->format_is('%elementnumber;', "elem\n set\nnumb",
    'Title of element set number');

$tst->format_is('%elevation;', 'eleva', 'Title of elevation');

$tst->format_is('%ephemeristype;', "e\nt", 'Title of ephemeris type');

$tst->format_is('%epoch', '              epoch', 'Title of epoch');

$tst->format_is('%event;', 'event', 'Title of event');

$tst->format_is('%firstderivative;', " first derivative\n   of mean motion",
    'Title of first derivative');

$tst->format_is('%fraction_lit;', "frac\n lit", 'Title of fraction lit');

$tst->format_is('%id;', '   oid', 'Title of id');

$tst->format_is('%illumination;', 'illum', 'Title of illumination');

$tst->format_is('%inclination;', 'inclinat', 'Title of inclination');

$tst->format_is('%international;', "internat\n  launch\ndesignat",
    'Title of international launch designator');

$tst->format_is('%latitude;', 'latitude', 'Title of latitude');

$tst->format_is('%longitude;', 'longitude', 'Title of longitude');

$tst->format_is('%magnitude;', 'magn', 'Title of magnitude');

$tst->format_is('%meananomaly;', "     mean\n  anomaly",
    'Title of mean anomaly');

$tst->format_is('%meanmotion;', ' mean motion', 'Title of mean motion');

$tst->format_is('%mma', 'mma', 'Title of mma');

$tst->format_is('%name', '                    name', 'Title of name');

$tst->format_is('%operational', '', 'Title of operational');

$tst->format_is('%percent', '', 'Title of percent');

$tst->format_is('%periapsis', 'periap', 'Title of periapsis');

$tst->format_is('%perigee', 'perige', 'Title of perigee');

$tst->format_is('%period', '      period', 'Title of period');

$tst->format_is('%phase', 'phas', 'Title of phase');

$tst->format_is('%range', '     range', 'Title of range');

$tst->format_is('%revolutionsatepoch', "revolu\n    at\n epoch",
    'Title of revolutionsatepoch');

$tst->format_is('%right_ascension', "   right\nascensio",
    'Title of right_ascension');

$tst->format_is('%secondderivative', "second derivative\n   of mean motion",
    'Title of secondderivative');

$tst->format_is('%semimajor', "semima\n  axis", 'Title of semimajor');

$tst->format_is('%semiminor', "semimi\n  axis", 'Title of semiminor');

$tst->format_is('%space', '', 'Title of space');

$tst->format_is('%status', ((' ' x 54) . 'status'), 'Title of status');

$tst->format_is('%time', '    time', 'Title of time');

$tst->format_is('%tle', '', 'Title of tle');

$tst->method_ok( format_effector =>
    altitude => title => 'How many degrees above horizon',
    'Set new default title on object' );
$tst->format_is('%altitude;', <<'EOD', 'Demonstrate new default title');
    How
   many
degrees
  above
horizon
EOD
$tst->method_is( format_effector => 'altitude', [
	title => 'How many degrees above horizon',
    ], 'Retrieve new default settings' );
$tst->method_ok( format_effector => altitude => title => undef,
    'Clear object-level default title' );
$tst->method_is( format_effector => 'altitude', [],
    'Check that object level settings are cleared' );
$tst->format_is('%altitude;', 'altitud',
    'Check that original default title is restored.');

# Macro titles

$tst->note( 'Macro titles' );

$tst->method_fail( macro => declination => '%right_ascension',
    q{Macro name 'declination' duplicates format effector name},
    'Redefinition of declination should fail' );
$tst->method_ok( macro => azel => '%elevation %azimuth(bearing)',
    'Define macro azel as elevation and azimuth');
$tst->method_ok( macro => equatorial => '%right_ascension %declination',
    'Define macro equatorial as right ascension and declination');
$tst->method_is( macro => 'azel', '%elevation %azimuth(bearing)',
    'Verify definition of macro azel');
$tst->method_is (macro => equatorial => '%right_ascension %declination',
    'Verify definition of macro equatorial');
$tst->format_is('%azel',
    'eleva  azimuth',
    'Expand macro azel (title)');
$tst->format_is('%equatorial',
    "   right\nascensio decli",
    'Expand macro equatorial (title)');

# Macro data expansion better with pass

$tst->note( 'Macro expansion' );
$tst->format_setup( pass => pass => @pass );

$tst->format_is('%azel',
    ' 27.5 153.8 SE',
    'Expand macro azel (data)');
$tst->format_is('%equatorial',
    '21:09:19 -19.2',
    'Expand macro equatorial (data)');
$tst->method_ok( macro => local_coord => '%azel',
    "Define macro local_coord as '%azel'");
$tst->format_is('%local_coord',
    ' 27.5 153.8 SE',
    'Expand macro local_coord (defined as %azel)');
$tst->method_ok( macro => local_coord => '%equatorial',
    "Define macro local_coord as '%equatorial'");
$tst->format_is('%local_coord',
    '21:09:19 -19.2',
    'Expand macro local_coord (now defined as %equatorial)');
$tst->method_ok( macro => azel => '%elevation($*) %azimuth($*,bearing)',
    'Redefine macro azel as elevation and azimuth, with argument');
$tst->format_is('%azel',
    ' 27.5 153.8 SE',
    'Expand macro azel with no argument');
$tst->format_is('%azel(body)',
    ' 27.5 153.8 SE',
    'Expand macro azel with argument (body)');
$tst->format_is('%azel(appulse)',
    ' 29.2 151.2 SE',
    'Expand macro azel with argument (appulse)');

$tst->note( 'Actual default output' );
$tst->note( 'We create a new object for this, to restore defaults' );

$tst->new_ok();

$tst->format_setup( almanac => almanac => @almanac );

$tst->method_is( almanac => @almanac, '2009-04-01 10:52:31 Sunrise',
    'Default almanac output' );
$tst->method_is( almanac => '', 'Almanac has no headings' );

# TODO flare

$tst->method_is( list => <<'EOD', 'List title' );
   oid name                     epoch               period
EOD
# We use a new object here because the 'inertial' setting appears to be
# sticky. Will have to look into this in Astro::Coord::ECI::TLE.
$tst->method_is( list =>
    Astro::Coord::ECI::TLE->new(
	id => 25544,
	name => 'ISS',
	classification => 'U',
	effective => $epoch - 1800,
	epoch => $epoch,
	meanmotion => &deg2rad(3.930270155),
	eccentricity => 0.0004029,
	inclination => &deg2rad(51.6426),
	international => '98067A',
	firstderivative => &deg2rad(1.23456789e-8),
	secondderivative => &deg2rad(1.23456789e-20),
	bstardrag => 8.2345e-5,
	ephemeristype => 0,
	ascendingnode => &deg2rad(159.8765),
	argumentofperigee => &deg2rad(198.7654),
	meananomaly => &deg2rad(279.8765),
	elementnumber => 456,
	revolutionsatepoch => 56789,
    ),
<<'EOD', 'List output' );
 25544 ISS                      2008-10-09 10:53:02 01:31:36
EOD

$tst->method_is( 'location', '', 'Location title' );
$tst->method_is( 'location', $sta, <<'EOD', 'Location' );
Location: 1600 Pennsylvania Ave NW, Washington DC 20502
          Latitude 38.8987, longitude -77.0377, height 17 m
EOD

$tst->method_is( 'pass', <<'EOD', 'Pass title' );
    time eleva  azimuth      range latitude longitude altitud illum event
EOD
$tst->method_is( 'pass', @pass, <<'EOD', 'Pass' );

 25544 - ISS  2008-10-09
23:23:41  27.5 153.8 SE      703.5  34.0765  -74.2084   353.9 lit   apls
23:23:41  29.2 151.2 SE   389093.9        2.9 degrees from Moon
EOD

$tst->method_is( 'phase', <<'EOD', 'Phase title' );
                             phas                  fract
      date     time     name angl phase              lit
EOD
$tst->method_is( 'phase', $moon, <<'EOD', 'Phase' );
2008-10-09 23:23:41     Moon  119 waxing gibbous     74%
EOD

$tst->method_is( 'position', <<'EOD', 'Position title' );
            name eleva  azimuth      range               epoch illum
EOD
$tst->method_is( 'position', {
	body => $moon,
	station => $sta,
    }, <<'EOD', 'Position' );
2008-10-09 23:23:41
            Moon  29.2 151.2 SE   389093.9
EOD

# TODO position given Iridium satellite, preferably flaring

$tst->method_is( 'tle', '', 'TLE title (none)' );
$tst->method_is( 'tle', $body, <<'EOD', 'TLE' );
ISS --effective 2008/283/10:23:02.000
1 25544U 98067A   08283.45349537  .00007111 10240-12  82345-4 0  4565
2 25544  51.6426 159.8765 0004029 198.7654 279.8765 15.72108062567893
EOD

$tst->method_is( 'tle_verbose', '', 'TLE verbose title (none)' );
$tst->method_is( 'tle_verbose', $body, <<'EOD', 'TLE verbose' );
NORAD ID: 25544
    Name: ISS
    International launch designator: 98067A
    Epoch of data: 2008-10-09 10:53:02 GMT
    Effective date of data: 2008-10-09 10:23:02 GMT
    Classification status: U
    Mean motion: 3.930270155 degrees/minute
    First derivative of motion: 1.23456789e-08 degrees/minute squared
    Second derivative of motion: 1.23456789e-20 degrees/minute cubed
    B Star drag term: 8.2345e-05
    Ephemeris type: 0
    Inclination of orbit: 51.6426 degrees
    Right ascension of ascending node: 10:39:30.360000
    Eccentricity:  0.00040
    Argument of perigee: 198.7654 degrees from ascending node
    Mean anomaly: 279.8765 degrees
    Element set number: 456
    Revolutions at epoch: 56789
    Period (derived): 01:31:36
    Semimajor axis (derived): 6731.51857320361 kilometers
    Perigee altitude (derived): 350.669444370469 kilometers
    Apogee altitude (derived): 356.093702036757 kilometers
EOD

1;

# ex: set textwidth=72 :
