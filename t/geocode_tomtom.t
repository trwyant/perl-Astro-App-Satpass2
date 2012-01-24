package main;

use 5.008;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;	# Because of done_testing();
use Astro::App::Satpass2::Test::Geocode;

setup	'Astro::App::Satpass2::Geocode::TomTom';

SKIP: {
    geocode '1600 Pennsylvania Ave, Washington DC', 1;
}

done_testing;

1;

# ex: set textwidth=72 :
