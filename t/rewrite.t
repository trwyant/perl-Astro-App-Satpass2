package main;

use 5.006002;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

use Astro::App::Satpass2;

class   'Astro::App::Satpass2';

method  new => INSTANTIATE, 'Instantiate';

my @commands;

method  set => execute_filter => sub {
    my ( $self, $args ) = @_;
    push @commands, $args;
    return 0;
}, undef, 'Disable execution and capture tokenized command';

method  source => { level1 => 1 }, [ 'almanac' ], undef,
    q{Rewrite 'almanac'};

is      scalar @commands, 2, q{Expect two commands from 'almanac'};

is_deeply $commands[0], [ 'location' ], q{First command is 'location'};

is_deeply $commands[1], [ 'almanac' ], q{Second command is 'almanac'};

@commands = ();

method  source => { level1 => 1 }, [ 'flare -am "today noon" \\', '+1' ],
    undef, q{Rewrite 'flare -am "today noon" +1'};

is      scalar @commands, 1, q{Expect one command from 'flare ...'};

is_deeply $commands[0], [ 'flare', '-noam', 'today noon', '+1' ],
    q{Command is 'flare -noam ...'};

@commands = ();

method  source => { level1 => 1 }, [ 'pass "today noon" +2' ], undef,
q{Rewrite 'pass "today noon" +1'};

is      scalar @commands, 2, q{Expect two commands from 'pass ...'};

is_deeply $commands[0], [ 'location' ], q{First command is 'location'};

is_deeply $commands[1], [ 'pass', 'today noon', '+2' ],
    q{Second command is 'pass ...'};

method  set => execute_filter => sub { return 1 }, undef,
    'Enable execution';

method  set => stdout => undef, undef, 'Disable output';

method  source => { level1 => 1 }, 't/rewrite_macros',
    undef, 'Load satpass-format macros';

execute 'macro list farmers', <<'EOD', 'Rewrite almanac';
macro define farmers location \
    almanac
EOD

execute 'macro list glint', <<'EOD', 'Rewrite flare';
macro define glint 'flare -noam $@'
EOD

execute 'macro list burg', <<'EOD', 'Rewrite localize';
macro define burg 'localize horizon formatter verbose'
EOD

execute 'macro list overtake', <<'EOD', 'Rewrite pass';
macro define overtake location \
    'pass $@'
EOD

execute 'macro list exhibit', <<'EOD', 'Rewrite show';
macro define exhibit 'formatter date_format' \
    'show horizon verbose' \
    'formatter time_format'
EOD

execute 'macro list assign', <<'EOD', 'Rewrite set';
macro define assign 'set horizon 10' \
    'formatter date_format "%a %d-%b-%Y"' \
    'formatter time_format "%I:%M:%S %p"' \
    'set verbose 1 appulse 5' \
    'formatter gmt 1'
EOD

execute 'macro list norad', <<'EOD', 'Rewrite st invocation';
macro define norad 'st $@'
EOD

execute 'macro list st', <<'EOD', 'Rewrite st use';
macro define st 'spacetrack $@'
EOD

done_testing;

1;

# ex: set textwidth=72 :
