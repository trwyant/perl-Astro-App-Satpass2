package main;

use strict;
use warnings;

use Test::More 0.40;

BEGIN {
    my @failures;
    foreach my $module ( qw{ Cwd File::Spec File::Temp IO::File } ) {
	eval "require $module; $module->import(); 1"
	    or push @failures, $module;
    }
    if ( @failures ) {
	plan( skip_all => 'Can not load ' . join ', ', @failures );
	exit;
    }
}

$| = 1;

plan( tests => 159 );

require_ok( 'App::Satpass2' )
    or BAIL_OUT( "Can not continue without loading App::Satpass2" );

my $app = App::Satpass2->new();
isa_ok($app, 'App::Satpass2')
    or BAIL_OUT("Can not continue without App::Satpass2 object");
$app->set(
    autoheight => undef,
    gmt => 1,
    stdout => undef,
);

{
    my $fh = File::Temp->new();
    my $fn = $fh->filename;
    eval {$app->execute("echo Madam, I\\'m Adam >$fn")};
    my $got = $@ || do {
	local $/ = undef;
	$fh->seek(0, 0);
	<$fh>;
    };
    chomp $got;
    is($got, "Madam, I'm Adam", "Redirect output to a file");
    my $buffer;
    eval {$app->set(stdout => \$buffer);
	$app->execute("echo There was a young lady named Bright")};
    $got = $@ || $buffer;
    chomp $got;
    is($got, "There was a young lady named Bright", "Output to a scalar ref");
    $buffer = undef;
    eval {$app->set(stdout => sub {$buffer .= $_[0]});
	$app->execute("echo Who could travel much faster than light.")};
    $got = $@ || $buffer;
    chomp $got;
    is($got, "Who could travel much faster than light.", "Output to code");
    $buffer = [];
    eval {$app->set(stdout => $buffer);
	$app->execute("echo '    She set out one day'")};
    $got = $@ || join ('', @$buffer);
    chomp $got;
    is($got, "    She set out one day", "Output to an array ref");
    $got = eval {$app->set(stdout => undef);
	$app->execute("echo '    In a relative way'")};
    $@ and $got = $@;
    chomp $got;
    is($got, "    In a relative way", "Output returned");
    $got = eval {$app->execute('# And returned the previous night.')};
    $@ and $got = $@;
    is($got, undef, "Comments should be ignored");
    $got = eval {$app->execute(' ')};
    $@ and $got = $@;
    is($got, undef, "Blank lines should be ignored");

    SATPASS2_EXECUTE:
    {
	$got = undef;
	eval {$app->execute('exit')};
	$got = $@ || 'Failed to exit; no exception thrown';
    }
    is($got, undef, "Ability to exit.");

}

_app('set stdout STDOUT', "Attribute 'stdout' may not be set interactively",
    'Can not set stdout interactively');
_app(sub {$app->set(stdout => undef); undef}, undef,
    'Can set stdout programmatically');
_app('foo \'bar', 'Unclosed single quote', 'Bad command - unclosed quote');
_app('foo ${1', 'Missing right curly bracket',
	'Bad command - missing right curly');
_app('foo >>>bar', 'Syntax error near >>>',
	'Bad command - invalid redirect');
_app('foo', 'Unknown interactive method \'foo\'', 'Unknown interactive method');
_app('alias', <<eod, 'Default aliases');
iridium => Astro::Coord::ECI::TLE::Iridium
moon => Astro::Coord::ECI::Moon
sun => Astro::Coord::ECI::Sun
tle => Astro::Coord::ECI::TLE
eod
_app('alias fubar iridium', undef, 'Add an alias');
_app('alias', <<eod, 'Confirm addition of alias');
fubar => Astro::Coord::ECI::TLE::Iridium
iridium => Astro::Coord::ECI::TLE::Iridium
moon => Astro::Coord::ECI::Moon
sun => Astro::Coord::ECI::Sun
tle => Astro::Coord::ECI::TLE
eod
_app('alias fubar \'\'', undef, 'Remove new alias');
_app('alias', <<eod, 'Confirm alias removal');
iridium => Astro::Coord::ECI::TLE::Iridium
moon => Astro::Coord::ECI::Moon
sun => Astro::Coord::ECI::Sun
tle => Astro::Coord::ECI::TLE
eod
_app('set warn_on_empty 0', undef, 'No warning for empty lists');
_app('show appulse', 'set appulse 0', 'Default appulse value');
_app('set appulse 10', undef, 'Change appulse value to 10');
_app('show appulse', 'set appulse 10', 'Appulse value now 10');
_app('set latitude 51d28m38s', undef, 'Set latitude');
_app('show latitude', 'set latitude 51.4772222222222', 'Latitude value');
_app('set longitude 0', undef, 'Set longitude');
_app('show longitude', 'set longitude 0', 'Longitude value');
_app('set height 2', undef, 'Set height above sea level');
_app('show height', 'set height 2', 'Height above sea level');
_app('location', <<'EOD', 'Location command with no name');
Location:
          Latitude 51.4772, longitude 0.0000, height 2 m
EOD
_app("set location 'Royal Observatory, Greenwich England'",
    undef, "Set our location's name");
_app('show location',
    "set location 'Royal Observatory, Greenwich England'",
    "Location's name");
_app('location', <<'EOD', 'Location command with name');
Location: Royal Observatory, Greenwich England
          Latitude 51.4772, longitude 0.0000, height 2 m
EOD
_app('set date_format %Y/%m/%d time_format %H:%M:%S',
    undef, 'Set date and time format');
_app('show date_format', 'set date_format %Y/%m/%d', 'Show date format');
_app('show time_format', 'set time_format %H:%M:%S', 'Show time format');
_app("almanac '20090401T000000 UT'",
    <<eod, 'Almanac for April Fools 2009');
2009/04/01 00:04:00 local midnight
2009/04/01 01:17:47 Moon set
2009/04/01 05:01:29 begin twilight
2009/04/01 05:35:18 Sunrise
2009/04/01 08:23:38 Moon rise
2009/04/01 12:03:51 local noon
2009/04/01 17:21:29 Moon transits meridian
2009/04/01 18:33:28 Sunset
2009/04/01 19:07:26 end twilight
eod
_app('begin', undef, 'Begin local block');
_app('show horizon', 'set horizon 20', 'Confirm horizon setting');
_app('localize horizon', undef, 'Localize horizon');
_app('export horizon 15', undef, 'Export horizon, setting its value');
_app('show horizon', 'set horizon 15', 'Check that the horizon was set');
_app(sub {$ENV{horizon}}, '15', 'Check that the horizon setting was exported');
_app('set horizon 25', undef, 'Set horizon to 20' );
_app( 'show horizon', 'set horizon 25', 'Check new horizon value' );
_app( sub {$ENV{horizon}}, '25', 'Check new horizon exported' );
_app('end', undef, 'End local block');
_app( 'show horizon', 'set horizon 20', 'Check horizon back to 20' );
_app( sub {$ENV{horizon}}, '20', 'Check exported horizon at 20 also' );
_app('export BOGUS', 'You must specify a value',
    'Export of environment variable needs a value');
_app('export BOGUS froboz', undef, 'Export environment variable');
_app(sub {$ENV{BOGUS}}, 'froboz', 'Check that value was exported');
_app('echo Able was I, ere I saw Elba.',
    'Able was I, ere I saw Elba.', 'The echo command');
_app('echo Able \\',
    'was I, ere I saw Elba.',
    'Able was I, ere I saw Elba.',
    'Assembly of continued line.');
# TODO test flare (how without TLEs)?
# TODO test height when/if implemented
# TODO test help when/if implemented
_app('list', undef, 'The list command, with an empty list');
_app('load t/missing.dat', 'No files found',
    'Attempt to load non-existing file');
_app('load t/data.tle', undef, 'Load a TLE file');
_app('list', <<eod, 'List the loaded items');
   oid name                     epoch               period
 88888                          1980/10/01 23:41:24 01:29:37
 11801                          1980/08/17 07:06:40 10:30:08
eod
_app('choose 88888', undef, 'Keep OID 88888, losing all others');
_app('list', <<eod, 'Check that the list now includes only 88888');
   oid name                     epoch               period
 88888                          1980/10/01 23:41:24 01:29:37
eod
_app('tle', <<eod, 'List the TLE for object 888888');
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
eod
_app('clear', undef, 'Remove all items from the list');
_app('list', undef, 'Confirm that the list is empty again');
_app('load t/data.tle', undef, 'Load the TLE file again');
_app('tle', <<eod, 'List the loaded TLEs');
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
1 11801U          80230.29629788  .01431103  00000-0  14311-1
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848
eod
_app('drop 88888', undef, 'Drop object 88888');
_app('tle', <<eod, 'List the TLEs for object 11801');
1 11801U          80230.29629788  .01431103  00000-0  14311-1
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848
eod
_app('tle -verbose', <<eod, 'Verbose TLE for object 11801');
NORAD ID: 11801
    Name:
    International launch designator:
    Epoch of data: 1980/08/17 07:06:40 GMT
    Effective date of data: <none> GMT
    Classification status: U
    Mean motion: 0.57134462 degrees/minute
    First derivative of motion: 2.48455381944444e-06 degrees/minute squared
    Second derivative of motion: 0 degrees/minute cubed
    B Star drag term: 1.4311e-02
    Ephemeris type:
    Inclination of orbit: 46.7916 degrees
    Right ascension of ascending node: 15:21:44.496000
    Eccentricity:  0.73180
    Argument of perigee: 47.4722 degrees from ascending node
    Mean anomaly: 10.4117 degrees
    Element set number:
    Revolutions at epoch:
    Period (derived): 10:30:08
    Semimajor axis (derived): 24347.281726148 kilometers
    Perigee altitude (derived): 151.716308738674 kilometers
    Apogee altitude (derived): 35786.5731435573 kilometers
eod
_app('macro brief', undef, 'Brief macro listing, without macros');
_app('macro define place location', undef, "Define 'place' macro");
_app('macro brief', 'place', 'Brief macro listing, with a macro');
_app('macro list', 'macro define place location', 'Normal macro listing');
_app('place', <<eod, 'Execute place macro');
Location: Royal Observatory, Greenwich England
          Latitude 51.4772, longitude 0.0000, height 2 m
eod
_app('macro delete place', undef, 'Delete place macro');
_app('macro brief', undef, 'Prove place macro went away');
_app('macro define say \'echo $1\'', undef, 'Define macro with argument');
_app('say cheese', 'cheese', 'Execute macro with argument');
_app('say', '', 'Execute macro without argument');
_app('macro define say \'echo ${1:-Uncle Albert}\'', undef,
    'Redefine macro with argument and default');
_app('say cheese', 'cheese', 'Execute macro with explicit argument');
_app('say', 'Uncle Albert', 'Execute macro defaulting argument');
_app('macro define say \'echo ${1:=Cheezburger} $1\'', undef,
    'Redefine doubletalk macro with := default');
_app('say cheese', 'cheese cheese', 'Execute doubletalk macro');
_app('say', 'Cheezburger Cheezburger', 'Execute doubletalk with default');
_app('macro define say \'echo ${1:?Nothing to say}\'', undef,
    'Redefine macro with error');
_app('say cheese', 'cheese', 'Execute macro, no error');
_app('say', 'Nothing to say', 'Execute macro, triggering error');
_app('macro define say \'echo ${1:+something}\'', undef,
    'Redefine macro overriding argument');
_app('say cheese', 'something', 'Check that argument is overridden');
_app('say', '', 'Check that override does not appear without argument');
_app('macro define say \'echo ${1:2:4}\'', undef,
    'Redefine macro with substring operator');
_app('say abcdefghi', 'cdef', 'Check substring extraction');
_app('say abcd', 'cd', 'Check substring extraction with short string');
_app('say a', '', 'Check substring extraction with really short string');
_app('say', '', 'Check substring extraction with no argument at all');
_app('macro define say \'echo ${!1}\'', undef,
    'Redefine macro with indirection');
_app('say horizon', '20', 'Check argument indirection');

{

    no warnings qw{ uninitialized };
    local $ENV{fubar} = undef;
    use warnings qw{ uninitialized };

    _app('say fubar', '', 'Check argument indirection with missing target');

}

_app('clear', undef, 'Ensure we have no TLEs loaded');
_app('load t/data.tle', undef, 'Load our usual set of TLEs');
_app("pass '19801012T000000Z'", <<'EOD', 'Calculate passes over Greenwich');
    time eleva  azimuth      range latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02   0.0 199.0 S      1687.8  37.2228   -6.0197   204.9 lit   rise
05:42:43  55.9 115.6 SE      255.5  50.9259    1.7791   213.1 lit   max
05:46:37   0.0  29.7 NE     1778.5  64.0515   17.6896   224.9 lit   set

 88888 -   1980/10/14
05:32:49   0.0 204.8 SW     1691.2  37.6261   -7.7957   205.5 lit   rise
05:36:32  85.6 111.4 E       215.0  51.4245    0.2141   214.4 lit   max
05:40:27   0.0  27.3 NE     1782.5  64.5101   16.6694   226.8 lit   set

 88888 -   1980/10/15
05:26:29   0.0 210.3 SW     1693.5  38.1313   -9.4884   206.3 shdw  rise
05:27:33   4.7 212.0 SW     1220.1  42.1574   -7.5648   208.7 lit   lit
05:30:12  63.7 297.6 NW      239.9  51.8981   -1.3250   215.8 lit   max
05:34:08   0.0  25.1 NE     1789.5  64.9426   15.6750   228.8 lit   set

 88888 -   1980/10/16
05:20:01   0.0 215.7 SW     1701.4  38.6745  -11.1244   207.2 shdw  rise
05:22:20  14.8 228.1 SW      701.8  47.3322   -6.4800   213.2 lit   lit
05:23:44  43.5 299.4 NW      310.4  52.4061   -2.7900   217.4 lit   max
05:27:40   0.0  23.0 NE     1798.7  65.3494   14.7032   230.8 lit   set

 88888 -   1980/10/17
05:13:26   0.0 221.0 SW     1706.4  39.3182  -12.6738   208.3 shdw  rise
05:16:45  28.6 273.8 W       433.1  51.5795   -5.3038   217.8 lit   lit
05:17:08  31.7 301.4 NW      400.0  52.9477   -4.1788   219.1 lit   max
05:21:03   0.0  21.0 N      1809.7  65.7310   13.7503   232.9 lit   set

 88888 -   1980/10/18
05:06:44   0.0 226.2 SW     1708.2  40.0617  -14.1335   209.7 shdw  rise
05:10:23  24.5 302.6 NW      495.7  53.4634   -5.5405   220.8 shdw  max
05:10:50  22.3 327.2 NW      537.6  55.0439   -4.0816   222.4 lit   lit
05:14:16   0.0  19.0 N      1814.7  66.0412   12.6971   234.9 lit   set
EOD
_app('set local_coord equatorial_rng', undef, 'Specify equatorial + range');
_app("pass '19801013T000000Z' +1", <<'EOD', 'Ensure we get equatorial + range');
            right
    time ascensio decli      range latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02 05:30:58 -36.6     1687.8  37.2228   -6.0197   204.9 lit   rise
05:42:43 09:33:08  29.8      255.5  50.9259    1.7791   213.1 lit   max
05:46:37 16:51:14  32.2     1778.5  64.0515   17.6896   224.9 lit   set
EOD
_app('set local_coord azel_rng', undef, 'Specify azel + range');
_app("pass '19801013T000000Z' +1", <<'EOD', 'Ensure we get azel + range');
    time eleva  azimuth      range latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02   0.0 199.0 S      1687.8  37.2228   -6.0197   204.9 lit   rise
05:42:43  55.9 115.6 SE      255.5  50.9259    1.7791   213.1 lit   max
05:46:37   0.0  29.7 NE     1778.5  64.0515   17.6896   224.9 lit   set
EOD
_app('set local_coord azel', undef, 'Specify azel only');
_app("pass '19801013T000000Z' +1", <<'EOD', 'Ensure we get azel only');
    time eleva  azimuth latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02   0.0 199.0 S   37.2228   -6.0197   204.9 lit   rise
05:42:43  55.9 115.6 SE  50.9259    1.7791   213.1 lit   max
05:46:37   0.0  29.7 NE  64.0515   17.6896   224.9 lit   set
EOD
_app('set local_coord az_rng', undef, 'Specify azimugh + range');
_app("pass '19801013T000000Z' +1", <<'EOD', 'Ensure we get azimuth + range');
    time  azimuth      range latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02 199.0 S      1687.8  37.2228   -6.0197   204.9 lit   rise
05:42:43 115.6 SE      255.5  50.9259    1.7791   213.1 lit   max
05:46:37  29.7 NE     1778.5  64.0515   17.6896   224.9 lit   set
EOD
_app('set local_coord equatorial', undef, 'Specify equatorial only');
_app("pass '19801013T000000Z' +1", <<'EOD', 'Ensure we get equatorial only');
            right
    time ascensio decli latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02 05:30:58 -36.6  37.2228   -6.0197   204.9 lit   rise
05:42:43 09:33:08  29.8  50.9259    1.7791   213.1 lit   max
05:46:37 16:51:14  32.2  64.0515   17.6896   224.9 lit   set
EOD
_app('set local_coord', undef, 'Clear local coordinates');
_app("pass '19801013T000000Z' +1", <<'EOD', 'Ensure we get old coordinates back');
    time eleva  azimuth      range latitude longitude altitud illum event

 88888 -   1980/10/13
05:39:02   0.0 199.0 S      1687.8  37.2228   -6.0197   204.9 lit   rise
05:42:43  55.9 115.6 SE      255.5  50.9259    1.7791   213.1 lit   max
05:46:37   0.0  29.7 NE     1778.5  64.0515   17.6896   224.9 lit   set
EOD
_app("phase '20090401T000000 UT'", <<eod, 'Phase of moon April 1 2009');
                             phas                  fract
      date     time     name angl phase              lit
2009/04/01 00:00:00     Moon   69 waxing crescent    32%
eod
{
    my $warning;
    local $SIG{__WARN__} = sub {$warning = $_[0]};
    _app('clear', undef, 'Clear observing list');
    _app('load t/data.tle', undef, 'Load observing list');
    _app('choose 88888', undef, 'Restrict ourselves to body 88888');
    _app("position '20090401T000000Z'", <<eod,
            name eleva  azimuth      range               epoch illum
2009/04/01 00:00:00
             Sun -34.0 358.8 N   1.495e+08
            Moon   8.3 302.0 NW   369373.2
eod
	'Position of things in sky on 01-Apr-2009 midnight UT');
    _do_test($warning, qr{Mean eccentricity < 0 or > 1},
	'Expect warning on 888888');
    _app('set local_coord equatorial_rng', undef,
	'Set local_coord to \'equatorial_rng\'');
    _app("position '20090401T000000Z'", <<eod,
                    right
            name ascensio decli      range               epoch illum
2009/04/01 00:00:00
             Sun 00:41:56   4.5  1.495e+08
            Moon 05:13:53  26.0   369373.2
eod
	'Position of things in sky on 01-Apr-2009 midnight UT, equatorial');
    _app('set local_coord', undef, 'Clear local_coord');
    _app("position '20090401T000000Z'", <<eod,
            name eleva  azimuth      range               epoch illum
2009/04/01 00:00:00
             Sun -34.0 358.8 N   1.495e+08
            Moon   8.3 302.0 NW   369373.2
eod
	'Position of things in sky on 01-Apr-2009 midnight UT, in azel again');
}
_app("quarters '20090301T000000 UT'", <<eod,
2009/03/04 07:45:18 First quarter Moon
2009/03/11 02:37:41 Full Moon
2009/03/18 17:47:34 Last quarter Moon
2009/03/20 11:40:07 Spring equinox
2009/03/26 16:05:47 New Moon
eod
    'Quarters of Moon and Sun, Mar 1 2009');
_app('sky list', <<eod, "List what's in the sky");
sky add Moon
sky add Sun
eod

_app('sky drop moon', undef, 'Get rid of the Moon');
_app('sky list', 'sky add Sun', 'Confirm the Moon is gone');
_app('sky add moon', undef, 'Add the Moon back again');
_app('sky list', <<eod, 'Confirm that both sun and moon are in the sky');
sky add Moon
sky add Sun
eod
_app('sky clear', undef, 'Remove all bodies from the sky');
_app('sky list', undef, 'Confirm that there is nothing in the sky');
_app('sky add sun', undef, 'Add the sun back again');
_app('sky add moon', undef, 'Add the moon back yet again');
_app('sky add fubar',
    'You must give at least right ascension and declination',
    'Add unknown body (fails)');
_app('sky add Arcturus 213.9153000 +19.1824103 11.25 -1.09343 -1.99943 -5.2',
    undef, 'Add Arcturus');
_app('sky list', <<eod, 'Confirm Sun, Moon, and Arcturus are in the sky');
sky add Arcturus 14:15:40  19.182 11.25 -1.0934 -1.99943 -5.2
sky add Moon
sky add Sun
eod
_app('source t/source.dat Able was I, ere I saw Elba',
    'Able was I, ere I saw Elba', 'Echo from a source file');
_app('source -optional t/source.dat There was a young lady named Bright,',
    'There was a young lady named Bright,',
    'Echo from an optional source file');
_app('source t/missing.dat', 'Failed to open t/missing.dat',
    'Source from a missing file');
_app('source -optional t/missing.dat', undef,
    'Optional source from a missing file.');
_app('clear', undef, 'Clear observing list before loading ISS data');
_app('set horizon 20 appulse 10 visible 1 twilight civil lit 1 geometric 0',
    undef, 'Prepare to check for appulse of ISS at Salamanca');
_app('set latitude 40.964972 longitude -5.663047 height 802 location \'Salamanca, Spain\'',
    undef, 'Move to Salamanca, Spain for next test');

SKIP: {
    -d 't' or skip ("No t directory found", 1);
    my $skip;
    $skip = _get_satellite_data($app,
	File::Spec->catfile(qw{t appulse.tle}),
	'retrieve', '-start', '20090331T000000Z',
	'-end', '20090402T000000Z', 25544
    ) and skip $skip, 1;

    is(
	eval {
	    $app->pass('20090401T000000Z', '+1')
	} || $@,
	<<'EOD',
    time eleva  azimuth      range latitude longitude altitud illum event

 25544 - ISS (ZARYA)  2009/04/01
19:33:00  20.1 297.2 NW      883.9  43.8855  -14.4029   355.3 lit   rise
19:34:39  62.9 243.8 SW      393.9  40.2759   -7.4548   353.9 lit   apls
19:34:39  63.4 244.2 SW   364322.7        0.5 degrees from Moon
19:34:50  65.2 219.2 SW      386.7  39.8859   -6.7979   353.8 lit   max
19:36:40  20.0 140.2 SE      880.4  35.3860   -0.1266   352.2 lit   set
EOD
	'Pass of ISS over Salamanca Spain, with appulse of Moon'
    );
}
    
# TODO test status (maybe just work)
# TODO test system (how?)
# TODO test time (how?)

_app('clear', undef, 'Clear the observing list for validate() check');
_app('load t/data.tle', undef, 'Load a TLE file for validate() check');
_app('list', <<eod, 'List the loaded items');
   oid name                     epoch               period
 88888                          1980/10/01 23:41:24 01:29:37
 11801                          1980/08/17 07:06:40 10:30:08
eod
_app('validate -quiet "19810101T120000Z"', undef, 'Validate for 01-Jan-1981');
_app('list', <<eod, 'List the valid items');
   oid name                     epoch               period
 88888                          1980/10/01 23:41:24 01:29:37
eod

SKIP: {
    -d 't' or skip ("No t directory found", 1);
    my $t = File::Spec->catfile(&getcwd, 't');
    eval {$app->execute('cd t')};
    is($@ || &getcwd, $t, "Change to t directory (cd with argument)");
}

SKIP: {
    my $home = eval {(getpwuid($<))[7]}
	or skip ("Can not execute getpwuid", 1);
    eval {$app->execute('cd')};
    is($@ || &getcwd, $home, "Change to home directory (cd without argument)");
}

SKIP: {
    my $tests = 5;
    my $rslt;
##  defined ($rslt = _check_access('http://rpc.geocoder.us/Geo/Coder/US'))
    defined ($rslt = _check_access('http://rpc.geocoder.us/'))
	and skip ($rslt, $tests);
    eval {require SOAP::Lite}
	or skip ("Can not load SOAP::Lite", $tests);
    $rslt = eval {$app->execute(
	    "geocode '1600 Pennsylvania Ave, Washington DC'")};
    ok(!$@, "geocode of White House succeeded");
    is($rslt, <<eod, "Geocode of White House returned expected data");

set location '1600 Pennsylvania Ave NW Washington DC 20502'
set latitude 38.898748
set longitude -77.037684
eod
    is($app->get('location'),
	'1600 Pennsylvania Ave NW Washington DC 20502',
	'Geocode of White House returned expected address');
    is($app->get('latitude'), 38.898748,
	'Geocode of White House returned expected latitude');
    is($app->get('longitude'), -77.037684,
	'Geocode of White House returned expected longitude');
}

cmp_ok(@{$app->{frame}}, '==', 1, 'Object frame stack clean') or eval {
    require YAML;
    diag ("Stack contents: ", YAML::Dump( $app->{frame}));
    1;
} or diag($@);

sub _app {	## no critic (RequireArgUnpacking)
    my @cmd = @_;
    my $title = pop @cmd;
    my $want = pop @cmd;
    my $got;
    if ( ref $cmd[0] eq 'CODE' ) {
	my $code = shift @cmd;
	$got = eval { $app->system( $code, @cmd ) };
    } else {
	$got = eval { $app->execute( @cmd ) };
    }
    @_ = ($got, $want, $title);
    goto &_do_test;
}

#	$rslt = _check_access($url)
#
#	The result is either an error message, or false for success.

sub _check_access {
    my ($url) = @_;
    eval {require LWP::UserAgent; 1}
	or return "Can not load LWP::UserAgent";
    my $ua = LWP::UserAgent->new()
	or return "Can not instantiate LWP::UserAgent";
    my $rslt = $ua->get($url)
	or return "Can not get $url";
    $rslt->is_success or return $rslt->status_line;
    return;
}

sub _do_test {
    my ($got, $want, $title) = @_;
    defined $want and chomp $want;
    if ($@) {
	chomp $@;
	@_ = ($@, qr/^@{[quotemeta $want]}/, $title);
	goto &like;
    } else {
	defined $got and chomp $got;
	if (ref $want eq 'Regexp') {
	    goto &like;
	} else {
	    defined $want and chomp $want;
	    @_ = ($got, $want, $title);
	    goto &is;
	}
    }
}

{
    my ($bypass, $message);
    BEGIN {
	$message = 'Space Track username/password not provided';
    }

    sub _get_satellite_data {
	my ($app, $fn, @stcmd) = @_;

	# If the file has already been created, just load it and return.
	eval {
	    $app->load($fn);
	    1;
	} and return;

	# If we have already run and not been able to access Space
	# Track, return the appropriate message.
	$bypass and return $bypass;

	# If we are unable to load Astro::SpaceTrack, say so.
	eval {
	    require Astro::SpaceTrack;
	    1;
	} or return ($bypass = "Astro::SpaceTrack not available");
	$app->st(qw{set with_name 1});

	# If we do not have a Space Track username or password, try to
	# scavenge one from the user's profile.
	if ($app->st(qw{show username password}) eq <<eod
st set username ''
st set password ''
eod
	) {
	    eval {
		my $app2 = App::Satpass2->new();
		$app2->init();
		$app->execute(
		    $app2->st(qw{show username password})
		);
	    };
	}

	# If we _still_ do not have a Space Track username and password,
	# give up if we're doing automated testing. Otherwise prompt the
	# user for them.
	if ($app->st(qw{show username password}) eq <<eod
st set username ''
st set password ''
eod
	) {
	    $ENV{AUTOMATED_TESTING}
		and return (
		$bypass = "Automated testing and SPACETRACK_USER not set"
	    );
	    {
		warn <<eod;

In order to do the following test we need orbital data from the Space
Track web side. You need to give your Space Track username and password
to retrieve this data. If you do not have a Space Track username and
password, or if you do not wish to run this test, simply hit <return>.

eod
		my $user = _prompt('Enter Space Track username: ')
		    or return ($bypass = $message);
		my $pass = _prompt('Enter Space Track password: ')
		    or return ($bypass = $message);
		$app->st('set', username => $user, password => $pass);
		eval {
		    $app->st('login');
		    1;
		} and last;
		$app->st('set', username => '', password => '');
		$@ =~ m/401/ and do {
		    warn $@, "\n";
		    redo;
		};
		return "Failed to log in to Space Track: $@";
	    }
	}

	# If, after all this rigamarole, we have a username and
	# password, retrieve the desired data, returning a failure
	# message if we fail.
	eval {
	    $app->st(@stcmd);
	    1;
	} or return "Failed to retrieve data from Space Track: $@";

	# At this point, we have our data. Write it to a file so that we
	# can skip this whole mess the next time around.
	if ($ENV{SATPASS2_TEST_PRESERVE_DATA}) {
	    my $fh = IO::File->new($fn, '>') or return;
	    print {$fh} $app->tle();
	}
	return;
    }
}

sub _prompt {
    my @args = @_;
    print STDERR @args;
    # We're a test, and we're trying to be lightweight.
    return unless defined (my $input = <STDIN>);	## no critic (ProhibitExplicitStdin)
    chomp $input;
    return $input;
}

1;
