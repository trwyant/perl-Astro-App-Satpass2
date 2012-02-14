package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

use Astro::App::Satpass2::Format::Dump;

class 'Astro::App::Satpass2::Format::Dump';

SKIP: {

    my $tests = 1;

    eval {
	require Data::Dumper;
	1;
    } or skip 'Data::Dumper not available', $tests ;

    method 'new', INSTANTIATE, 'Instantiate';

}

done_testing;

1;

# ex: set textwidth=72 :
