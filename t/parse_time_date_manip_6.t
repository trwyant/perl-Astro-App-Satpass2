package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

BEGIN {

    eval {
	require Date::Manip;
	1;
    } or do {
	plan skip_all => 'Date::Manip not available';
	exit;
    };

    my $ver = Date::Manip->VERSION();
    Date::Manip->import();
    ( my $test = $ver ) =~ s/ _ //smxg;
    $test >= 6 or do {
	plan skip_all =>
	    "Date::Manip $ver installed; this test is for 6.00 or greater";
	exit;
    };

    eval {
	require Time::y2038;
	Time::y2038->import( qw{ timegm timelocal } );
	1;
    } or eval {
	require Time::Local;
	Time::Local->import( qw{ timegm timelocal } );
	1;
    } or do {
	plan skip_all => 'Time::y2038 or Time::Local required';
	exit;
    };

}

require_ok 'Astro::App::Satpass2::ParseTime';

class 'Astro::App::Satpass2::ParseTime';

method new => class => 'Astro::App::Satpass2::ParseTime::Date::Manip',
    INSTANTIATE, 'Instantiate';

method isa => 'Astro::App::Satpass2::ParseTime::Date::Manip::v6', TRUE,
    'Object is an Astro::App::Satpass2::ParseTime::Date::Manip::v6';

method isa => 'Astro::App::Satpass2::ParseTime', TRUE,
    'Object is an Astro::App::Satpass2::ParseTime';

method 'delegate',
    'Astro::App::Satpass2::ParseTime::Date::Manip::v6',
    'Delegate is Astro::App::Satpass2::ParseTime::Date::Manip::v6';

method 'use_perltime', FALSE, 'Does not use perltime';

method parse => '20100202T120000Z',
    timegm( 0, 0, 12, 2, 1, 110 ),
    'Parse noon on Groundhog Day 2010';

my $base = timegm( 0, 0, 0, 1, 3, 109 );	# April 1, 2009 GMT;
use constant ONE_DAY => 86400;			# One day, in seconds.
use constant HALF_DAY => 43200;			# 12 hours, in seconds.

method base => $base, TRUE, 'Set base time to 01-Apr-2009 GMT';

method parse => '+0', $base, 'Parse of +0 returns base time';

method parse => '+1', $base + ONE_DAY,
    'Parse of +1 returns one day later than base time';

method parse => '+0', $base + ONE_DAY,
    'Parse of +0 now returns one day later than base time';

method 'reset', TRUE, 'Reset to base time';

method parse => '+0', $base, 'Parse of +0 returns base time again';

method parse => '+0 12', $base + HALF_DAY,
    q{Parse of '+0 12' returns base time plus 12 hours};

method 'reset', TRUE, 'Reset to base time again';

method parse => '-0', $base, 'Parse of -0 returns base time';

method parse => '-0 12', $base - HALF_DAY,
    'Parse of \'-0 12\' returns 12 hours before base time';

method perltime => 1, TRUE, 'Set perltime true';

method parse => '20090101T000000',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000';

method parse => '20090701T000000',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000';

method perltime => 0, TRUE, 'Set perltime false';

method parse => '20090101T000000',
    timelocal( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000, no help from perltime';

method parse => '20090701T000000',
    timelocal( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000, no help from perltime';

method parse => '20090101T000000Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000Z';

method parse => '20090701T000000Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000Z';

done_testing;

1;

# ex: set textwidth=72 :
