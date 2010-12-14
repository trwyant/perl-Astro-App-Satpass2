package main;

use strict;
use warnings;

use lib qw{ inc };

use App::Satpass2::Test::Format;
use Time::Local;

my $tst = App::Satpass2::Test::Format->new(
    'App::Satpass2::FormatTime::DateTime::Cldr' );

eval {
    require DateTime;
    require DateTime::TimeZone;
    1;
} or do {
    $tst->plan(
	skip_all => 'DateTime and/or DateTime::TimeZone not available' );
    exit;
};

$tst->plan( tests => 13 );

$tst->require_ok();

$tst->can_ok( 'new' );
$tst->can_ok( 'attribute_names' );
$tst->can_ok( 'copy' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'format_datetime' );
$tst->can_ok( 'format_datetime_width' );
$tst->can_ok( 'tz' );

$tst->new_ok();

my $time = timegm( 0, 0, 0, 1, 3, 111 );	# midnight 1-Apr-2011
$tst->method_ok( 'gmt', 'Harness turned on gmt attribute' );
$tst->method_is( format_datetime => 'yyyy/MM/dd HH:mm:SS', $time,
    '2011/04/01 00:00:00', 'Implicit GMT time' );
$tst->method_is( format_datetime_width => 'yyyy/MM/dd HH:mm:SS', 19,
    'Compute width required for format' );
$tst->method( gmt => 0 );			# Turn off gmt attr
$tst->method_is( format_datetime => 'yyyy/MM/dd HH:mm:SS', $time, 1,
    '2011/04/01 00:00:00', 'Explicit GMT time' );

1;

# ex: set textwidth=72 :
