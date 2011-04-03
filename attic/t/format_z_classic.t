package main;

use strict;
use warnings;

use lib qw{ inc };

use Astro::App::Satpass2::Test::Format;
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


my $tst = Astro::App::Satpass2::Test::Format->new( 'Astro::App::Satpass2::Format::Classic' );

$tst->plan( tests => 334 );

$tst->require_ok();

$tst->can_ok( 'new' );

$tst->can_ok( 'date_format' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'local_coord' );
$tst->can_ok( 'provider' );
$tst->can_ok( 'time_format' );
$tst->can_ok( 'tz' );

$tst->can_ok( 'alias' );
$tst->can_ok( 'almanac' );
$tst->can_ok( 'flare' );
$tst->can_ok( 'list' );
$tst->can_ok( 'location' );
$tst->can_ok( 'pass' );
$tst->can_ok( 'phase' );
$tst->can_ok( 'position' );
$tst->can_ok( 'tle' );
$tst->can_ok( 'tle_verbose' );

$tst->can_ok( 'template' );

$tst->new_ok();

$tst->method_fail( template => local_coord => '%pass',
    'Circular reference to local_coord in pass from local_coord',
    'Setting circular template reference should fail',
);

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
$tst->format_setup( almanac => almanac => \@almanac );

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
	body => $body,
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

$tst->method( template => pass_start => '' );	# Supress pass OID.
$tst->method( template => pass_appulse => undef );	# Supress appulsed body.

$tst->format_setup( pass => pass => \@pass );

$tst->note( '%altitude;' );

$tst->format_is( '%altitude;', "Altitud\n  353.9",
    'Altitude of satellite (no effector args)' );
$tst->format_is( '%altitude();', "Altitud\n  353.9",
    'Altitude of satellite (empty effector args)' );
$tst->format_is( '%*altitude();', "Altitude\n353.9",
    'Altitude of satellite (glob field width)' );
$tst->format_is( '%*.*altitude();', "Altitude\n353.9",
    'Altitude of satellite (glob field width and decimal places)' );
$tst->format_is( '%altitude(body);', "Altitud\n  353.9",
    q{Altitude of satellite (explicit 'body')} );
$tst->format_is( '%altitude(center);', " Center\nAltitud",
    'Altitude of flare center (unavailable)' );
$tst->format_is( '%*altitude(center);', 'Center Altitude',
    'Altitude of flare center (glob field width, still unavailable)' );
$tst->format_is( '%*altitude(center);', 'Center Altitude',
    'Altitude of flare center (glob field width and decimal places, ditto)' );
$tst->format_is( '%*altitude(center,missing=unavailable);',
    "Center Altitude\nunavailable",
    q{Altitude of flare center ('missing=unavailable')} );
$tst->format_is( '%8altitude(appulse);', " Appulse\nAltitude\n385877.8",
    'Altitude of appulsed body' );
$tst->format_is( '%altitude(station);', "Station\nAltitud\n    0.0",
    'Altitude of station' );
$tst->format_is( '%.0altitude(station,units=meters);',
    "Station\nAltitud\n     17",
    'Altitude of station in meters' );

$tst->note( '%angle;' );

# TODO test mirror angle (when it is actually available)

$tst->format_is( '%angle', 'Angl', 'Mirror angle unavailable' );
$tst->format_is( '%angle(appulse);', "Appu\nAngl\n 2.9", 'Appulse angle' );
$tst->format_fail( '%angle(center);', '%angle(center) is not allowed',
    'Center angle is not allowed');
$tst->format_fail( '%angle(station);', '%angle(station) is not allowed',
    'Station angle is not allowed');

$tst->note( '%apoapsis;' );

$tst->format_is('%apoapsis;', "Apoaps\n   356", 'Apoapsis of satellite');
$tst->format_is('%apoapsis(center);', "Center\nApoaps",
    'Apoapsis of flare center (unavailable)');
$tst->format_is('%apoapsis(appulse);', "Appuls\nApoaps",
    'Apoapsis of appulsed body (unavailable)');
$tst->format_is('%apoapsis(station);', "Statio\nApoaps",
    'Apoapsis of station (unavailable)');
$tst->format_is('%apoapsis(earth);', "Apoaps\n  6734",
    'Apoapsis of satellite from center of Earth');
$tst->format_is('%apoapsis(center,earth);', "Center\nApoaps",
    'Apoapsis of flare center from center of Earth (unavailable)');
$tst->format_is('%apoapsis(appulse,earth);', "Appuls\nApoaps",
    'Apoapsis of appulsed body from center of Earth (unavailable)');
$tst->format_is('%apoapsis(station,earth);', "Statio\nApoaps",
    'Apoapsis of station from center of Earth (unavailable)');

$tst->note( '%apogee;' );

$tst->format_is('%apogee;', "Apogee\n   356", 'Apogee of satellite');
$tst->format_is('%apogee(center);', "Center\nApogee",
    'Apogee of flare center (unavailable)');
$tst->format_is('%apogee(appulse);', "Appuls\nApogee",
    'Apogee of appulsed body (unavailable)');
$tst->format_is('%apogee(station);', "Statio\nApogee",
    'Apogee of station (unavailable)');
$tst->format_is('%apogee(earth);', "Apogee\n  6734",
    'Apogee of satellite from center of Earth');
$tst->format_is('%apogee(center,earth);', "Center\nApogee",
    'Apogee of flare center from center of Earth (unavailable)');
$tst->format_is('%apogee(appulse,earth);', "Appuls\nApogee",
    'Apogee of appulsed body from center of Earth (unavailable)');
$tst->format_is('%apogee(station,earth);', "Statio\nApogee",
    'Apogee of station from center of Earth (unavailable)');

$tst->note( '%argumentofperigee;' );

$tst->format_is('%argumentofperigee;',
    " Argument\n       of\n  Perigee\n 198.7654",
    'Argument of perigee of satellite');
$tst->format_is('%argumentofperigee(center);',
    "   Center\n Argument\n       of\n  Perigee",
    'Argument of perigee of center (unavailable)');
$tst->format_is('%argumentofperigee(appulse);',
    "  Appulse\n Argument\n       of\n  Perigee",
    'Argument of perigee of appulse (unavailable)');
$tst->format_is('%argumentofperigee(station);',
    "  Station\n Argument\n       of\n  Perigee",
    'Argument of perigee of station (unavailable)');

$tst->note( '%ascendingnode;' );
$tst->format_is('%ascendingnode;',
    "  Ascending\n       Node\n10:39:30.36",
    'Ascending node of satellite');
$tst->format_is('%9.4ascendingnode(units=degrees);',
    "Ascending\n     Node\n 159.8765",
    'Ascending node of satellite (degrees)');
$tst->format_is('%ascendingnode(center);',
    "     Center\n  Ascending\n       Node",
    'Ascending node of center (unavailable)');
$tst->format_is('%ascendingnode(appulse);',
    "    Appulse\n  Ascending\n       Node",
    'Ascending node of appulse (unavailable)');
$tst->format_is('%ascendingnode(station);',
    "    Station\n  Ascending\n       Node",
    'Ascending node of station (unavailable)');

$tst->note( '%azimuth;' );

$tst->format_is('%azimuth;', "Azimu\n153.8", 'Azimuth of satellite');
$tst->format_is('%azimuth(bearing);', " Azimuth\n153.8 SE",
    'Azimuth of satellite, with bearing');
$tst->format_is('%azimuth(bearing=3);', "  Azimuth\n153.8 SSE",
    'Azimuth of satellite, with three-character bearing');
$tst->format_is('%2azimuth(units=bearing);', "Az\nSE",
    'Azimuth of satellite, as bearing');
$tst->format_is('%azimuth(center);', "Cente\nAzimu",
    'Azimuth of center (unavailable)');
$tst->format_is('%azimuth(center,bearing);', "  Center\n Azimuth",
    'Azimuth of center, with bearing (unavailable)');
$tst->format_is('%azimuth(appulse);', "Appul\nAzimu\n151.2",
    'Azimuth of appulsed body');
$tst->format_is('%azimuth(appulse,bearing);',
    " Appulse\n Azimuth\n151.2 SE",
    'Azimuth of appulsed body, with bearing');
$tst->format_is('%azimuth(station);', "Stati\nAzimu\n335.5",
    'Azimuth of station from satellite');
$tst->format_is('%azimuth(station,bearing);',
    " Station\n Azimuth\n335.5 NW",
    'Azimuth of station from satellite, with bearing');

$tst->note( '%bstardrag;' );

$tst->format_is('%bstardrag;', "    B* Drag\n 8.2345e-05",
    'B* drag of satellite');
$tst->format_is('%bstardrag(center);',  "  Center B*\n       Drag",
    'B* drag of center (unavailable)');
$tst->format_is('%bstardrag(appulse);', " Appulse B*\n       Drag",
    'B* drag of appulse (unavailable)');
$tst->format_is('%bstardrag(station);', " Station B*\n       Drag",
    'B* drag of station (unavailable)');

$tst->note( '%classification;' );

$tst->format_is('%classification;', "\nU", 'Classification of satellite');
$tst->format_is('%classification(center);', '',
    'Classification of flare center (unavailable)');
$tst->format_is('%classification(appulse);', '',
    'Classification of appulsed body (unavailable)');
$tst->format_is('%classification(station);', '',
    'Classification of station (unavailable)');

$tst->note( '%date;' );

$tst->format_is('%date(units=gmt);', "      Date\n2008-10-09", 'Date');
$tst->format_is('%*.5date(units=julian);', "Date\n2454749.47478",
    'Date as Julian day');
$tst->format_is('%*.5date(units=days_since_epoch);',
    sprintf( "Date\n%.5f", ($time - $epoch)/86400 ),
    'Date as days since epoch');
$tst->format_is('%date(appulse,units=gmt);', 
    "   Appulse\n      Date\n2008-10-09",
    'Date(appulse) is normally the same as date');
$tst->format_is('%date(appulse,units=days_since_epoch)',
    "   Appulse\n      Date",
    'Date(appulse,units=days_since_epoch is blank, since no appulse epoch');
$tst->format_fail('%date(center);', '%date(center) is not allowed',
    'Center date is not allowed');
$tst->format_fail('%date(station);', '%date(station) is not allowed',
    'Station date is not allowed');

$tst->note( '%declination;' );

$tst->format_is('%declination(earth);', "Decli\n 33.9",
    'Declination, from center of Earth');
$tst->format_is('%declination;', "Decli\n-19.2",
    'Declination, from station');
$tst->format_is('%declination(center,earth);', "Cente\nDecli",
    'Declination of flare center, from center of Earth');
$tst->format_is('%declination(center);', "Cente\nDecli",
    'Declination of flare center, from station');
$tst->format_is('%declination(appulse,earth);',
    "Appul\nDecli\n-16.1",
    'Declination of appulsed, from center of Earth');
$tst->format_is('%declination(appulse);', 
    "Appul\nDecli\n-16.8",
    'Declination of appulsed, from station');
$tst->format_is('%declination(station,earth);', "Stati\nDecli\n 38.7",
    'Declination of station, from center of Earth');
$tst->format_is('%declination(station);', "Stati\nDecli\n 19.2",
    'Declination of station, from satellite');

$tst->note( '%eccentricity' );

$tst->format_is('%eccentricity;', "Eccentri\n 0.00040",
    'Eccentricity of satellite');
$tst->format_is('%eccentricity(center);', "  Center\nEccentri",
    'Eccentricity of center (unavailable)');
$tst->format_is('%eccentricity(appulse);', " Appulse\nEccentri",
    'Eccentricity of appulse (unavailable)');
$tst->format_is('%eccentricity(station);', " Station\nEccentri",
    'Eccentricity of station (unavailable)');

$tst->note( '%eci_x;' );

$tst->format_is('%eci_x;', "     ECI x\n    2416.6",
    'Satellite Earth-centered inertial X');
$tst->format_is('%eci_x(center);', "Center ECI\n         x",
    'Center Earth-centered inertial X (unavailable)');
$tst->format_is('%eci_x(appulse);',
    "   Appulse\n     ECI x\n  282759.2",
    'Appulse Earth-centered inertial X');
$tst->format_is('%eci_x(station);',
    "   Station\n     ECI x\n    1928.2",
    'Station Earth-centered inertial X');

$tst->note( '%eci_y;' );

$tst->format_is('%eci_y;', "     ECI y\n   -5031.4",
    'Satellite Earth-centered inertial Y');
$tst->format_is('%eci_y(center);', "Center ECI\n         y",
    'Center Earth-centered inertial Y (unavailable)');
$tst->format_is('%eci_y(appulse);',
    "   Appulse\n     ECI y\n -249276.5",
    'Appulse Earth-centered inertial Y');
$tst->format_is('%eci_y(station);',
    "   Station\n     ECI y\n   -4581.2",
    'Station Earth-centered inertial Y');

$tst->note( '%eci_z;' );

$tst->format_is('%eci_z;', "     ECI z\n    3751.8",
    'Satellite Earth-centered inertial Z');
$tst->format_is('%eci_z(center);', "Center ECI\n         z",
    'Center Earth-centered inertial Z (unavailable)');
$tst->format_is('%eci_z(appulse);',
    "   Appulse\n     ECI z\n -108498.3",
    'Appulse Earth-centered inertial Z');
$tst->format_is('%eci_z(station);',
    "   Station\n     ECI z\n    3983.6",
    'Station Earth-centered inertial Z');

$tst->note( '%effective' );

$tst->format_is('%effective(units=zulu);',
    "     Effective Date\n2008-10-09 10:23:02",
    q{Effective date of satellite data (using 'zulu' as alias for 'gmt')});
$tst->format_is('%*.5effective(units=julian);',
    "Effective Date\n2454748.93266",
    'Effective date of satellite data as Julian day');
$tst->format_is('%-effective(units=days_since_epoch);',
    "Effective Date\n-0.020833",
    'Effective date as days since epoch');
$tst->format_is('%effective(center);',
    "   Center Effective\n               Date",
    'Effective date of center (unavailable)');
$tst->format_is('%effective(appulse);',
    "  Appulse Effective\n               Date",
    'Effective date of appulsed body (unavailable)');
$tst->format_is('%effective(station);',
    "  Station Effective\n               Date",
    'Effective date of station (unavailable)');

$tst->note( '%elementnumber' );

$tst->format_is('%elementnumber;', "Elem\n Set\nNumb\n 456",
    'Element set number of satellite');
$tst->format_is('%elementnumber(center);', "Cent\nElem\n Set\nNumb",
    'Element set number of center (unavailable)');
$tst->format_is('%elementnumber(appulse);', "Appu\nElem\n Set\nNumb",
    'Element set number of appulse (unavailable)');
$tst->format_is('%elementnumber(station);', "Stat\nElem\n Set\nNumb",
    'Element set number of station (unavailable)');

$tst->note( '%elevation' );

$tst->format_is('%elevation;', "Eleva\n 27.5",
    'Elevation of satellite');
$tst->format_is('%elevation(center);', "Cente\nEleva",
    'Elevation of flare center (unavailable)');
$tst->format_is('%elevation(appulse);', "Appul\nEleva\n 29.2",
    'Elevation of appulsed body');
$tst->format_is('%elevation(station);', "Stati\nEleva\n-32.8",
    'Elevation of station, from satellite');

$tst->note( '%ephemeristype;' );

$tst->format_is('%ephemeristype;', "E\nT\n0",
    'Ephemeris type of satellite');
$tst->format_is('%ephemeristype(center);', "C\nE\nT",
    'Ephemeris type of center (unavailable)');
$tst->format_is('%ephemeristype(appulse);', "A\nE\nT",
    'Ephemeris type of appulse (unavailable)');
$tst->format_is('%ephemeristype(station);', "S\nE\nT",
    'Ephemeris type of station (unavailable)');

$tst->note( '%epoch;' );

$tst->format_is('%epoch(units=zulu);',
    "              Epoch\n2008-10-09 10:53:02",
    q{Epoch of satellite data (using 'zulu' as alias for 'gmt')});
$tst->format_is('%*.5epoch(units=julian);',
    "Epoch\n2454748.95350",
    'Epoch of satellite data as Julian day');
$tst->format_fail('%epoch(units=days_since_epoch);',
    q{%epoch units 'days_since_epoch' not valid},
    'Epoch(units=days_since_epoch) forbidden (since it is always 0)');
$tst->format_is('%epoch(center);',
    "       Center Epoch",
    'Epoch of center (unavailable)');
$tst->format_is('%epoch(appulse);',
    "      Appulse Epoch",
    'Epoch of appulsed body (unavailable)');
$tst->format_is('%epoch(station);',
    "      Station Epoch",
    'Epoch of station (unavailable)');

$tst->note( '%event;' );

# Note that the following directly manipulates data inside the formatter
# object, using the references used to set that data. The author will
# not be responsible for what happens if anyone other than the author
# writes code that does this.

$tst->format_is('%event;', "Event\n apls", 'Event');
$pass[0]{events}[0]{event} = 0;
$tst->format_is('%event;', 'Event', 'Event (0)');
$pass[0]{events}[0]{event} = 1;
$tst->format_is('%event;', "Event\n shdw", 'Event (1)');
$pass[0]{events}[0]{event} = 2;
$tst->format_is('%event;', "Event\n  lit", 'Event (2)');
$pass[0]{events}[0]{event} = 3;
$tst->format_is('%event;', "Event\n  day", 'Event (3)');
$pass[0]{events}[0]{event} = 4;
$tst->format_is('%event;', "Event\n rise", 'Event (4)');
$pass[0]{events}[0]{event} = 5;
$tst->format_is('%event;', "Event\n  max", 'Event (5)');
$pass[0]{events}[0]{event} = 6;
$tst->format_is('%event;', "Event\n  set", 'Event (6)');
$pass[0]{events}[0]{event} = 7;
$tst->format_is('%event;', "Event\n apls", 'Event (7)');
$tst->format_fail('%event(appulse);', '%event(appulse) is not allowed',
    'Appulse event is not allowed');
$tst->format_fail('%event(center);', '%event(center) is not allowed',
    'Center event is not allowed');
$tst->format_fail('%event(station);', '%event(station) is not allowed',
    'Station event is not allowed');

$tst->note( '%firstderivative;' );

$tst->format_is('%firstderivative;',
    " First Derivative\n   of Mean Motion\n 1.2345678900e-08",
    'First derivative of satellite (degrees/minute**2)');
$tst->format_is('%firstderivative(center);',
    "     Center First\n    Derivative of\n      Mean Motion",
    'First derivative of center (unavailable)');
$tst->format_is('%firstderivative(appulse);',
    "    Appulse First\n    Derivative of\n      Mean Motion",
    'First derivative of appulse (unavailable)');
$tst->format_is('%firstderivative(station);',
    "    Station First\n    Derivative of\n      Mean Motion",
    'First derivative of station (unavailable)');

$tst->note( '%fraction_lit;' );

$tst->format_is('%fraction_lit;', "Frac\n Lit",
    'Fraction of object illuminated (unavailable)');
$tst->format_is('%fraction_lit(center);', "Cent\nFrac\n Lit",
    'Fraction of flare center illuminated (unavailable)');
$tst->format_is('%fraction_lit(appulse);', "Appu\nFrac\n Lit\n0.74",
    'Fraction of appulsed body illuminated');
$tst->format_is('%.0fraction_lit(appulse,units=percent);',
    "Appu\nFrac\n Lit\n  74%",
    'Percent of appulsed body illuminated');
$tst->format_is('%.0fraction_lit(appulse,units=percent,append= percent);',
    "Appu\nFrac\n Lit\n  74 percent",
    'Percent of appulsed body illuminated, override appended text');
$tst->format_is('%fraction_lit(station);', "Stat\nFrac\n Lit",
    'Fraction of station illuminated (unavailable)');

$tst->note( '%id;' );

$tst->format_is('%id;', "   OID\n 25544", 'OID of satellite');
$tst->format_is('%id(center);', "Center\n   OID",
    'OID of flare center (unavailable)');
$tst->format_is('%id(appulse);', "Appuls\n   OID\n  Moon",
    'OID of appulsed body');
$tst->format_is('%id(station);', "Statio\n   OID", 'OID of station');

$tst->note( '%illumination;' );

$tst->format_is('%illumination;', "Illum\n  lit",
    'Illumination (lit/shdw/day)');
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

$tst->format_is('%inclination;', "Inclinat\n 51.6426",
    'Inclination of satellite (degrees)');
$tst->format_is('%inclination(center);', "  Center\nInclinat",
    'Inclination of center (unavailable)');
$tst->format_is('%inclination(appulse);', " Appulse\nInclinat",
    'Inclination of appulse (unavailable)');
$tst->format_is('%inclination(station);', " Station\nInclinat",
    'Inclination of station (unavailable)');

$tst->note( '%international;' );

$tst->format_is('%international;',
    "Internat\n  Launch\nDesignat\n  98067A",
    'International launch designator');
$tst->format_is('%international(center);',
    "  Center\nInternat\n  Launch\nDesignat",
    'Int\'l launch desig of center (unavailable)');
$tst->format_is('%international(appulse);',
    " Appulse\nInternat\n  Launch\nDesignat",
    'Int\'l launch desig of appulse (unavailable)');
$tst->format_is('%international(station);',
    " Station\nInternat\n  Launch\nDesignat",
    'Int\'l launch desig of station (unavailable)');

$tst->note( '%latitude;' );

$tst->format_is('%latitude;', "Latitude\n 34.0765",
    'Latitude of satellite');
$tst->format_is('%latitude(center);', "  Center\nLatitude",
    'Latitude of center (unavailable)');
$tst->format_is('%latitude(appulse);', " Appulse\nLatitude\n-16.0592",
    'Latitude of appulsed body');
$tst->format_is('%latitude(station);', " Station\nLatitude\n 38.8987",
    'Latitude of station');

$tst->note( '%longitude;' );

$tst->format_is('%longitude;',
    "Longitude\n -74.2084",
    'Longitude of satellite');
$tst->format_is('%longitude(center);',
    "   Center\nLongitude",
    'Longitude of flare center (unavailable)');
$tst->format_is('%longitude(appulse);',
    "  Appulse\nLongitude\n -51.2625",
    'Longitude of appulsed body');
$tst->format_is('%longitude(station);',
    "  Station\nLongitude\n -77.0377",
    'Longitude of station');

$tst->note( '%magnitude;' );

# TODO flare magnitude, flare center magnitude.

$tst->format_is('%magnitude;', 'Magn', 'Magnitude (unavailable)');
$tst->format_fail('%magnitude(appulse);',
    '%magnitude(appulse) is not allowed',
    'Appulse magnitude is not allowed');
$tst->format_fail('%magnitude(station);',
    '%magnitude(station) is not allowed',
    'Station magnitude is not allowed');

$tst->note( '%meananomaly;' );

$tst->format_is('%meananomaly;', 
    "     Mean\n  Anomaly\n 279.8765",
    'Mean anomaly of satellite (degrees)');
$tst->format_is('%meananomaly(center);',
    "   Center\n     Mean\n  Anomaly",
    'Mean anomaly of center (unavailable)');
$tst->format_is('%meananomaly(appulse);',
    "  Appulse\n     Mean\n  Anomaly",
    'Mean anomaly of appulse (unavailable)');
$tst->format_is('%meananomaly(station);',
    "  Station\n     Mean\n  Anomaly",
    'Mean anomaly of station (unavailable)');

$tst->note( '%meanmotion' );

$tst->format_is('%meanmotion;', " Mean Motion\n3.9302701550",
    'Mean motion of satellite (degrees/minute)');
$tst->format_is('%meanmotion(center);', " Center Mean\n      Motion",
    'Mean motion of center (unavailable)');
$tst->format_is('%meanmotion(appulse);', "Appulse Mean\n      Motion",
    'Mean motion of appulse (unavailable)');
$tst->format_is('%meanmotion(station);', "Station Mean\n      Motion",
    'Mean motion of station (unavailable)');

$tst->note( '%mma;' );

# TODO actual flaring MMA from flare structure.

$tst->format_is('%mma;', 'MMA',
    'MMA or other flare source (unavailable)');
$tst->format_fail('%mma(appulse);', '%mma(appulse) is not allowed',
    'Appulse mma is not allowed');
$tst->format_fail('%mma(center);', '%mma(center) is not allowed',
    'Center mma is not allowed');
$tst->format_fail('%mma(station);', '%mma(station) is not allowed',
    'Station mma is not allowed');

$tst->note( '%name;' );

$tst->format_is('%-name;', "Name\nISS", 'Name of object');
$tst->format_is('%name(center);', '             Center Name',
    'Name of center (unavailable)');
$tst->format_is('%-name(appulse);', "Appulse Name\nMoon",
    'Name of appulsed body');
$tst->format_is('%-24name(station);',
    "Station Name\n1600 Pennsylvania Ave NW",
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

$tst->format_is('%percent;', "\n%", 'Literal percent');
$tst->format_fail('%percent(appulse);', '%percent(appulse) is not allowed',
    'Appulse percent is not allowed');
$tst->format_fail('%percent(center);', '%percent(center) is not allowed',
    'Center percent is not allowed');
$tst->format_fail('%percent(station);', '%percent(station) is not allowed',
    'Station percent is not allowed');

$tst->note( '%periapsis;' );

$tst->format_is('%periapsis;', "Periap\n   351",
    'Periapsis of satellite');
$tst->format_is('%periapsis(center);', "Center\nPeriap",
    'Periapsis of flare center (unavailable)');
$tst->format_is('%periapsis(appulse);', "Appuls\nPeriap",
    'Periapsis of appulsed body (unavailable)');
$tst->format_is('%periapsis(station);', "Statio\nPeriap",
    'Periapsis of station (unavailable)');
$tst->format_is('%periapsis(earth);', "Periap\n  6729",
    'Periapsis of satellite from center of Earth');
$tst->format_is('%periapsis(center,earth);', "Center\nPeriap",
    'Periapsis of flare center from center of Earth (unavailable)');
$tst->format_is('%periapsis(appulse,earth);', "Appuls\nPeriap",
    'Periapsis of appulsed body from center of Earth (unavailable)');
$tst->format_is('%periapsis(station,earth);', "Statio\nPeriap",
    'Periapsis of station from center of Earth (unavailable)');

$tst->note( '%perigee;' );

$tst->format_is('%perigee;', "Perige\n   351", 'Perigee of satellite');
$tst->format_is('%perigee(center);', "Center\nPerige",
    'Perigee of flare center (unavailable)');
$tst->format_is('%perigee(appulse);', "Appuls\nPerige",
    'Perigee of appulsed body (unavailable)');
$tst->format_is('%perigee(station);', "Statio\nPerige",
    'Perigee of station (unavailable)');
$tst->format_is('%perigee(earth);', "Perige\n  6729",
    'Perigee of satellite from center of Earth');
$tst->format_is('%perigee(center,earth);', "Center\nPerige",
    'Perigee of flare center from center of Earth (unavailable)');
$tst->format_is('%perigee(appulse,earth);', "Appuls\nPerige",
    'Perigee of appulsed body from center of Earth (unavailable)');
$tst->format_is('%perigee(station,earth);', "Statio\nPerige",
    'Perigee of station from center of Earth (unavailable)');

$tst->note( '%period;' );

$tst->format_is('%period;', "      Period\n    01:31:36",
    'Period of satellite');
$tst->format_is('%*.0period(units=seconds);', "Period\n5496",
    'Period of satellite in seconds');
$tst->format_is('%*.2period(units=minutes);', "Period\n91.61",
    'Period of satellite in minutes');
$tst->format_is('%*.3period(units=hours);', "Period\n1.527",
    'Period of satellite in hours');
$tst->format_is('%*.5period(units=days);', "Period\n0.06362",
    'Period of satellite in days');
$tst->format_is('%period(center);', "      Center\n      Period",
    'Period of center (unavailable)');
$tst->format_is('%period(appulse);',
    "     Appulse\n      Period\n 27 07:43:12",
    'Period of appulsed body');
$tst->format_is('%period(station);', "     Station\n      Period",
    'Period of station (unavailable)');

$tst->note( '%phase;' );

$tst->format_is('%phase;', 'Phas', 'Phase of satellite (unavailable)');
$tst->format_is('%phase(units=phase);', 'Phas',
    'Phase of satellite as string (unavailable)');
$tst->format_is('%phase(center);', "Cent\nPhas",
    'Phase of center (unavailable)');
$tst->format_is('%phase(center,units=phase);', "Cent\nPhas",
    'Phase of center as string (unavailable)');
$tst->format_is('%phase(appulse);', "Appu\nPhas\n 119",
    'Phase of appulsed body');
$tst->format_is('%-24phase(appulse,units=phase);',
    "Appulse Phase\nwaxing gibbous",
    'Phase of appulsed body as string');
$tst->format_is('%phase(station);', "Stat\nPhas",
    'Phase of station (unavailable)');
$tst->format_is('%phase(station,units=phase);', "Stat\nPhas",
    'Phase of station as string (unavailable)');

# TODO %provider;

$tst->note( '%range;' );

$tst->format_is('%range;', "     Range\n     703.5",
    'Range of satellite');
$tst->format_is('%.0range(units=meters);', "     Range\n    703549",
    'Range of satellite in meters');
$tst->format_is('%range(center);', "    Center\n     Range",
    'Range of center (unavailable)');
$tst->format_is('%range(appulse);', "   Appulse\n     Range\n  389093.9",
    'Range of appulsed body');
$tst->format_is('%range(station);', "   Station\n     Range\n     703.5",
    'Range of station (from satellite)');

$tst->note( '%revolutionsatepoch;' );

$tst->format_is('%revolutionsatepoch;', 
    "Revolu\n    at\n Epoch\n 56789",
    'Revolutions at epoch of satellite');
$tst->format_is('%revolutionsatepoch(center);',
    "Center\nRevolu\n    at\n Epoch",
    'Revolutions at epoch of center (unavailable)');
$tst->format_is('%revolutionsatepoch(appulse);',
    "Appuls\nRevolu\n    at\n Epoch",
    'Revolutions at epoch of appulse (unavailable)');
$tst->format_is('%revolutionsatepoch(station);',
    "Statio\nRevolu\n    at\n Epoch",
    'Revolutions at epoch of station (unavailable)');

$tst->note( '%right_ascension;' );

$tst->format_is('%right_ascension(earth);',
    "   Right\nAscensio\n19:42:37",
    'Right ascension, from center of Earth');
$tst->format_is('%right_ascension;',
    "   Right\nAscensio\n21:09:19",
    'Right ascension, from station');
$tst->format_is('%right_ascension(center,earth);',
    "  Center\n   Right\nAscensio",
    'Right ascension of flare center, from center of Earth');
$tst->format_is('%right_ascension(center);',
    "  Center\n   Right\nAscensio",
    'Right ascension of flare center, from station');
$tst->format_is('%right_ascension(appulse,earth);',
    " Appulse\n   Right\nAscensio\n21:14:24",
    'Right ascension of appulsed, from center of Earth');
$tst->format_is('%right_ascension(appulse);',
    " Appulse\n   Right\nAscensio\n21:15:44",
    'Right ascension of appulsed, from station');
$tst->format_is('%right_ascension(station,earth);',
    " Station\n   Right\nAscensio\n19:31:18",
    'Right ascension of station, from center of Earth');
$tst->format_is('%right_ascension(station);',
    " Station\n   Right\nAscensio\n09:09:19",
    'Right ascension of station, from satellite');

$tst->note( '%secondderivative;' );

$tst->format_is('%secondderivative;',
    "Second Derivative\n   of Mean Motion\n 1.2345678900e-20",
    'Second derivative of satellite (degrees/minute**3)');
$tst->format_is('%secondderivative(center);',
    "    Center Second\n    Derivative of\n      Mean Motion",
    'Second derivative of center (unavailable)');
$tst->format_is('%secondderivative(appulse);',
    "   Appulse Second\n    Derivative of\n      Mean Motion",
    'Second derivative of appulse (unavailable)');
$tst->format_is('%secondderivative(station);',
    "   Station Second\n    Derivative of\n      Mean Motion",
    'Second derivative of station (unavailable)');

$tst->note( '%semimajor;' );

$tst->format_is('%semimajor;', "Semima\n  Axis\n  6732",
    'Semimajor axis of satellite');
$tst->format_is('%semimajor(center);', "Center\nSemima\n  Axis",
    'Semimajor axis of flare center (unavailable)');
$tst->format_is('%semimajor(appulse);', "Appuls\nSemima\n  Axis",
    'Semimajor axis of appulsed body (unavailable)');
$tst->format_is('%semimajor(station);', "Statio\nSemima\n  Axis",
    'Semimajor axis of station (unavailable)');

$tst->note( '%semiminor;' );

$tst->format_is('%semiminor;', "Semimi\n  Axis\n  6732",
    'Semiminor axis of satellite');
$tst->format_is('%semiminor(center);', "Center\nSemimi\n  Axis",
    'Semiminor axis of flare center (unavailable)');
$tst->format_is('%semiminor(appulse);', "Appuls\nSemimi\n  Axis",
    'Semiminor axis of appulsed body (unavailable)');
$tst->format_is('%semiminor(station);', "Statio\nSemimi\n  Axis",
    'Semiminor axis of station (unavailable)');

$tst->note( '%space;' );

$tst->format_is('%space;.', " .\n .", 'A single space');
$tst->format_is('%3space;.', "   .\n   .", 'Three spaces');
$tst->format_fail('%space(appulse);', '%space(appulse) is not allowed',
    'Appulse space is not allowed');
$tst->format_fail('%space(center);', '%space(center) is not allowed',
    'Center space is not allowed');
$tst->format_fail('%space(station);', '%space(station) is not allowed',
    'Station space is not allowed');

$tst->note( '%status;' );

# TODO test actual Iridium status.

$tst->format_is('%status;',
    '                                                      Status',
    'Status of satellite (unavailable)');
$tst->format_fail('%status(appulse);', '%status(appulse) is not allowed',
    'Appulse status is not allowed');
$tst->format_fail('%status(center);', '%status(center) is not allowed',
    'Center status is not allowed');
$tst->format_fail('%status(station);', '%status(station) is not allowed',
    'Station status is not allowed');

$tst->note( '%time;' );

$tst->format_is('%time(units=gmt);', "    Time\n23:23:41", 'Time of day');
$tst->format_is('%*.5time(units=julian);', "Time\n2454749.47478",
    'Time as Julian day (same as %date;)');
$tst->format_is('%time;', "    Time\n23:23:41",	# gmt should
    'Time of day');				# already be set
$tst->method_is( effectors_used => 'pass', { time => 1 },
    'Format effectors used by pass (right now)' );
$tst->format_is('%time(appulse,units=gmt);',
    " Appulse\n    Time\n23:23:41",
    'Time(appulse) is usually the same as time');
$tst->format_fail('%time(center);', '%time(center) is not allowed',
    'Center time is not allowed');
$tst->format_fail('%time(station);', '%time(station) is not allowed',
    'Station time is not allowed');
$tst->method_ok( gmt => 0, 'Can turn off gmt' );
SKIP: {
    eval {
	require Astro::App::Satpass2::FormatTime::DateTime::Strftime;
	1;
    } or $tst->skip ( 'DateTime not available', 3 );
    $tst->method_ok( tz => 'CST6CDT', 'Can set zone to Central US' );
    $tst->format_is( '%time', "    Time\n18:23:41",
	'Time of day (Central US)' );
    $tst->method_ok( tz => undef, 'Can make zone undef' );
}
$tst->method_ok( gmt => 1, 'Can turn gmt back on' );
$tst->format_is('%time;', "    Time\n23:23:41",
    'Time of day (round trip on tz)');

$tst->format_is('%tle;', <<'EOD', 'TLE of satellite');

ISS --effective 2008/283/10:23:02.000
1 25544U 98067A   08283.45349537  .00007111 10240-12  82345-4 0  4565
2 25544  51.6426 159.8765 0004029 198.7654 279.8765 15.72108062567893
EOD

$tst->method_ok( format_effector =>
    status => missing => '<none>',
    'Set new missing text for %status' );
$tst->format_is('%-status;', "Status\n<none>",
    'Status of satellite ("<none>")');
$tst->method_ok( format_effector =>
    status => missing => undef,
    'Restore default missing text for %status' );
$tst->format_is('%status;',
    '                                                      Status',
    'Status of satellite ("")');

$tst->method_ok( format_effector =>
    perigee => places => 1,
    'Set new decimal places for %perigee' );
$tst->format_is('%perigee;', "Perige\n 350.7",
    'Perigee of satellite (1 decimal place)');
$tst->method_ok( format_effector =>
    perigee => places => undef,
    'Restore default decimal places for %perigee' );
$tst->format_is('%perigee;', "Perige\n   351",
    'Perigee of satellite (default decimal places)');

$tst->method_ok( format_effector =>
    perigee => units => 'miles',
    'Set new units for %perigee' );
$tst->format_is('%perigee;', "Perige\n   218",
    'Perigee of satellite (in miles)');
$tst->method_ok( format_effector =>
    perigee => units => undef,
    'Restore default units for %perigee' );
$tst->format_is('%perigee;', "Perige\n   351",
    'Perigee of satellite (default units)');
$tst->format_is('%perigee(units=miles);', "Perige\n   218",
    'Perigee of satellite (explicitly in miles)' );

$tst->method_ok( format_effector =>
    perigee => width => 8,
    'Set new field width for %perigee' );
$tst->format_is('%perigee;', " Perigee\n     351",
    'Perigee of satellite (field width 8)');
$tst->method_ok( format_effector =>
    perigee => width => undef,
    'Restore default decimal width for %perigee' );
$tst->format_is('%perigee;', "Perige\n   351",
    'Perigee of satellite (default field width)');

# Recursive template data expansion better with pass

$tst->note( 'Recursive template expansion' );
$tst->format_setup( pass => pass => \@pass );

$tst->format_is('%azel',
    "Eleva  Azimuth\n 27.5 153.8 SE",
    'Expand template azel (data)');
$tst->format_is('%equatorial',
    "   Right\nAscensio Decli\n21:09:19 -19.2",
    'Expand template equatorial (data)');
$tst->method_ok( template => local_coord => '%azel',
    "Define template local_coord as '%azel'");
$tst->format_is('%local_coord',
    "Eleva  Azimuth\n 27.5 153.8 SE",
    'Expand template local_coord (defined as %azel)');
$tst->method_ok( template => local_coord => '%equatorial',
    "Define template local_coord as '%equatorial'");
$tst->format_is('%local_coord',
    "   Right\nAscensio Decli\n21:09:19 -19.2",
    'Expand template local_coord (now defined as %equatorial)');
$tst->method_ok( template => azel => '%elevation($*) %azimuth($*,bearing)',
    'Redefine template azel as elevation and azimuth, with argument');
$tst->format_is('%azel',
    "Eleva  Azimuth\n 27.5 153.8 SE",
    'Expand template azel with no argument');
$tst->format_is('%azel(body)',
    "Eleva  Azimuth\n 27.5 153.8 SE",
    'Expand template azel with argument (body)');
$tst->format_is('%azel(appulse)',
    "Appul  Appulse\nEleva  Azimuth\n 29.2 151.2 SE",
    'Expand template azel with argument (appulse)');

$tst->note( 'Actual default output' );
$tst->note( 'We create a new object for this, to restore defaults' );

$tst->new_ok();

$tst->format_setup( almanac => almanac => \@almanac );

$tst->method_is( almanac => \@almanac, '2009-04-01 10:52:31 Sunrise',
    'Default almanac output' );

# TODO flare

# We use a new object here because the 'inertial' setting appears to be
# sticky. Will have to look into this in Astro::Coord::ECI::TLE.
$tst->method_is( list => [
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
    ) ],
<<'EOD', 'List output' );
   OID Name                     Epoch               Period
 25544 ISS                      2008-10-09 10:53:02 01:31:36
EOD

$tst->method_is( 'location', $sta, <<'EOD', 'Location' );
Location: 1600 Pennsylvania Ave NW, Washington DC 20502
          Latitude 38.8987, longitude -77.0377, height 17 m
EOD

$tst->method_is( 'pass', \@pass, <<'EOD', 'Pass' );
    Time Eleva  Azimuth      Range Latitude Longitude Altitud Illum Event

2008-10-09     25544 - ISS
23:23:41  27.5 153.8 SE      703.5  34.0765  -74.2084   353.9 lit   apls
23:23:41  29.2 151.2 SE   389093.9        2.9 degrees from Moon
EOD


$tst->method_is( 'phase', [ $moon ], <<'EOD', 'Phase' );
                             Phas                  Frac
      Date     Time     Name Angl Phase             Lit
2008-10-09 23:23:41     Moon  119 waxing gibbous     74%
EOD

$tst->method_is( 'position', {
	bodies => [ $moon ],
	station => $sta,
	time	=> $time,
    }, <<'EOD', 'Position' );
2008-10-09 23:23:41
            Name Eleva  Azimuth      Range               Epoch Illum
            Moon  29.2 151.2 SE   389093.9
EOD

# TODO position given Iridium satellite, preferably flaring

$tst->method_is( 'tle', [ $body ], <<'EOD', 'TLE' );
ISS --effective 2008/283/10:23:02.000
1 25544U 98067A   08283.45349537  .00007111 10240-12  82345-4 0  4565
2 25544  51.6426 159.8765 0004029 198.7654 279.8765 15.72108062567893
EOD

$tst->method_is( 'tle_verbose', [ $body ], <<'EOD', 'TLE verbose' );
NORAD ID: 25544
    Name: ISS
    International launch designator: 98067A
    Epoch of data: 2008-10-09 10:53:02 GMT
    Effective date of data: 2008-10-09 10:23:02 GMT
    Classification status: U
    Mean motion: 3.93027015 degrees/minute
    First derivative of motion: 1.23456789e-08 degrees/minute squared
    Second derivative of motion: 1.23457e-20 degrees/minute cubed
    B Star drag term: 8.23450e-05
    Ephemeris type: 0
    Inclination of orbit: 51.6426 degrees
    Right ascension of ascending node: 10:39:30
    Eccentricity: 0.0004029
    Argument of perigee: 198.7654 degrees from ascending node
    Mean anomaly: 279.8765 degrees
    Element set number: 456
    Revolutions at epoch: 56789
    Period (derived): 01:31:36
    Semimajor axis (derived): 6731.5 kilometers
    Perigee altitude (derived): 350.7 kilometers
    Apogee altitude (derived): 356.1 kilometers
EOD

1;

# ex: set textwidth=72 :
