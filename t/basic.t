package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 required\n";
	exit;
    }
}

my $date_manip_delegate;
eval {	## no critic (RequireCheckingReturnValueOfEval)
    require Date::Manip;
    $date_manip_delegate = 'Astro::App::Satpass2::ParseTime::Date::Manip::v5';
    Date::Manip->VERSION( 6.0 );
    $date_manip_delegate = 'Astro::App::Satpass2::ParseTime::Date::Manip::v6';
};


plan( tests => 42 );

require_ok( 'Astro::App::Satpass2::Copier' )
    or BAIL_OUT();

require_ok( 'Astro::App::Satpass2::FormatTime' );

isa_ok( 'Astro::App::Satpass2::FormatTime', 'Astro::App::Satpass2::Copier' );

require_ok( 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' );

isa_ok( 'Astro::App::Satpass2::FormatTime::POSIX::Strftime',
    'Astro::App::Satpass2::FormatTime' );

instantiate( 'Astro::App::Satpass2::FormatTime::POSIX::Strftime' );

SKIP: {

    eval {
	require DateTime;
	require DateTime::TimeZone;
	1;
    } or skip( 'DateTime and/or DateTime::TimeZone not available', 8 );

    require_ok( 'Astro::App::Satpass2::FormatTime::DateTime' );

    isa_ok( 'Astro::App::Satpass2::FormatTime::DateTime',
	'Astro::App::Satpass2::FormatTime' );

    require_ok( 'Astro::App::Satpass2::FormatTime::DateTime::Strftime' );

    isa_ok( 'Astro::App::Satpass2::FormatTime::DateTime::Strftime',
	'Astro::App::Satpass2::FormatTime::DateTime' );

    instantiate( 'Astro::App::Satpass2::FormatTime::DateTime::Strftime' );

    require_ok( 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' );

    isa_ok( 'Astro::App::Satpass2::FormatTime::DateTime::Cldr',
	'Astro::App::Satpass2::FormatTime::DateTime' );

    instantiate( 'Astro::App::Satpass2::FormatTime::DateTime::Cldr' );

}

instantiate( 'Astro::App::Satpass2::FormatTime' );

require_ok( 'Astro::App::Satpass2::Format' )
    or BAIL_OUT();

isa_ok( 'Astro::App::Satpass2::Format', 'Astro::App::Satpass2::Copier' );

require_ok( 'Astro::App::Satpass2::Format::Dump' )
    or BAIL_OUT();

isa_ok( 'Astro::App::Satpass2::Format::Dump', 'Astro::App::Satpass2::Format' );

instantiate( 'Astro::App::Satpass2::Format::Dump' );

require_ok( 'Astro::App::Satpass2::Format::Classic' )
    or BAIL_OUT();

isa_ok( 'Astro::App::Satpass2::Format::Classic', 'Astro::App::Satpass2::Format' );

instantiate( 'Astro::App::Satpass2::Format::Classic' );

require_ok( 'Astro::App::Satpass2::ParseTime' );

isa_ok( 'Astro::App::Satpass2::ParseTime', 'Astro::App::Satpass2::Copier' );

require_ok( 'Astro::App::Satpass2::ParseTime::Date::Manip' )
    or BAIL_OUT();

is( eval { Astro::App::Satpass2::ParseTime::Date::Manip->delegate() },	## no critic (RequireCheckingReturnValueOfEval)
    $date_manip_delegate,
    'Date::Manip delegate is ' . (
	defined $date_manip_delegate ? $date_manip_delegate : 'undef' ),
);

require_ok( 'Astro::App::Satpass2::ParseTime::Date::Manip::v5' )
    or BAIL_OUT();

isa_ok( 'Astro::App::Satpass2::ParseTime::Date::Manip::v5',
    'Astro::App::Satpass2::ParseTime' );

require_ok( 'Astro::App::Satpass2::ParseTime::Date::Manip::v6' )
    or BAIL_OUT();

isa_ok( 'Astro::App::Satpass2::ParseTime::Date::Manip::v6',
    'Astro::App::Satpass2::ParseTime' );

require_ok( 'Astro::App::Satpass2::ParseTime::ISO8601' )
    or BAIL_OUT();

isa_ok( 'Astro::App::Satpass2::ParseTime::ISO8601',
    'Astro::App::Satpass2::ParseTime' );

is( eval { Astro::App::Satpass2::ParseTime::ISO8601->delegate() },	## no critic (RequireCheckingReturnValueOfEval)
    'Astro::App::Satpass2::ParseTime::ISO8601',
    'ISO8601 delegate is Astro::App::Satpass2::ParseTime::ISO8601' );

SKIP: {
    $date_manip_delegate
	or skip( "Unable to load Date::Manip", 1 );
    instantiate( 'Astro::App::Satpass2::ParseTime',
	'Astro::App::Satpass2::ParseTime::Date::Manip',
	$date_manip_delegate );
}

instantiate( 'Astro::App::Satpass2::ParseTime',
    'Astro::App::Satpass2::ParseTime::ISO8601',
    'Astro::App::Satpass2::ParseTime::ISO8601' );

{

    my $want_class = $date_manip_delegate ||
	'Astro::App::Satpass2::ParseTime::ISO8601';

    instantiate( 'Astro::App::Satpass2::ParseTime', $want_class );

    instantiate( 'Astro::App::Satpass2::ParseTime',
	'Astro::App::Satpass2::ParseTime::Date::Manip Astro::App::Satpass2::ParseTime::ISO8601',
	$want_class );

    instantiate( 'Astro::App::Satpass2::ParseTime',
	'Astro::App::Satpass2::ParseTime::Date::Manip',
	'Astro::App::Satpass2::ParseTime::ISO8601',
	$want_class );

    instantiate( 'Astro::App::Satpass2::ParseTime',
	'Astro::App::Satpass2::ParseTime::ISO8601',
	'Astro::App::Satpass2::ParseTime::Date::Manip',
	'Astro::App::Satpass2::ParseTime::ISO8601' );

}

require_ok( 'Astro::App::Satpass2' )
    or BAIL_OUT();

instantiate( 'Astro::App::Satpass2' );


sub instantiate {
    my ( $class, @args ) = @_;
    my $want = @args ? pop @args : $class;
    if ( my $obj = eval { $class->new( @args ) } ) {
	@_ = ( $obj, $want );
	goto &isa_ok;
    } else {
	@_ = ( "Can't instantiate $class: $@" );
	goto &fail;
    }
}


1;

# ex: set textwidth=72 :
