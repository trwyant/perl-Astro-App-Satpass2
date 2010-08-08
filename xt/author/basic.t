package main;

use strict;
use warnings;

BEGIN {
    my $test_more;
    eval {
	$test_more = __LINE__ + 1;
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	( my $err = $@ ) =~ s/ (?<= \n ) (?= . ) /#   /smx;
	print "1..1\n";
	print "not ok 1 - require Test::More 0.40;\n",
	"#   Failed test 'require Test::More 0.40;'\n",
	"#   at ", __FILE__, ' line ', $test_more, "\n",
	"#   Error: $err";
	exit;
    }
}

plan( tests => 9 );

diag( 'Things needed for authortest' );

require_ok( 'Astro::SIMBAD::Client' );
require_ok( 'Astro::SpaceTrack' );
require_ok( 'Date::Manip' );
require_ok( 'DateTime' );
require_ok( 'DateTime::TimeZone' );
require_ok( 'Geo::WebService::Elevation::USGS' );
require_ok( 'SOAP::Lite' );
require_ok( 'Time::HiRes' );

ok( -f 'date_manip_v5/Date/Manip.pm',
    'Have Date::Manip v5 for regression testing' );

1;

# ex: set textwidth=72 :
