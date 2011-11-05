package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

require_ok 'Astro::App::Satpass2::Format';

can_ok 'Astro::App::Satpass2::Format' => 'new';

can_ok 'Astro::App::Satpass2::Format' => 'date_format';

can_ok 'Astro::App::Satpass2::Format' => 'desired_equinox_dynamical';

can_ok 'Astro::App::Satpass2::Format' => 'gmt';

can_ok 'Astro::App::Satpass2::Format' => 'local_coord';

can_ok 'Astro::App::Satpass2::Format' => 'provider';

can_ok 'Astro::App::Satpass2::Format' => 'time_format';

can_ok 'Astro::App::Satpass2::Format' => 'tz';

class 'Astro::App::Satpass2::Format';

method 'new', INSTANTIATE, 'Instantiate';

method gmt => 1, TRUE, 'Set gmt to 1';

method 'gmt', 1, 'Confirm gmt set to 1';

method date_format => '%Y-%m-%d', q{Default date_format is '%Y-%m-%d'};

method desired_equinox_dynamical => 0,
    'Default desired_equinox_dynamical is 0';

method local_coord => 'azel_rng',
    q{Default local_coord is 'azel_rng'};

method provider => 'Test provider', TRUE, 'Set provider';

method 'provider', 'Test provider', 'Confirm provider set';

method time_format => '%H:%M:%S', q{Default time_format is '%H:%M:%S'};

method tz => undef, 'Default time zone is undefined';

method tz => 'est5edt', TRUE, 'Set time zone';

method tz => 'est5edt', 'Got back same time zone';

my $expect_time_formatter = eval {
    require DateTime;
    require DateTime::TimeZone;
    'Astro::App::Satpass2::FormatTime::DateTime::Strftime';
} || 'Astro::App::Satpass2::FormatTime::POSIX::Strftime';

method config => decode => 1,
    [
	[ date_format			=> '%Y-%m-%d' ],
	[ desired_equinox_dynamical	=> 0 ],
	[ gmt				=> 1 ],
	[ local_coord			=> 'azel_rng' ],
	[ provider			=> 'Test provider' ],
	[ time_format			=> '%H:%M:%S' ],
	[ time_formatter		=> $expect_time_formatter ],
	[ tz				=> 'est5edt' ],
    ],
    'Dump configuration';

method config => decode => 1, changes => 1,
    [
	[ gmt				=> 1 ],
	[ provider			=> 'Test provider' ],
	[ time_formatter		=> $expect_time_formatter ],
	[ tz				=> 'est5edt' ],
    ],
    'Dump configuration changes';

done_testing;

1;

# ex: set textwidth=72 :
