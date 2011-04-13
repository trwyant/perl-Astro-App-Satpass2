package main;

use strict;
use warnings;

BEGIN {
    my $test_more;
    eval {
	$test_more = __LINE__ + 1;
	require Test::More;
	Test::More->VERSION( 0.52 );
	Test::More->import();
	1;
    } or do {
	( my $err = $@ ) =~ s/ (?<= \n ) (?= . ) /#   /smx;
	print "1..1\n";
	print "not ok 1 - require Test::More 0.52;\n",
	"#   Failed test 'require Test::More 0.52;'\n",
	"#   at ", __FILE__, ' line ', $test_more, "\n",
	"#   Error: $err";
	exit;
    }
}

plan tests => 13;

diag 'Things needed for authortest';

require_ok 'Astro::SIMBAD::Client';
require_ok 'Astro::SpaceTrack';
require_ok 'Date::Manip';
require_ok 'DateTime';
ok eval { Date::Manip->VERSION( 6 ) }, 'Installed Date::Manip is v6';
require_ok 'DateTime::TimeZone';
require_ok 'Geo::WebService::Elevation::USGS';
require_ok 'SOAP::Lite';
require_ok 'Test::MockTime';
require_ok 'Test::Perl::Critic';
require_ok 'Test::Without::Module';
require_ok 'Time::HiRes';

ok -f 'date_manip_v5/Date/Manip.pm',
    'Have Date::Manip v5 for regression testing';

1;

# ex: set textwidth=72 :
