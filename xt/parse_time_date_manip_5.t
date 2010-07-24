package main;

use strict;
use warnings;

BEGIN {

    -d 'date_manip_v5' and eval {
	require lib;
	lib->import( 'date_manip_v5' );
	1;
    } or do {
	print "1..0 # skip Directory date_manip_v5/ required\n";
	exit;
    };

}

require 't/parse_time_date_manip_5.t';
