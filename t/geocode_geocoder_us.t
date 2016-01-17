package main;

use 5.008;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;	# Because of done_testing();
use My::Module::Test::Geocode;

$ENV{AUTHOR_TESTING}
    or plan skip_all => 'geocoder.us temporarily (I hope!) out of action';

setup	'Astro::App::Satpass2::Geocode::Geocoder::US';

TODO: {
    SKIP: {
	local $TODO = 'geocoder.us temporarily (I hope!) out of action';
	geocode '1600 Pennsylvania Ave, Washington DC', 1;
    }
}

done_testing;

1;

# ex: set textwidth=72 :
