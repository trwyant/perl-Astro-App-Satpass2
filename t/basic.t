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
    $date_manip_delegate = 'App::Satpass2::ParseTime::Date::Manip::v5';
    Date::Manip->VERSION( 6.0 );
    $date_manip_delegate = 'App::Satpass2::ParseTime::Date::Manip::v6';
};


plan( tests => 45 );

require_ok( 'App::Satpass2::Copier' )
    or BAIL_OUT();

require_ok( 'App::Satpass2::FormatTime' );

isa_ok( 'App::Satpass2::FormatTime', 'App::Satpass2::Copier' );

require_ok( 'App::Satpass2::FormatTime::POSIX' );

isa_ok( 'App::Satpass2::FormatTime::POSIX', 'App::Satpass2::FormatTime' );

isa_ok( 'App::Satpass2::FormatTime::POSIX',
    'App::Satpass2::FormatTime::Strftime' );

instantiate( 'App::Satpass2::FormatTime::POSIX' );

SKIP: {

    eval {
	require DateTime;
	require DateTime::TimeZone;
	1;
    } or skip( 'DateTime and/or DateTime::TimeZone not available', 10 );

    require_ok( 'App::Satpass2::FormatTime::DateTime' );

    isa_ok( 'App::Satpass2::FormatTime::DateTime',
	'App::Satpass2::FormatTime' );

    require_ok( 'App::Satpass2::FormatTime::DateTime::Strftime' );

    isa_ok( 'App::Satpass2::FormatTime::DateTime::Strftime',
	'App::Satpass2::FormatTime::DateTime' );

    isa_ok( 'App::Satpass2::FormatTime::DateTime::Strftime',
	'App::Satpass2::FormatTime::Strftime' );

    instantiate( 'App::Satpass2::FormatTime::DateTime::Strftime' );

    require_ok( 'App::Satpass2::FormatTime::DateTime::Cldr' );

    isa_ok( 'App::Satpass2::FormatTime::DateTime::Cldr',
	'App::Satpass2::FormatTime::DateTime' );

    isa_ok( 'App::Satpass2::FormatTime::DateTime::Cldr',
	'App::Satpass2::FormatTime::Cldr' );

    instantiate( 'App::Satpass2::FormatTime::DateTime::Cldr' );

}

instantiate( 'App::Satpass2::FormatTime' );

require_ok( 'App::Satpass2::Format' )
    or BAIL_OUT();

isa_ok( 'App::Satpass2::Format', 'App::Satpass2::Copier' );

require_ok( 'App::Satpass2::Format::Dump' )
    or BAIL_OUT();

isa_ok( 'App::Satpass2::Format::Dump', 'App::Satpass2::Format' );

instantiate( 'App::Satpass2::Format::Dump' );

require_ok( 'App::Satpass2::Format::Classic' )
    or BAIL_OUT();

isa_ok( 'App::Satpass2::Format::Classic', 'App::Satpass2::Format' );

instantiate( 'App::Satpass2::Format::Classic' );

require_ok( 'App::Satpass2::ParseTime' );

isa_ok( 'App::Satpass2::ParseTime', 'App::Satpass2::Copier' );

require_ok( 'App::Satpass2::ParseTime::Date::Manip' )
    or BAIL_OUT();

is( eval { App::Satpass2::ParseTime::Date::Manip->delegate() },	## no critic (RequireCheckingReturnValueOfEval)
    $date_manip_delegate,
    'Date::Manip delegate is ' . (
	defined $date_manip_delegate ? $date_manip_delegate : 'undef' ),
);

require_ok( 'App::Satpass2::ParseTime::Date::Manip::v5' )
    or BAIL_OUT();

isa_ok( 'App::Satpass2::ParseTime::Date::Manip::v5',
    'App::Satpass2::ParseTime' );

require_ok( 'App::Satpass2::ParseTime::Date::Manip::v6' )
    or BAIL_OUT();

isa_ok( 'App::Satpass2::ParseTime::Date::Manip::v6',
    'App::Satpass2::ParseTime' );

require_ok( 'App::Satpass2::ParseTime::ISO8601' )
    or BAIL_OUT();

isa_ok( 'App::Satpass2::ParseTime::ISO8601',
    'App::Satpass2::ParseTime' );

is( eval { App::Satpass2::ParseTime::ISO8601->delegate() },	## no critic (RequireCheckingReturnValueOfEval)
    'App::Satpass2::ParseTime::ISO8601',
    'ISO8601 delegate is App::Satpass2::ParseTime::ISO8601' );

SKIP: {
    $date_manip_delegate
	or skip( "Unable to load Date::Manip", 1 );
    instantiate( 'App::Satpass2::ParseTime',
	'App::Satpass2::ParseTime::Date::Manip',
	$date_manip_delegate );
}

instantiate( 'App::Satpass2::ParseTime',
    'App::Satpass2::ParseTime::ISO8601',
    'App::Satpass2::ParseTime::ISO8601' );

{

    my $want_class = $date_manip_delegate ||
	'App::Satpass2::ParseTime::ISO8601';

    instantiate( 'App::Satpass2::ParseTime', $want_class );

    instantiate( 'App::Satpass2::ParseTime',
	'App::Satpass2::ParseTime::Date::Manip App::Satpass2::ParseTime::ISO8601',
	$want_class );

    instantiate( 'App::Satpass2::ParseTime',
	'App::Satpass2::ParseTime::Date::Manip',
	'App::Satpass2::ParseTime::ISO8601',
	$want_class );

    instantiate( 'App::Satpass2::ParseTime',
	'App::Satpass2::ParseTime::ISO8601',
	'App::Satpass2::ParseTime::Date::Manip',
	'App::Satpass2::ParseTime::ISO8601' );

}

require_ok( 'App::Satpass2' )
    or BAIL_OUT();

instantiate( 'App::Satpass2' );


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
