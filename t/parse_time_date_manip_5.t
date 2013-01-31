package main;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;
use Astro::App::Satpass2::Test::App;

BEGIN {

    eval {

	# Force Date::Manip 5 backend if we have Date::Manip 6.
	local $Date::Manip::Backend = 'DM5';

	require Date::Manip;

	1;
    } or plan skip_all => 'Date::Manip not available';

    $^O eq 'MSWin32'
	and plan skip_all => 'Date::Manip 5 tests fail under Windows';

    eval {
	require Time::y2038;
	Time::y2038->import( qw{ timegm timelocal } );
	1;
    } or eval {
	require Time::Local;
	Time::Local->import( qw{ timegm timelocal } );
	1;
    } or do {
	plan skip_all =>
	    'Time::y2038 or Time::Local required';
	exit;
    };

}

# The following is a hook for the author test that forces this to run
# under Date::Manip 5.54. We want the author test to fail if we get
# version 6.

our $DATE_MANIP_5_REALLY;

if ( $DATE_MANIP_5_REALLY ) {
    ( my $ver = Date::Manip->VERSION() ) =~ s/ _ //smxg;
    cmp_ok $ver, '<', 6, 'Date::Manip version is really less than 6';
}

require_ok 'Astro::App::Satpass2::ParseTime';

class 'Astro::App::Satpass2::ParseTime';

method new => class => 'Astro::App::Satpass2::ParseTime::Date::Manip',
    INSTANTIATE, 'Instantiate';

method isa => 'Astro::App::Satpass2::ParseTime::Date::Manip::v5', TRUE,
    'Object is an Astro::App::Satpass2::ParseTime::Date::Manip::v5';

method isa => 'Astro::App::Satpass2::ParseTime', TRUE,
    'Object is an Astro::App::Satpass2::ParseTime';

method 'delegate',
    'Astro::App::Satpass2::ParseTime::Date::Manip::v5',
    'Delegate is Astro::App::Satpass2::ParseTime::Date::Manip::v5';

method use_perltime => TRUE, 'Uses perltime';

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

method parse => '20090101T000000Z',
    timegm( 0, 0, 0, 1, 0, 109 ),
    'Parse ISO-8601 20090101T000000Z'
    or dump_date_manip();

method parse => '20090701T000000Z',
    timegm( 0, 0, 0, 1, 6, 109 ),
    'Parse ISO-8601 20090701T000000Z'
    or dump_date_manip();

done_testing;

{

    my $dumped;

    sub dump_date_manip {
	$dumped++
	    and return;

	my $vers = Date::Manip->VERSION();

	diag '';

	diag "Date::Manip version: $vers";

	$vers =~ s/ _ //smxg;

	if ( $vers >= 6 ) {

	    diag 'Date::Manip superclasses: ', join ', ', @Date::Manip::ISA;

	    if ( Date::Manip->isa( 'Date::Manip::DM5' ) ) {
		diag '$Cnf{Language}: ', $Date::Manip::DM5::Cnf{Language};
	    }

	}

	return;
    }
}

1;

# ex: set textwidth=72 :
