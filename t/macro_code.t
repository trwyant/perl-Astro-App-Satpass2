package main;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2;
use Astro::App::Satpass2::Utils ();
use Astro::App::Satpass2::Macro::Code;
use Test::More 0.88;	# Because of done_testing();

use constant lib_dir => 'eg';

-d lib_dir
    or plan skip_all => 'Can not find eg/ directory';

my ( $mac, $sp );

eval {
    $sp = Astro::App::Satpass2->new();
    $sp->set(
	location	=> '1600 Pennsylvania Ave NW Washington DC 20502',
	latitude	=> 38.898748,
	longitude	=> -77.037684,
	height		=> 16.68,
    );
    1;
} or plan skip_all => "Can not instantiate Satpass2: $@";

eval {
   $mac = Astro::App::Satpass2::Macro::Code->new(
	lib	=> lib_dir,
	name	=> 'My::Macros',
	generate	=> \&Astro::App::Satpass2::_macro_load_generator,
	parent	=> $sp,
	warner	=> $sp->{_warner},	# Encapsulation violation
    );
    1;
} or plan skip_all => "Can not instantiate macro: $@";

cmp_ok scalar $mac->implements(), '==', 4, 'Module implements 4 macros';

ok $mac->implements( 'angle' ), 'Module implements angle()';

ok $mac->implements( 'dumper' ), 'Module implements dumper()';

ok $mac->implements( 'hi' ), 'Module implements hi()';

ok $mac->implements( 'test' ), 'Module implements test()';

is $mac->generator(), <<'EOD', 'Module serializes correctly';
macro load -lib eg My::Macros angle
macro load -lib eg My::Macros dumper
macro load -lib eg My::Macros hi
macro load -lib eg My::Macros test
EOD

is $mac->generator( 'angle' ), <<'EOD', 'Single macro serializes';
macro load -lib eg My::Macros angle
EOD

is $mac->execute( hi => 'sailor' ), <<'EOD', q{Macro 'hi' executes};
Hello, sailor!
EOD

eval {
    is $mac->execute(
        qw{ angle -places 2 sun moon 20130401T120000Z } ),
	<<'EOD', q{Macro 'angle' executes with command options};
112.73
EOD
    1;
} or diag "Macro 'angle' failed: $@";

eval {
    is $mac->execute(
	angle => { places => 3 }, qw{ sun moon 20130401T120000Z } ),
	<<'EOD', q{Macro 'angle' executes with hash ref options};
112.727
EOD
    1;
} or diag "Macro 'angle' failed: $@";

done_testing;

1;

# ex: set textwidth=72 :
