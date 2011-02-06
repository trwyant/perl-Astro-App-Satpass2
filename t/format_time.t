package main;

use strict;
use warnings;

use lib qw{ inc };

use Astro::App::Satpass2::Test::Format;
use Time::Local;

my $tst = Astro::App::Satpass2::Test::Format->new( 'Astro::App::Satpass2::FormatTime' );

$tst->plan( tests => 12 );

$tst->require_ok();

$tst->can_ok( 'new' );
$tst->can_ok( 'attribute_names' );
$tst->can_ok( 'copy' );
$tst->can_ok( 'gmt' );
$tst->can_ok( 'format_datetime_width' );
$tst->can_ok( 'tz' );

$tst->new_ok();

$tst->method_ok( 'gmt', 'Harness turned on gmt attribute' );

# Test various ineffective templates (null case).
$tst->method_is( format_datetime_width => '', 0, 'Width of null template' );
$tst->method_is( format_datetime_width => 'foo', 3,
    'Width of constant template' );
$tst->method_is( format_datetime_width => 'foo%%bar', 7,
    'Width of template with literal percent' );

1;

# ex: set textwidth=72 :
