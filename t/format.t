package main;

use strict;
use warnings;

use Test2::V0;
use Astro::App::Satpass2::Format;

use lib qw{ inc };

use My::Module::Test::App;

my $mocker = setup_app_mocker;
my $app = Astro::App::Satpass2->new();

klass( 'Astro::App::Satpass2::Format' );

{
    no warnings qw{ uninitialized };	# Needed by 5.8.8.
    local $ENV{TZ} = undef;	# Tests explicitly assume no TZ.
    call_m( 'new', parent => $app, INSTANTIATE, 'Instantiate' );
}

call_m( gmt => 1, TRUE, 'Set gmt to 1' );

call_m( 'gmt', 1, 'Confirm gmt set to 1' );

call_m( date_format => '%Y-%m-%d', q{Default date_format is '%Y-%m-%d'} );

call_m( desired_equinox_dynamical => 0,
    'Default desired_equinox_dynamical is 0' );

call_m( local_coord => 'azel_rng',
    q{Default local_coord is 'azel_rng'} );

call_m( provider => 'Test provider', TRUE, 'Set provider' );

call_m( 'provider', 'Test provider', 'Confirm provider set' );

call_m( time_format => '%H:%M:%S', q{Default time_format is '%H:%M:%S'} );

call_m( tz => undef, 'Default time zone is undefined' );

call_m( tz => 'est5edt', TRUE, 'Set time zone' );

call_m( tz => 'est5edt', 'Got back same time zone' );

my $expect_time_formatter = eval {
    require DateTime;
    require DateTime::TimeZone;
    DateTime::TimeZone->new( name => 'local' );
    'DateTime::Strftime';
} || 'POSIX::Strftime';

call_m( config => decode => 1,
    [
	[ date_format			=> '%Y-%m-%d' ],
	[ desired_equinox_dynamical	=> 0 ],
	[ gmt				=> 1 ],
	[ local_coord			=> 'azel_rng' ],
	[ provider			=> 'Test provider' ],
	[ round_time			=> 1 ],
	[ time_format			=> '%H:%M:%S' ],
	[ time_formatter		=> $expect_time_formatter ],
	[ tz				=> 'est5edt' ],
	[ value_formatter		=>
	    'Astro::App::Satpass2::FormatValue' ],
    ],
    'Dump configuration' );

call_m( config => decode => 1, changes => 1,
    [
	[ gmt				=> 1 ],
	[ provider			=> 'Test provider' ],
	[ time_formatter		=> $expect_time_formatter ],
	[ tz				=> 'est5edt' ],
    ],
    'Dump configuration changes' );

done_testing;

1;

# ex: set textwidth=72 :
