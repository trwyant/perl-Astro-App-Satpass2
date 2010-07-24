package main;

use strict;
use warnings;

use lib qw{ inc };

use App::Satpass2::Test::Format;

my $tst = App::Satpass2::Test::Format->new(
    'App::Satpass2::Format::Dump' );

$tst->plan( tests => 17 );

$tst->require_ok();

$tst->can_ok( 'new' );

$tst->can_ok( 'date_format' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'local_coord' );
$tst->can_ok( 'provider' );
$tst->can_ok( 'time_format' );

$tst->can_ok( 'almanac' );
$tst->can_ok( 'flare' );
$tst->can_ok( 'list' );
$tst->can_ok( 'location' );
$tst->can_ok( 'pass' );
$tst->can_ok( 'phase' );
$tst->can_ok( 'position' );
$tst->can_ok( 'tle' );
$tst->can_ok( 'tle_verbose' );

SKIP: {

    eval {
	require Data::Dumper;
	1;
    } or $tst->skip( 'Data::Dumper not available', 1 );

    $tst->new_ok();

}

1;

# ex: set textwidth=72 :
