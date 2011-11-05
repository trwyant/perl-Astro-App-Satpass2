package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;

use Astro::App::Satpass2::Format::Template::Provider;
use Template::Constants qw{ STATUS_OK STATUS_DECLINED };

my $tp = Astro::App::Satpass2::Format::Template::Provider->new();

ok $tp, 'Instantated Astro::App::Satpass2::Format::Template::Provider';

ok $tp->__satpass2_template( foo => 'bar' ), 'Store template foo';

is scalar $tp->__satpass2_template( 'foo' ), 'bar',
    'Content of foo via scalar __satpass_template';

is( ( $tp->__satpass2_template( 'foo' ) )[0], 'bar',
    'Content of foo via list __satpass_template' );

is( ( $tp->__satpass2_template( 'foo' ) )[1], 1,
    'Pseudo-modification time of foo via list __satpass_template' );

is $tp->_template_modified( 'foo' ), 1,
    'Pseudo-modification time of foo via _template_modified';

is scalar $tp->_template_content( 'foo' ), 'bar',
    'Content of foo via scalar _template_content';

is( ( $tp->_template_content( 'foo' ) )[0], 'bar',
    'Content of foo via list _template_content' );

is( ( $tp->_template_content( 'foo' ) )[1], STATUS_OK,
    'Status of foo via list _template_content' );

is $tp->_template_modified( 'bar' ), undef,
    'Pseudo-modification time of bar via _template_modified';

is scalar $tp->_template_content( 'bar' ), undef,
    'Content of bar via scalar _template_content';

is( ( $tp->_template_content( 'bar' ) )[0], undef,
    'Content of bar via list _template_content' );

is( ( $tp->_template_content( 'bar' ) )[1], STATUS_DECLINED,
    'Status of bar via list _template_content' );

is_deeply [ sort $tp->__satpass2_defined_templates() ], [ qw{ foo } ],
    'Defined templates';

ok $tp->__satpass2_template( foo => 'bazzle' ), 'Update template foo';

is scalar $tp->__satpass2_template( 'foo' ), 'bazzle',
    'Content of foo via scalar __satpass_template';

is( ( $tp->__satpass2_template( 'foo' ) )[0], 'bazzle',
    'Content of foo via list __satpass_template' );

is( ( $tp->__satpass2_template( 'foo' ) )[1], 2,
    'Pseudo-modification time of foo via list __satpass_template' );

is $tp->_template_modified( 'foo' ), 2,
    'Pseudo-modification time of foo via _template_modified';

is scalar $tp->_template_content( 'foo' ), 'bazzle',
    'Content of foo via scalar _template_content';

is( ( $tp->_template_content( 'foo' ) )[0], 'bazzle',
    'Content of foo via list _template_content' );

is( ( $tp->_template_content( 'foo' ) )[1], STATUS_OK,
    'Status of foo via list _template_content' );

done_testing;

1;

# ex: set textwidth=72 :
