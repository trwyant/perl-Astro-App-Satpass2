package main;

use strict;
use warnings;

use lib qw{ inc };

use App::Satpass2::Test::Format;
use Time::Local;

my $tst = App::Satpass2::Test::Format->new( 'App::Satpass2::FormatTime' );

$tst->plan( tests => 15 );

$tst->require_ok();

$tst->can_ok( 'new' );
$tst->can_ok( 'attribute_names' );
$tst->can_ok( 'copy' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'strftime_width' );
$tst->can_ok( 'tz' );

$tst->new_ok();

my $time = timegm( 0, 0, 0, 1, 3, 111 );	# midnight 1-Apr-2011
$tst->method_ok( 'gmt', 'Harness turned on gmt attribute' );
$tst->method_is( strftime => '%Y/%m/%d %H:%M:%S', $time,
    '2011/04/01 00:00:00', 'Implicit GMT time' );
$tst->method_is( strftime_width => '%Y/%m/%d %H:%M:%S', 19,
    'Compute width required for format' );
$tst->method( gmt => 0 );			# Turn off gmt attr
$tst->method_is( strftime => '%Y/%m/%d %H:%M:%S', $time, 1,
    '2011/04/01 00:00:00', 'Explicit GMT time' );

# Test various ineffective templates (null case).
$tst->method_is( strftime_width => '', 0, 'Width of null template' );
$tst->method_is( strftime_width => 'foo', 3,
    'Width of constant template' );
$tst->method_is( strftime_width => 'foo%%bar', 7,
    'Width of template with literal percent' );

1;

# ex: set textwidth=72 :
