package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

require_ok 'Astro::App::Satpass2::Format::Dump';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'new';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'date_format';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'gmt';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'local_coord';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'provider';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'time_format';

can_ok 'Astro::App::Satpass2::Format::Dump' => 'format';

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
