package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;

eval {
    require Geo::Coder::TomTom;
    1;
} or do {
    plan skip_all => 'Geo::Coder::TomTom not available';
    exit;
};

my $skip;
require_ok 'Astro::App::Satpass2::Geocode::TomTom'
    or $skip = 1;

SKIP: {

    my $tests = 1;	# Number of tests to skip.

    $skip
	and skip 'Unable to load Astro::App::Satpass2::Geocode::TomTom',
	    $tests;

    my $url = Astro::App::Satpass2::Geocode::TomTom->GEOCODER_SITE;
    my $rslt;
    eval {
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new();
	$rslt = $ua->get( $url );
	1;
    } and $rslt->is_success()
	or skip "Unable to access $url", $tests;

    my $geocoder = Astro::App::Satpass2::Geocode::TomTom->new();

    my $loc = '1600 Pennsylvania Ave, Washington DC';

    my @resp = $geocoder->geocode( $loc );
    # Having had test failures on OSM when the database changed, I have
    # decided that it is not this class' problem to do anything but
    # call the wrapped class successfully. Accordingly, I have replaced
    # a detailed test of the return with a test for success.
    ok scalar @resp, "Geocode of $loc succeeded";

}

done_testing;

1;

# ex: set textwidth=72 :
