package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;

eval {
    require Astro::App::Satpass2::Geocode::Geocoder::US;
    1;
} or do {
    plan skip_all =>
	'Unable to load Astro::App::Satpass2::Geocode::Geocoder::US';
    exit;
};

my $url = Astro::App::Satpass2::Geocode::Geocoder::US->GEOCODER_SITE;
my $rslt;
eval {
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new();
    $rslt = $ua->get( $url );
    1;
} and $rslt->is_success() or do {
    plan skip_all => "Unable to access $url";
    exit;
};

my $geocoder = Astro::App::Satpass2::Geocode::Geocoder::US->new();

my $loc = '1600 Pennsylvania Ave, Washington DC';

my @resp = $geocoder->geocode( $loc );

is_deeply \@resp, [
    {
	description	=> '1600 Pennsylvania Ave NW, Washington DC 20502',
	latitude	=> '38.898748',
	longitude	=> '-77.037684',
    }
], "Geocode $loc"
    or eval {
    require Data::Dumper;
    diag Data::Dumper::Dumper( \@resp );
};

done_testing;

1;

# ex: set textwidth=72 :
