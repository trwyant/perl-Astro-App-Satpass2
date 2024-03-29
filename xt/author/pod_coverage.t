package main;

use strict;
use warnings;

use Test::More 0.88;

BEGIN {
    eval {
	require Test::Pod::Coverage;
	Test::Pod::Coverage->VERSION(1.00);
	Test::Pod::Coverage->import();
	1;
    } or do {
	print <<eod;
1..0 # skip Test::Pod::Coverage 1.00 or greater required.
eod
	exit;
    };
}

{
    local $@ = undef;
    eval {
	no warnings qw{ deprecated };
	require Date::Manip::DM5;
    };
}

all_pod_coverage_ok ({
	also_private => [
	    qr{^[[:upper:]\d_]+$},
	    # The following is my convention for subroutine attributes.
	    qr{^[[:upper:]][[:lower:]]+$},
	],
	coverage_class => 'Pod::Coverage::CountParents'
    });

1;

# ex: set textwidth=72 :
