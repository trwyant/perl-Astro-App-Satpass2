package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;

eval {
    require Geo::Coder::OSM;
    1;
} or do {
    plan skip_all => 'Geo::Coder::OSM not available';
    exit;
};

my $skip;
require_ok 'Astro::App::Satpass2::Geocode::OSM'
    or $skip = 1;

SKIP: {

    my $tests = 1;	# Number of tests to skip.
    $skip
	and skip 'Unable to load Astro::App::Satpass2::Geocode::OSM',
	    $tests;

    my $url = Astro::App::Satpass2::Geocode::OSM->GEOCODER_SITE;
    my $rslt;
    eval {
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new();
	$rslt = $ua->get( $url );
	1;
    } and $rslt->is_success()
	or skip "Unable to access $url", $tests;

    my $geocoder = Astro::App::Satpass2::Geocode::OSM->new();

    my $loc = '10 Downing St, London England';

    my @resp = $geocoder->geocode( $loc );
    # Geo::Coder::OSM's tests do not check any specific location, and
    # having gotten test failures when #10 Downing Street moved (at
    # least in OSM's database) I'm going to do as Geo::Coder::OSM does,
    # and just test for success.
    ok scalar @resp, "Geocode of $loc succeeded";

}

done_testing;

1;

# ex: set textwidth=72 :
