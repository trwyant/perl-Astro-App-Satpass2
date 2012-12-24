package Astro::App::Satpass2::FormatValue;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Copier };

use Astro::App::Satpass2::FormatTime;
use Astro::App::Satpass2::Utils qw{ has_method instance };
use Astro::App::Satpass2::Warner;
use Astro::Coord::ECI::Sun;
use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::Utils qw{ deg2rad embodies julianday PI rad2deg TWOPI };
use Clone ();
use List::Util qw{ max min };
use POSIX qw{ floor };
use Scalar::Util qw{ reftype };
use Text::Wrap ();

our $VERSION = '0.011';

use constant NONE => undef;
use constant TITLE_GRAVITY_BOTTOM	=> 'bottom';
use constant TITLE_GRAVITY_TOP		=> 'top';

#	Instantiator

{
    my %locale = (
	almanac	=> {
	    title	=> 'Almanac',
	},
	altitude	=> {
	    title	=> 'Altitude',
	},
	angle	=> {
	    title	=> 'Angle',
	},
	apoapsis	=> {
	    title	=> 'Apoapsis',
	},
	apogee	=> {
	    title	=> 'Apogee',
	},
	argument_of_perigee	=> {
	    title	=> 'Argument Of Perigee',
	},
	ascending_node	=> {
	    title	=> 'Ascending Node',
	},
	azimuth	=> {
	    title	=> 'Azimuth',
	},
	bearing	=> {
	    table	=> [
		[ qw{ N E S W } ],
		[ qw{ N NE E SE S SW W NW } ],
		[ qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW
		    NNW } ],
	    ],
	},
	b_star_drag	=> {
	    title	=> 'B Star Drag',
	},
	classification	=> {
	    title	=> 'Classification',
	},
	date	=> {
	    title	=> 'Date',
	},
	declination	=> {
	    title	=> 'Declination',
	},
	eccentricity	=> {
	    title	=> 'Eccentricity',
	},
	effective_date	=> {
	    title	=> 'Effective Date',
	},
	element_number	=> {
	    title	=> 'Element Number',
	},
	elevation	=> {
	    title	=> 'Elevation',
	},
	ephemeris_type	=> {
	    title	=> 'Ephemeris Type',
	},
	epoch	=> {
	    title	=> 'Epoch',
	},
	event	=> {
	    table	=> [ '', qw{ shdw lit day rise max set apls } ],
	    title	=> 'Event',
	},
	first_derivative	=> {
	    title	=> 'First Derivative',
	},
	fraction_lit	=> {
	    title	=> 'Fraction Lit',
	},
	illumination	=> {
	    title	=> 'Illumination',
	},
	inclination	=> {
	    title	=> 'Inclination',
	},
	international	=> {
	    title	=> 'International Launch Designator',
	},
	latitude	=> {
	    title	=> 'Latitude',
	},
	longitude	=> {
	    title	=> 'Longitude',
	},
	magnitude	=> {
	    title	=> 'Magnitude',
	},
	maidenhead	=> {
	    title	=> 'Maidenhead Grid Square',
	},
	mean_anomaly	=> {
	    title	=> 'Mean Anomaly',
	},
	mean_motion	=> {
	    title	=> 'Mean Motion',
	},
	mma	=> {
	    title	=> 'MMA',
	},
	name	=> {
	    title	=> 'Name',
	},
	oid	=> {
	    title	=> 'OID',
	},
	operational	=> {
	    title	=> 'Operational',
	},
	periapsis	=> {
	    title	=> 'Periapsis',
	},
	perigee	=> {
	    title	=> 'Perigee',
	},
	period	=> {
	    title	=> 'Period',
	},
	phase	=> {
	    table	=> [
		[6.1 => 'new'], [83.9 => 'waxing crescent'],
		[96.1 => 'first quarter'], [173.9 => 'waxing gibbous'],
		[186.1 => 'full'], [263.9 => 'waning gibbous'],
		[276.1 => 'last quarter'], [353.9 => 'waning crescent'],
	    ],
	    title	=> 'Phase',
	},
	range	=> {
	    title	=> 'Range',
	},
	revolutions_at_epoch	=> {
	    title	=> 'Revolutions At Epoch',
	},
	right_ascension	=> {
	    title	=> 'Right Ascension',
	},
	second_derivative	=> {
	    title	=> 'Second Derivative',
	},
	semimajor	=> {
	    title	=> 'Semimajor Axis',
	},
	semiminor	=> {
	    title	=> 'Semiminor Axis',
	},
	status	=> {
	    title	=> 'Status',
	},
	time	=> {
	    title	=> 'Time',
	},
	tle	=> {
	    title	=> 'TLE',
	},
	type	=> {
	    title	=> 'Type',
	},
    );

    sub new {
	my ( $class, %args ) = @_;
	ref $class and $class = ref $class;
	my $self = {};
	bless $self, $class;

	$self->warner( delete $args{warner} );

	foreach my $name ( qw{ data default } ) {
	    $self->{$name} = $args{$name} || {};
	    ref $self->{$name}
		and 'HASH' eq reftype( $self->{$name} )
		or $self->{warner}->wail(
		"Argument '$name' must be a hash reference" );
	}

	$self->{desired_equinox_dynamical} =
	    $args{desired_equinox_dynamical} || 0;

	$self->{fixed_width} = exists $args{fixed_width} ?
	    $args{fixed_width} :
	    1;

	$self->{locale} = $args{locale} || \%locale;

	$self->{overflow} = $args{overflow} || 0;

	defined( $self->{local_coordinates} = $args{local_coordinates} )
	    or $self->{local_coordinates} = \&__local_coord_azel_rng;
	ref $self->{local_coordinates}
	    or $self->{local_coordinates} = $self->can(
		"__local_coord_$self->{local_coordinates}" )
	    or $self->{warner}->wail(
		"Unknown local_coordinates $self->{local_coordinates}" );
	'CODE' eq ref $self->{local_coordinates}
	    or $self->{warner}->wail(
		'Argument local_coordinates must be a code reference ',
		'or the name of a known coordinate system'
	    );

	$self->{title} = $args{title};

	$self->title_gravity( _dor( $args{title_gravity},
		TITLE_GRAVITY_TOP ) );

	$self->{time_formatter} = $args{time_formatter} ||
	    'Astro::App::Satpass2::FormatTime';
	ref $self->{time_formatter}
	    or $self->{time_formatter} = $self->{time_formatter}->new();
	instance( $self->{time_formatter},
	    'Astro::App::Satpass2::FormatTime' )
	    or $self->{warner}->wail(
	    'Argument time_formatter must be an Astro::App::Satpass2::FormatTime'
	);
	$self->{date_format} = $args{date_format};
	defined $self->{date_format}
	    or $self->{date_format} = $self->{time_formatter}->DATE_FORMAT();
	$self->{time_format} = $args{time_format};
	defined $self->{time_format}
	    or $self->{time_format} = $self->{time_formatter}->TIME_FORMAT();

	foreach my $action ( $self->_uses_date_format() ) {
	    my $fmt = $self->_make_date_format( $action );
	    my $width = $self->{time_formatter}->format_datetime_width( $fmt );
	    $self->{internal}{$action}{width} = $width;
	    $self->{internal}{$action}{format} = $fmt;
	}

	return $self;
    }

}

#	Overrides

sub clone {
    my ( $self, @args ) = @_;
    my %arg;
    if ( @args == 1 && ref $args[0] eq 'HASH' ) {
	%arg = %{ $args[0] };
    } else {
	%arg = @args;
    }
    while ( my ( $name, $value ) = each %{ $self } ) {
	defined $arg{$name}
	    or $arg{$name} = $value;
    }
    delete $arg{internal};
    return $self->new( %arg );
}

#	Accessors.

sub body {	# Required for template 'list', which needs to figure
		# out whether the body is inertial or not.
    my ( $self ) = @_;
    return $self->_get_eci( 'body' );
}

#	Mutators. These should be kept to a minimum.

sub fixed_width {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->{fixed_width} = $args[0];
	return $self;
    } else {
	return $self->{fixed_width};
    }
}

sub title_gravity {
    my ( $self, @args ) = @_;
    if ( @args ) {
	is_valid_title_gravity( $args[0] )
	    or $self->{warner}->wail(
		"Attribute title_gravity value '$args[0]' invalid"
	    );
	$self->{title_gravity} = $args[0];
	return $self;
    } else {
	return $self->{title_gravity};
    }
}

#	Transformations

sub appulse {
    my ( $self ) = @_;
    return $self->_variant( 'appulse' );
}

sub bodies {
    my ( $self ) = @_;
    my $bodies = $self->_get( data => 'bodies' )
	or return;

    my $questionable = $self->_get( data => 'questionable' );
    my $sta = $self->_get( data => 'station' );
    my $sun = Astro::Coord::ECI::Sun->new();
    my $time = $self->_get( data => 'time' );
    my $twilight = $self->_get( data => 'twilight' );
    defined $twilight
	or $twilight = deg2rad( -6 );	# Civil

    my @rslt;
    foreach my $body ( @{ $bodies } ) {
	embodies( $body, 'Astro::Coord::ECI' )
	    or next;

	my $data = {
	    body		=> $body,
	    illumination	=> _illumination(
		body	=> $body,
		station	=> $sta,
		time	=> $time,
		sun	=> $sun,
		twilight => $twilight,
	    ),
	    questionable	=> $questionable,
	};

	push @rslt, $self->_variant( $data );
    }

    return \@rslt;
}

sub _elevation {
    my ( $station, $body, $time ) = @_;
    defined $time and $body->universal( $time );
    return ( $station->azel( $body ) )[1];
}

sub _illumination {
    my ( $station, $body, $time, $twilight, $sun ) = @_;

    my %arg = @_;

    embodies( $arg{body}, 'Astro::Coord::ECI::TLE' )
	or return PASS_EVENT_NONE;

    defined $arg{time}
	or $arg{time} = $arg{body}->universal();

    embodies( $arg{sun}, 'Astro::Coord::ECI' )
	or $arg{sun} = $arg{body}->get( 'illum' );
    embodies( $arg{sun}, 'Astro::Coord::ECI' )
	or $arg{sun} = Astro::Coord::ECI::Sun->new();

    defined $arg{twilight}
	or $arg{twilight} = _dor(
	    $arg{body}->get( 'twilight' ),
	    deg2rad( -6 ),	# Civil
	);

    defined $arg{time}
	and embodies( $arg{station}, 'Astro::Coord::ECI' )
	and _elevation( $arg{station}, $arg{body}, $arg{time} ) >= 0
	or return PASS_EVENT_NONE;

    _elevation( $arg{station}, $arg{sun}, $arg{time} ) > $arg{twilight}
	and return PASS_EVENT_DAY;

    _elevation( $arg{body}, $arg{sun} ) > $arg{body}->dip()
	and return PASS_EVENT_LIT;

    return PASS_EVENT_SHADOWED;
}

sub center {
    my ( $self ) = @_;
    return $self->_variant( 'center' );
}

sub earth {
    my ( $self ) = @_;
    my $earth = $self->_variant();
    $earth->{data}{station} = Astro::Coord::ECI->new()->ecef( 0, 0, 0 );
    return $earth;
}

sub events {
    my ( $self ) = @_;
    return [ map { $self->clone( data => $_ ) } $self->__raw_events() ];
}

sub __raw_events {
    my ( $self ) = @_;

    my $events = $self->_get( data => 'events' )
	or return;

    'ARRAY' eq ref $events
	or return;

    return @{ $events };
}

sub reflections {
    my ( $self ) = @_;

    my $body = $self->_get_tle( 'body' )
	or return;

    my $sta = $self->_get_eci( 'station' )
	or return;

    my $time = $self->_get( data => 'time' );
    defined $time
	or $time = $body->universal();
    defined $time or return;

    my $illum = $self->_get( data => 'illumination' );
    defined $illum
	or $illum = _illumination(
	    body	=> $body,
	    station	=> $sta,
	    time	=> $time,
	);

    $illum
	and ( PASS_EVENT_LIT == $illum
	    or PASS_EVENT_DAY == $illum )
	and $body->can_flare( $self->_get( data => 'questionable' ) )
	or return;

    $body->set( horizon => 0 );
    my @rslt;
    foreach my $info ( $body->reflection( $sta, $time ) ) {
	push @rslt, $self->_variant( $info );
    }

    return \@rslt;
}

sub station {
    my ( $self ) = @_;
    my $station = $self->_variant();
    ( $station->{data}{body}, $station->{data}{station} ) = (
	map { $station->_get( data => $_ ) } qw{ station body } );
    return $station;
}

#	Formatters

sub local_coord {
    my ( $self, %arg ) = _arguments( @_ );
    return $self->{local_coordinates}->( $self, %arg );
}

sub __local_coord_az_rng {
    my ( $self, @arg ) = _arguments( @_ );
    return join ' ', $self->azimuth( @arg, { bearing => 2 } ),
	$self->range( @arg );
}

sub __local_coord_azel {
    my ( $self, @arg ) = _arguments( @_ );
    return join ' ', $self->elevation( @arg ),
	$self->azimuth( @arg, { bearing => 2 } );
}

sub __local_coord_azel_rng {
    my ( $self, @arg ) = _arguments( @_ );
    return join ' ', $self->elevation( @arg ),
	$self->azimuth( @arg, { bearing => 2 } ),
	$self->range( @arg );
}

sub __local_coord_equatorial {
    my ( $self, @arg ) = _arguments( @_ );
    return join ' ', $self->right_ascension( @arg ),
	$self->declination( @arg );
}

sub __local_coord_equatorial_rng {
    my ( $self, @arg ) = _arguments( @_ );
    return join ' ', $self->right_ascension( @arg ),
	$self->declination( @arg ),
	$self->range( @arg );
}

#	The %dimensions hash defines physical dimensions and the
#	allowable units for each. The keys of this hash are the names of
#	physical dimensions (e.g. 'length', 'mass', 'volume', and so
#	on), and the values are hashes defining the dimension.
#
#	Each dimension definition hash must have the following keys:
#
#	align_left => boolean
#	    This optional key, if true, specifies that the value is to
#	    be aligned to the left in its field. This value can be
#	    overridden in the {define} key, or when the formatter is
#	    called.
#
#	default => the name of the default units for the dimension. This
#	    value must appear as a key in the define hash (see below).
#	    This default can be overridden by a given format effector.
#
#	define => a hash defining the legal units for the dimension. The
#	    keys are the names of the units (e.g. for length
#	    'kilometers', 'meters', 'miles', 'feet'). The value is a
#	    hash containing zero or more of the following keys:
#
#	    alias => name
#	        This optional key specifies that the name is just an
#	        alias for another key, which must exist in the define
#	        hash. No other keys need be specified.
#
#	    align_left => boolean
#		This optional key, if true, specifies that the value is
#		to be aligned to the left of its field. It can be
#		overridden by a value specified when the formatter is
#		called.
#
#	    factor => number
#		A number to multiply the value by to do the conversion.
#
#	    formatter => name
#		This optional key specifies the name of the formatter
#		routine to use instead of the normal one.
#
#	    method => _name
#		This optional key specifies a method to call. The method
#		is passed the value being formatted, and the method's
#		return becomes the new value to format. If both {factor}
#		and {method} are specified, {method} is done first.
#
#	formatter => name
#	    This key specifies the formatter to use for the units. It
#	    can be overridden in the {define} key.

my %dimensions = (

    almanac_pseudo_units	=> {
	default	=> 'description',
	define	=> {
	    event	=> {},
	    detail	=> {
		formatter	=> '_format_integer',
	    },
	    description	=> {},
	},
	formatter	=> '_format_string',
    },

    angle_units => {
	align_left	=> 0,
	default		=> 'degrees',
	define	=> {
	    bearing	=> {
		align_left	=> 1,
		formatter	=> '_format_bearing',
	    },
	    decimal	=> {
		alias		=> 'degrees',
	    },
	    degrees	=> {
		factor		=> 90/atan2( 1, 0 ),
	    },
	    radians	=> {},
	    phase	=> {
		align_left	=> 1,
		formatter	=> '_format_phase',
	    },
	    right_ascension	=> {
		formatter	=> '_format_right_ascension',
	    },
	},
	formatter	=> '_format_number',
    },

    dimensionless	=> {
	default		=> 'unity',
	define		=> {
	    percent	=> {
		factor	=> 100,
	    },
	    unity	=> {},
	},
	formatter	=> '_format_number',
    },

    duration => {
	default		=> 'composite',
	define => {
	    composite	=> {
		formatter	=> '_format_duration',
	    },
	    seconds	=> {},
	    minutes	=> {
		factor	=> 1/60,
	    },
	    hours	=> {
		factor	=> 1/3600,
	    },
	    days	=> {
		factor	=> 1/86400,
	    },
	},
	formatter	=> '_format_number',
    },

    event_pseudo_units	=> {
	default	=> 'localized',
	define	=> {
	    localized	=> {},
	    integer	=> {
		formatter	=> '_format_integer',
	    },
	    string	=> {},
	},
	formatter	=> '_format_event',
    },

    integer_pseudo_units	=> {
	align_left	=> 0,
	default	=> 'integer',
	define	=> {
	    integer	=> {},
	},
	formatter	=> '_format_integer',
    },

    length => {
	align_left	=> 0,
	default		=> 'kilometers',
	define	=> {
	    kilometers	=> {},
	    km		=> {},
	    meters	=> {
		factor		=> 1000,
	    },
	    m		=> {
		alias		=> 'meters',
	    },
	    miles	=> {
		factor		=> 0.62137119,
	    },
	    mi		=> {
		alias		=> 'miles',
	    },
	    feet	=> {
		factor		=> 3280.8399,
	    },
	    ft		=> {
		alias		=> 'feet',
	    },
	},
	formatter	=> '_format_number',
    },

    number	=> {	# Just for consistency's sake
	align_left	=> 0,
	default		=> 'number',
	define		=> {
	    number	=> {},
	},
	formatter	=> '_format_number',
    },

    scientific	=> {	# Just for consistency's sake
	align_left	=> 0,
	default		=> 'scientific',
	define		=> {
	    scientific	=> {},
	},
	formatter	=> '_format_number_scientific',
    },

    string	=> {	# for tle, to prevent munging data. ONLY
			# 'string' is to be defined.
	default	=> 'string',
	define	=> {
	    string	=> {},
	},
	formatter	=> '_format_string',
    },

    string_pseudo_units	=> {
	default	=> 'string',
	define	=> {
	    lower_case	=> {
		formatter	=> '_format_lower_case',
	    },
	    string	=> {},
	    title_case	=> {
		formatter	=> '_format_title_case',
	    },
	    upper_case	=> {
		formatter	=> '_format_upper_case',
	    },
	},
	formatter	=> '_format_string',
    },

    time_units => {
	default		=> 'local',
	define	=> {
	    days_since_epoch => {
		factor	=> 1/86400,
		formatter => '_format_number',
		method	=> '_subtract_epoch',
	    },
	    gmt		=> {
		gmt	=> 1,
	    },
	    julian	=> {
		formatter	=> '_format_number',
		method		=> '_julian_day',
	    },
	    local	=> {},
	    universal	=> {
		alias	=> 'gmt',
	    },
	    z		=> {
		alias	=> 'gmt',
	    },
	    zulu	=> {
		alias	=> 'gmt',
	    },
	},
	formatter	=> '_format_time',
    },

);

sub __list_dimensions {
    return \%dimensions;
}

#	The following hash is used for generating formatter methods, as
#	a way of avoiding the replication of common code. The keys are
#	the method names, and the values are hashes which specify the
#	method to generate. If the named method already exists, it is
#	not replaced.
#
#	The hash specifying each method contains the following keys,
#	which are all requited unless the documentation for the key says
#	otherwise.
#
#	{chain} - An optional code reference which may (but need not)
#	    expand the formatter to produce multiple representations of
#	    the same value. It takes the arguments ( $self, $name,
#	    $value, $arg ) where $self is the invocant, $name is the
#	    name of the formatter method, $value is the value being
#	    formatted, and $arg is the formatter arguments, which have
#	    already had the defaults applied. It returns at least one
#	    argument hash. If it returns more than one, the same value
#	    is formatted using each set of arguments, with the results
#	    made into a single string using join( ' ', ... ). The
#	    returned argument sets MUST keep the same field width for
#	    the same arguments.
#
#	    This is used only for azimuth(), to process the 'bearing'
#	    argument.
#
#	{default} - A hash specifying all legal arguments, and their
#	    default values. You can specify undef to make the argument
#	    legal but give it no value (i.e. to pick up the value from
#	    somewhere else). This hash is passed verbatim to the
#	    _apply_defaults() method.
#
#	{dimension} - A hash specifying the dimension of the value to be
#	    formatted. This must contain a {dimension} key specifying
#	    the name of the dimension, and may contain a {units} value
#	    overriding the default units.
#
#	{fetch} - A code reference which returns the value to be
#	    formatted. It will be passed arguments ( $self, $name, $arg
#	    ), where $self is the invocant, $name is the name of the
#	    formatter method, and $arg is a refernce to the arguments
#	    hash, which has already had _apply_defaults() called on it.
#	    This code is _not_ called if the invocant was initialized
#	    with title => 1.

my %formatter_data = (	# For generating formatters

    almanac	=> {
	default	=> {
	    width	=> 40,
	},
	dimension	=> {
	    dimension	=> 'almanac_pseudo_units',
	},
	fetch		=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $field = $arg->{units} ||= 'description';
	    return $self->_get( data => almanac => $field );
	},
    },

    altitude	=> {
	default	=> {
	    places	=> 1,
	    width	=> 7,
	},
	dimension	=> {
	    dimension	=> 'length',
	},
	fetch		=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $value;
	    if ( my $body = $self->_get_eci( 'body' ) ) {
		$value = ( $body->geodetic() )[2];
	    }
	    return $value;
	},
    },

    angle =>	{
	default	=> {
	    places	=> 1,
	    width	=> 5,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get( data => 'angle' );
	},
    },

    apoapsis => {
	default	=> {
	    as_altitude	=> 1,
	    places	=> 0,
	    width	=> 6,
	},
	dimension	=> {
	    dimension	=> 'length',
	},
	fetch		=> sub {
	    my ( $self, $name, $arg ) = @_;

	    my $body;
	    $body = $self->_get_eci( 'body' )
		and $body->can( $name )
		or return NONE;

	    my $value = $body->$name();

	    if ( $arg->{as_altitude} ) {
		$body->can( 'semimajor' )
		    or return NONE;
		$value -= $body->get( 'semimajor' );
	    }

	    return $value;
	},
    },

#   apogee	=> duplicated from apoapsis, below

    argument_of_perigee	=> {
	default	=> {
	    places	=> 4,
	    width	=> 9,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'argumentofperigee' );
	},
    },

    ascending_node => {
	default	=> {
	    places	=> 2,
	    width	=> 11,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	    units	=> 'right_ascension',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'ascendingnode' );
	},
    },

    azimuth	=> {
	chain	=> sub {
	    my ( $self, $name, $value, $arg ) = @_;
	    $arg->{bearing}
		and $arg->{bearing} =~ m/ \A \d+ \z /sxm
		or $arg->{bearing} = 0;

	    $arg->{bearing} or return $arg;

	    if ( defined $value ) {
		my $ab = { %{ $arg } };	# Shallow clone
		$ab->{width} and $ab->{width} = $ab->{bearing};
		$ab->{units} = 'bearing';
		return ( $arg, $ab );
	    } else {
		$arg->{width}
		    and $arg->{width} += $arg->{bearing} + 1;
		return $arg;
	    }
	},
	default	=> {
	    bearing	=> 0,
	    places	=> 1,
	    width	=> 5,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $station = $self->_get_eci( 'station' )
		or return NONE;
	    return ( $station->azel( $body ) )[0];
	},
    },

    b_star_drag	=> {
	default	=> {
	    places	=> 4,
	    width	=> 11,
	},
	dimension	=> {
	    dimension	=> 'scientific',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'bstardrag' );
	},
    },

    classification	=> {
	default	=> {
	    width	=> 1,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'classification' );
	},
    },

    date	=> {
	default	=> {
	    delta	=> 0,
	    format	=> undef,	# Just to get it looked at
	    gmt		=> undef,
	    places	=> 5,
	    width	=> '',
	},
	dimension	=> {
	    dimension	=> 'time_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    defined( my $value = $self->_get( data => 'time' ) )
		or return NONE;
	    return $value + $arg->{delta};
	},
    },

    declination	=> {
	default	=> {
	    places	=> 1,
	    width	=> 5,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $station = $self->_get_eci( 'station' )
		or return NONE;
	    return ( $self->_get_precessed_coordinates(
		    equatorial => $body, $station ) )[ 1 ];
	},
    },

    eccentricity	=> {
	default	=> {
	    places	=> 5,
	    width	=> 8,
	},
	dimension	=> {
	    dimension	=> 'dimensionless',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'eccentricity' );
	},
    },

    effective_date	=> {
	default	=> {
	    format	=> undef,	# Just to get it looked at
	    gmt		=> undef,
	    places	=> '',
	    width	=> '',
	},
	dimension	=> {
	    dimension	=> 'time_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'effective' );
	},
    },

    element_number	=> {
	default	=> {
	    align_left	=> 0,
	    width	=> 4,
	},
	dimension	=> {
	    dimension	=> 'string',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $value = $self->_get_tle_attr( body => 'elementnumber' );
	    defined $value and $value =~ s/ \A \s+ //sxm;
	    return $value;
	},
    },

    elevation	=> {
	default	=> {
	    places	=> 1,
	    width	=> 5,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $station = $self->_get_eci( 'station' )
		or return NONE;
	    return ( $station->azel( $body ) )[1];
	},
    },

    ephemeris_type	=> {
	default	=> {
	    width	=> 1,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'ephemeristype' );
	},
    },

    epoch	=> {
	default	=> {
	    format	=> undef,	# Just to get it looked at
	    gmt		=> undef,
	    places	=> '',
	    width	=> '',
	},
	dimension	=> {
	    dimension	=> 'time_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'epoch' );
	},
    },

    event	=> {
	default	=> {
	    width	=> 5,
	},
	dimension	=> {
	    dimension	=> 'event_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    defined( my $value = $self->_get( data => $name ) )
		or return NONE;
	    return $value + 0;
	},
    },

    first_derivative	=> {
	default	=> {
	    places	=> 10,
	    width	=> 17,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	    formatter	=> '_format_number_scientific',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'firstderivative' );
	},
    },

    fraction_lit	=> {
	default	=> {
	    places	=> 2,
	    width	=> 4,
	},
	dimension	=> {
	    dimension	=> 'dimensionless',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    $body->can( 'phase' )
		or return NONE;
	    return ( $body->phase() )[1];
	},
    },

#   illumination	=> duplicated from event, below

    inclination	=> {
	default	=> {
	    places	=> 4,
	    width	=> 8,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'inclination' );
	},
    },

    inertial	=> {
	default	=> {
	    width	=> 1,
	},
	dimension	=> {
	    dimension	=> 'integer_pseudo_units',
	},
	fetch		=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    return $body->get( 'inertial' ) ? 1 : 0;
	},
    },

    international	=> {
	default	=> {
	    align_left	=> 1,
	    width	=> 8,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'international' );
	},
    },

    latitude	=> {
	default	=> {
	    places	=> 4,
	    width	=> 8,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    return ( $body->geodetic() )[0];
	},
    },

    longitude	=> {
	default	=> {
	    places	=> 4,
	    width	=> 9,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    return ( $body->geodetic() )[1];
	},
    },

    magnitude	=> {
	default	=> {
	    align_left	=> 0,
	    places	=> 1,
	    width	=> 4,
	},
	dimension	=> {
	    dimension	=> 'number',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get( data => 'magnitude' );
	},
    },

    maidenhead		=> {
	default => {
	    width	=> 6,
	    places	=> undef,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $places = defined $arg->{places} ?
		$arg->{places} :
		$arg->{width} ?
		    floor( $arg->{width} / 2 ) :
		    3;
	    return ( $body->maidenhead( $places ) )[0];
	},
    },

    mean_anomaly	=> {
	default	=> {
	    places	=> 4,
	    width	=> 9,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'meananomaly' );
	},
    },

    mean_motion	=> {
	default	=> {
	    places	=> 10,
	    width	=> 12,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'meanmotion' );
	},
    },

    mma	=> {
	default	=> {
	    width	=> 3,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get( data => 'mma' );
	},
    },

    name	=> {
	default	=> {
	    width	=> 24,	# Per http://celestrak.com/NORAD/documentation/tle-fmt.asp
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $value;
	    defined( $value = $body->get( 'name' ) )
		and return $value;
	    defined $arg->{missing}
		and 'oid' eq $arg->{missing}
		and return $body->get( 'id' );
	    return NONE;
	},
    },

    oid	=> {
	default	=> {
	    width	=> 6,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    defined( my $value = $body->get( 'id' ) )
		or return NONE;
	    not defined $arg->{align_left}
		and $arg->{align_left} = $value !~ m/ \A \d+ \z /sxm;
	    return $value;
	},
    },

    operational	=> {
	default	=> {
	    width	=> 1,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'status' );
	},
    },

#   periapsis	=> duplicated from apoapsis, below

#   perigee	=> duplicated from apoapsis, below

    period	=> {
	default	=> {
	    places	=> 0,
	    width	=> 12,
	},
	dimension	=> {
	    dimension => 'duration',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    $body->can( 'period' )
		or return NONE;
	    return $body->period();
	},
    },

    phase	=> {
	default	=> {
	    places	=> 0,
	    width	=> 4,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    $body->can( 'phase' )
		or return NONE;
	    return ( $body->phase() )[0];
	},
    },

    range	=> {
	default	=> {
	    places	=> 1,
	    width	=> 10,
	},
	dimension	=> {
	    dimension	=> 'length',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $station = $self->_get_eci( 'station' )
		or return NONE;
	    return ( $station->azel( $body ) )[2];
	},
    },

    revolutions_at_epoch	=> {
	default	=> {
	    align_left	=> 0,
	    width	=> 6,
	},
	dimension	=> {
	    dimension	=> 'string',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $value = $self->_get_tle_attr( body => 'revolutionsatepoch' );
	    defined $value and $value =~ s/ \A \s+ //sxm;
	    return $value;
	},
    },

    right_ascension	=> {
	default	=> {
	    places	=> 0,
	    width	=> 8,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	    units	=> 'right_ascension',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    my $station = $self->_get_eci( 'station' )
		or return NONE;
	    return ( $self->_get_precessed_coordinates(
		equatorial => $body, $station ) )[ 0 ];
	},
    },

    second_derivative	=> {
	default	=> {
	    places	=> 10,
	    width	=> 17,
	},
	dimension	=> {
	    dimension	=> 'angle_units',
	    formatter	=> '_format_number_scientific',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'secondderivative' );
	},
    },

    semimajor	=> {
	default	=> {
	    places	=> 0,
	    width	=> 6,
	},
	dimension	=> {
	    dimension	=> 'length',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    my $body = $self->_get_eci( 'body' )
		or return NONE;
	    $body->can( $name )
		or return NONE;
	    return $body->$name();
	},
    },

#   semiminor	=> duplicated from semimajor, below

    status	=> {
	default	=> {
	    width	=> 60,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get( data => 'status' );
	},
    },

#   time	=> duplicated from date, below

    tle	=> {
	default	=> {},
	dimension	=> {
	    dimension	=> 'string',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get_tle_attr( body => 'tle' );
	},
    },

    type	=> {
	default	=> {
	    align_left	=> 1,
	    width	=> 3,
	},
	dimension	=> {
	    dimension	=> 'string_pseudo_units',
	},
	fetch	=> sub {
	    my ( $self, $name, $arg ) = @_;
	    return $self->_get( data => 'type' );
	},
    },

);
foreach my $name ( qw{ apogee periapsis perigee } ) {
    $formatter_data{$name} = $formatter_data{apoapsis};
}
$formatter_data{semiminor} = $formatter_data{semimajor};
$formatter_data{illumination} = $formatter_data{event};
$formatter_data{time} = $formatter_data{date};

sub _fetch {
    my ( $self, $info, $name, $arg ) = @_;

    if ( ! $self->{internal}{time_set} ) {
	if ( defined( my $time = $self->_get( data => 'time' ) ) ) {
	    foreach my $key ( qw{ body station } ) {
		my $obj = $self->_get_eci( $key )
		    or next;
		$obj->universal( $time );
	    }
	}
	$self->{internal}{time_set} = 1;
    }
    return $info->{fetch}->( $self, $name, $arg );
}

while ( my ( $name, $info ) = each %formatter_data ) {
    __PACKAGE__->can( $name ) and next;

    no strict qw{ refs };

    *$name = sub {
	my ( $self, %arg ) = _arguments( @_ );

	$self->_apply_defaults( $name => \%arg, $info->{default} );

	my $value = ( $self->{title} || defined $arg{literal} ) ?
	    NONE :
	    $self->_fetch( $info, $name, \%arg );

	my @rslt;
	foreach my $parm ( $info->{chain} ?
	    $info->{chain}->( $self, $name, $value, \%arg ) :
	    \%arg ) {

	    push @rslt, defined $arg{literal} ?
		$self->_format_string( $arg{literal}, \%arg ) :
		$self->_apply_dimension(
		    $name => $value, $parm, $info->{dimension} );

	}

	return join ' ', @rslt;
    };
}

sub __list_formatters {
    return \%formatter_data;
}

#	Title control

# sub is_valid_title_gravity would normally be here, but in order to
# reduce technical debt it shares a hash with _do_title(), and is placed
# with it, below.

sub more_title_lines {
    my ( $self ) = @_;
    exists $self->{internal}{_title_info}
	or return 1;
    my $more;
    if ( $more = delete $self->{internal}{_title_info}{more} ) {
	$self->{internal}{_title_info}{inx}++
    } else {
	$self->reset_title_lines();
    }
    return $more;
}

sub reset_title_lines {
    my ( $self ) = @_;
    delete $self->{internal}{_title_info};
    return;
}

#	Private methods and subroutines of all sorts.

{

    my @always = qw{ align_left missing title };

    sub _apply_defaults {
	my ( $self, $action, $arg, $dflt ) = @_;

	defined $dflt or $dflt = {};

	defined $arg->{width}
	    or $self->{fixed_width}
	    or $arg->{width} = '';

	if ( defined $arg->{format} && ! defined $arg->{width} ) {
	    $arg->{width} = $self->{time_formatter}->
		format_datetime_width( $arg->{format} );
	}

	APPLY_DEFAULT_LOOP:
	foreach my $key ( keys %{ $dflt }, @always ) {

	    defined $arg->{$key} and next;

	    foreach my $source ( qw{ default internal locale } ) {
		defined( $arg->{$key} = $self->_get( $source, $action,
			$key ) )
		    and next APPLY_DEFAULT_LOOP;
	    }

	    $arg->{$key} = $dflt->{$key};

	}

	defined $arg->{width}
	    or $arg->{width} = '';
	$arg->{width} =~ m/ \D /sxm
	    and $arg->{width} = '';

	return;
    }

}

sub _apply_dimension {
    my ( $self, $name, $value, $arg, $dim ) = @_;

    defined( my $dimension = $dim->{dimension} )
	or $self->warner()->weep( 'No dimension specified' );

    defined( my $units = _dor( $arg->{units}, $dim->{units},
	$self->_get( default => $name, 'units' ),
	$dimensions{$dimension}{default} ) )
	or $self->warner()->weep( "Dimension $dimension undefined" );

    my $hash = $dimensions{$dimension}{define}{$units}
	or $self->{warner}->wail(
	    "Units $units not valid for $dimension" );

    if ( defined $hash->{alias} ) {
	$hash = $dimensions{$dimension}{define}{$hash->{alias}}
	    or $self->warner()->weep( "Undefined alias '$hash->{alias}'" );
	$units = $hash->{alias};
    }

    defined $arg->{align_left}
	or $arg->{align_left} = _dor( $hash->{align_left},
	    $dimensions{$dimension}{align_left} );

    $self->{title}
	and return $self->_do_title( $name, $arg );

    defined $value
	or return $self->_format_undef( undef, $arg );

    defined $hash->{method}
	and do {
	my $method = $hash->{method};
	defined( $value = $self->$method( $value ) )
	    or return $self->_format_undef( undef, $arg );
    };

    defined $hash->{factor}
	and $value *= $hash->{factor};

    defined $hash->{gmt}
	and not defined $arg->{gmt}
	and $arg->{gmt} = $hash->{gmt};

    $arg->{units} = $units;

    defined( my $formatter = _dor( $hash->{formatter},
	    $dim->{formatter},
	    $dimensions{$dimension}{formatter},
	) )
	or $self->warner()->weep( "No formatter for $dimension $units" );

    return $self->$formatter( $value, $arg );
}

sub _arguments {
    my @arg = @_;

    my $obj = shift @arg;
    my $hash = 'HASH' eq ref $arg[-1] ? pop @arg : {};

    my ( @clean, @append );
    foreach my $item ( @arg ) {
	if ( has_method( $item, 'dereference' ) ) {
	    push @append, $item->dereference();
	} else {
	    push @clean, $item;
	}
    }

    @clean % 2 and splice @clean, 0, 0, 'title';

    return ( $obj, %{ $hash }, @clean, @append );
}

sub _attrib_hash {
    my ( $self, $name, @arg ) = @_;
    if ( @arg ) {
	my $value = shift @arg;
	ref $value
	    and 'HASH' eq reftype( $value )
	    or $self->{warner}->wail(
	    "Attribute $name must be a hash reference" );
	$self->{$name} = $value;
	return $self;
    } else {
	return $self->{$name};
    }
}

{

    my %do_title = (
	TITLE_GRAVITY_TOP() => sub {
	    my ( $self, $wrapped, $arg ) = @_;
	    defined $self->{internal}{_title_info}{inx}
		or $self->{internal}{_title_info}{inx} = 0;
	    my $inx = $self->{internal}{_title_info}{inx};
	    $self->{internal}{_title_info}{more} ||=
		defined $wrapped->[$inx + 1];

	    return defined $wrapped->[$inx] ?
		$wrapped->[$inx] :
		$self->_format_string( '', $arg );
	},
	TITLE_GRAVITY_BOTTOM() => sub {
	    my ( $self, $wrapped, $arg ) = @_;
	    defined $self->{internal}{_title_info}{inx}
		or do {
		$self->{internal}{_title_info}{inx} = -1;
		$self->{internal}{_title_info}{max} = 0;
	    };
	    my $size = @{ $wrapped };
	    my $inx = $self->{internal}{_title_info}{inx};
	    if ( $inx < 0 ) {
		$self->{internal}{_title_info}{max} = max(
		    $size,
		    $self->{internal}{_title_info}{max},
		);
	    }
	    my $max = $self->{internal}{_title_info}{max};
	    $self->{internal}{_title_info}{more} ||= $inx + 1 < $max;
	    $inx = $inx - $max + $size;
	    return ( $inx >= 0 && defined $wrapped->[$inx] ) ?
		$wrapped->[$inx] :
		$self->_format_string( '', $arg );
	},
    );

    sub _do_title {
	my ( $self, $name, $arg ) = @_;
	# TODO this looks like a good place to insert localized title code.
	defined $arg->{title}
	    or $arg->{title} = '';
	my $title = $arg->{title};
	my $wrapped = $self->{internal}{$name}{_title}{$title}{$arg->{width}}
	    ||= $self->_do_title_wrap( $name, $arg );

	return $do_title{$self->{title_gravity}}->( $self, $wrapped, $arg );
    }

    sub is_valid_title_gravity {
	my ( @args ) = @_;
	defined( my $value = pop @args )
	    or return 0;
	return $do_title{$value} ? 1 : 0;
    }

}

sub _do_title_wrap {
    my ( $self, $name, $arg ) = @_;
    my $title = $arg->{title};
    $arg->{width} eq ''
	and return [ $title ];
    $arg->{width}
	or return [ '' ];
    local $Text::Wrap::columns = $arg->{width} + 1;
    local $Text::Wrap::huge = 'overflow';
    my $wrap = Text::Wrap::wrap( '', '', $title );
    my @lines = split qr{ \n }sxm, $wrap;
    return [ map { $self->_format_string( $_, $arg ) } @lines ];
}

sub _dor {
    foreach ( @_ ) {
	defined $_ and return $_;
    }
    return $_[-1];
}

sub _get {
    my ( $self, @arg ) = @_;
    my $hash = $self;
    foreach my $key ( @arg ) {
	ref $hash or return NONE;
	defined $key
	    or $self->warner()->weep( "Undefined key" );
	my $ref = reftype( $hash );
	if ( 'HASH' eq $ref ) {
	    $hash = $hash->{$key};
	} elsif ( 'ARRAY' eq $ref ) {
	    $hash = $hash->[$key];
	} else {
	    return NONE;
	}
    }
    return $hash;
}

sub _get_eci {
    my ( $self, @arg ) = @_;
    my $eci = $self->_get( data => @arg );
    embodies( $eci, 'Astro::Coord::ECI' )
	and return $eci;
    return NONE;
}

#	@coords = $self->_get_precessed_coordinates( $method, $body,
#			$station );
#
#	This method fetches the coordinates of the given body which are
#	specified by the given method. These must be inertial, and are
#	precessed if desired. If the body is not defined, nothing is
#	returned. If the station is passed, the coordinates are relative
#	to it; if it is undefined, nothing is returned.

sub _get_precessed_coordinates {
    my ( $self, $method, $body, $station ) = @_;

    foreach my $thing ( $body, $station ) {
	embodies( $thing, 'Astro::Coord::ECI' )
	    or return;
    }

    # TODO need to set station time from body? I think not now, but
    # Astro::App::Satpass2::FormatValue needed this.

    if ( my $equinox = $self->{desired_equinox_dynamical} ) {
	foreach my $thing ( $body, $station ) {
	    $thing = $thing->clone()->precess_dynamical( $equinox );
	}
    }

    return $station->$method( $body );
}

sub _get_tle {
    my ( $self, @arg ) = @_;
    my $tle = $self->_get( data => @arg );
    embodies( $tle, 'Astro::Coord::ECI::TLE' )
	and return $tle;
    return NONE;
}

sub _get_tle_attr {
    my ( $self, @arg ) = @_;
    my $attr = pop @arg;
    my $tle = $self->_get( data => @arg );
    embodies( $tle, 'Astro::Coord::ECI::TLE' )
	and $tle->attribute( $attr )
	or return NONE;
    return $tle->get( $attr );
}

#	$string = $self->_format_*( $value, \%arg );
#
#	These methods take the value and turn it into a string.
#	Recognized arguments are:
#	    {places} => decimal places, ignored if not a non-negative
#		number;
#	    {width} => field width, ignored if not a non-negative
#		number;

{
    my @bearings = (
	[ qw{ N E S W } ],
	[ qw{ N NE E SE S SW W NW } ],
	[ qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW } ],
    );

    sub _format_bearing {
	my ( $self, $value, $arg ) = @_;
	defined $value
	    or goto &_format_undef;

	my $table;

	foreach my $source ( qw{ default locale } ) {
	    $table = $self->_get( $source => bearing => 'table' )
		and last;
	}

	$table ||= \@bearings;

	$arg->{bearing}
	    or $arg->{bearing} = ( $arg->{width} || 2 );
	$arg->{width}
	    and $arg->{bearing} > $arg->{width}
	    and $arg->{bearing} = $arg->{width};

	my $inx = min( $arg->{bearing} || 2, scalar @{ $table } ) - 1;
	my $tags = $table->[$inx];
	my $bins = @{ $tags };
	$inx = floor ($value / TWOPI * $bins + .5) % $bins;
	return $self->_format_string( $tags->[$inx], $arg );
    }
}

sub _format_duration {
    my ( $self, $value, $arg ) = @_;

    defined $arg->{align_left}
	or $arg->{align_left} = 0;

    defined $value
	or goto &_format_undef;

    my $secs = floor ($value + .5);
    my $mins = floor ($secs / 60);
    $secs %= 60;
    my $hrs = floor ($mins / 60);
    $mins %= 60;
    my $days = floor ($hrs / 24);
    $hrs %= 24;

    my $buffer;
    if ($days > 0) {
	$buffer = sprintf '%d %02d:%02d:%02d', $days, $hrs, $mins, $secs;
    } else {
	$buffer = sprintf '%02d:%02d:%02d', $hrs, $mins, $secs;
    }

    '' eq $arg->{width}
	and return $buffer;

    length $buffer <= $arg->{width}
	or $self->{overflow}
	or return '*' x $arg->{width};

    $arg->{width} - length $buffer
	or return $buffer;

    return $self->_format_string( $buffer, $arg );
}

{
    my @evnt;
    foreach (
	[&PASS_EVENT_NONE => ''],
	[&PASS_EVENT_SHADOWED => 'shdw'],
	[&PASS_EVENT_LIT => 'lit'],
	[&PASS_EVENT_DAY => 'day'],
	[&PASS_EVENT_RISE => 'rise'],
	[&PASS_EVENT_MAX => 'max'],
	[&PASS_EVENT_SET => 'set'],
	[&PASS_EVENT_APPULSE => 'apls'],
    ) {
	$evnt[$_->[0]] = $_->[1];
    }

    sub _format_event {
	my ( $self, $value, $arg ) = @_;

	defined $value
	    and $value !~ m/ \D /sxm
	    or goto &_format_undef;

	my $table;
	if ( 'string' ne $arg->{units} ) {
	    foreach my $source ( qw{ default locale } ) {
		$table = $self->_get( $source => event => 'table' )
		    and last;
	    }
	}
	$table ||= \@evnt;

	return $self->_format_string( $table->[$value] || '', $arg );
    }

}

sub _format_integer {
    my ( $self, $value, $arg ) = @_;
    defined $value
	or goto &_format_undef;

    $arg->{width}
	and $arg->{width} =~ m/ \A \d+ \z /sxm
	or return sprintf '%d', $value;

    my $buffer = sprintf '%*d', $arg->{width}, $value;

    length $buffer <= $arg->{width}
	or $self->{overflow}
	or return '*' x $arg->{width};

    return $buffer;
}

sub _format_lower_case {
    my ( $self, $value, $arg ) = @_;
    defined $value
	or goto &_format_undef;

    return $self->_format_string( lc $value, $arg );
}

sub _format_number {
    my ( $self, $value, $arg ) = @_;
    defined $value
	and $value ne ''
	or goto &_format_undef;

    my $width = ( $arg->{width} && $arg->{width} =~ m/ \A \d+ \z /sxm )
	? $arg->{width} : '';
    my $tplt = "%$width";
    defined $arg->{places}
	and $arg->{places} =~ m/ \A \d+ \z /sxm
	and $tplt .= ".$arg->{places}";

    '%' eq $tplt
	and return "$value";

    my $buffer = sprintf $tplt . 'f', $value;

    # The following line is because sprintf '%.1f', 0.04 produces
    # '-0.0'. This may not be a bug, given what 'perldoc -f sprintf'
    # says, but it sure looks like a wart to me.
    $buffer =~ s/ \A ( \s* ) - ( 0* [.]? 0* \s* ) \z /$1 $2/smx;

    $width or return $buffer;

    if ($width && length $buffer > $width && $width >= 7) {
	$arg->{places} = $width - 7;
	return $self->_format_number_scientific( $value, $arg );
    }

    length $buffer <= $width
	or $self->{overflow}
	or return '*' x $width;

    return $buffer;
}

sub _format_number_scientific {
    my ( $self, $value, $arg ) = @_;
    defined $value
	and $value ne ''
	or goto &_format_undef;

    my $width = ( $arg->{width} && $arg->{width} =~ m/ \A \d+ \z /sxm )
	? $arg->{width} : '';
    my $tplt = "%$width";
    defined $arg->{places}
	and $arg->{places} =~ m/ \A \d+ \z /sxm
	and $tplt .= ".$arg->{places}";
    $tplt .= 'e';

    my $buffer = sprintf $tplt, $value;
    $buffer =~ s/ e ( [-+]? ) 0 (\d\d) \z /e$1$2/smx	# Normalize
	and $width
	and $width > length $buffer
	and $buffer = ' ' . $buffer;	# Preserve width after normalize

    $width
	or return $buffer;

    length $buffer <= $width
	or $self->{overflow}
	or return '*' x $width;

    return $buffer;
}

{
    my @table = (
	[6.1 => 'new'], [83.9 => 'waxing crescent'],
	[96.1 => 'first quarter'], [173.9 => 'waxing gibbous'],
	[186.1 => 'full'], [263.9 => 'waning gibbous'],
	[276.1 => 'last quarter'], [353.9 => 'waning crescent'],
    );

    sub _format_phase {
	my ( $self, $value, $arg ) = @_;
	defined $value
	    or goto &_format_undef;
	my $angle = rad2deg( $value );

	my $table;
	foreach my $source ( qw{ default locale } ) {
	    $table = $self->_get( $source => phase => 'table' )
		and last;
	}
	$table ||= \@table;
	foreach my $entry ( @{ $table } ) {
	    $entry->[0] > $angle or next;
	    return $self->_format_string( $entry->[1], $arg );
	}
	return $self->_format_string( $table[0][1], $arg );
    }
}

sub _format_right_ascension {
    my ( $self, $value, $arg ) = @_;
    defined $value
	or goto &_format_undef;
    my $sec = $value / PI * 12;
    my $hr = floor($sec);
    $sec = ($sec - $hr) * 60;
    my $min = floor($sec);
    $sec = ($sec - $min) * 60;
    my ( $ps, $wid );
    if ( defined $arg->{places} && $arg->{places} =~ m/ \A \d+ \z /sxm )
    {
	$ps = ".$arg->{places}";
	$wid = $arg->{places} ? 3 + $arg->{places} : 2;
    } else {
	$ps = '';
	$wid = 2;
    }
    defined $arg->{align_left}
	or $arg->{align_left} = 0;
    return $self->_format_string(
	sprintf( "%02d:%02d:%0$wid${ps}f", $hr, $min, $sec ), $arg );
}

sub _format_string {
    my ( $self, $value, $arg ) = @_;

    defined $value
	or goto &_format_undef;

    defined $arg->{width}
	and $arg->{width} =~ m/ \A \d+ \z /sxm
	or return "$value";

    my $left = defined $arg->{align_left} ? $arg->{align_left} : 1;
    $left = $left ? '-' : '';

    my $buffer = sprintf "%$left*s", $arg->{width}, $value;

    length $buffer <= $arg->{width}
	or $self->{overflow}
	or return substr $buffer, 0, $arg->{width};

    return $buffer;
}

sub _format_time {
    my ( $self, $value, $arg ) = @_;
    defined $value
	or goto &_format_undef;

    my $fmtr = $self->{time_formatter};
    my $fmt = $arg->{format};
    defined $fmt
	or $self->warner()->weep( "No time format" );

    my $buffer = $fmtr->format_datetime(
	$fmt, $value, $arg->{gmt} );
    return $self->_format_string( $buffer, $arg );
}

sub _format_title_case {
    my ( $self, $value, $arg ) = @_;
    defined $value
	or goto &_format_undef;

##  $value = join '', map { ucfirst lc $_ }
##	split qr{ (?<= [^[:alpha:]] ) (?= [[:alpha:]] ) }sxm, $value;
    $value =~ s{ (?: \A | (?<= \s ) ) ( [[:alpha:]] \S* ) }
	{ ucfirst lc $1 }sxmge;
    return $self->_format_string( $value, $arg );
}

sub _format_undef {
    my ( $self, $value, $arg ) = @_;

    $self->{title}
	and defined $arg->{title}
	and return $self->_format_string( $arg->{title}, $arg );

    defined $arg->{missing}
	and return $self->_format_string( $arg->{missing}, $arg );

    defined $arg->{width}
	and $arg->{width} =~ m/ \A \d+ \z /sxm
	and $arg->{width}
	or return '';

    return ' ' x $arg->{width};
}

sub _format_upper_case {
    my ( $self, $value, $arg ) = @_;
    defined $value
	or goto &_format_undef;

    return $self->_format_string( uc $value, $arg );
}

sub _julian_day {
    my ( $self, $value ) = @_;
    return julianday( $value );
}

{

    my %date_format = (
	date	=> [ 'date_format' ],
	effective_date	=> [ 'date_format', 'time_format' ],
	epoch	=> [ 'date_format', 'time_format' ],
	time	=> [ 'time_format' ],
    );

    sub _make_date_format {
	my ( $self, $action ) = @_;

	$date_format{$action}
	    or return;

	return join ' ', grep { defined $_ && '' ne $_ }
	    map { $self->{$_} } @{ $date_format{$action} };

    }

    sub _uses_date_format {
	return ( keys %date_format );
    }

}

{

    my %fmt = map { $_ => 1 } qw{ date_format time_format };

    sub _set_time_format {
	my ($self, $name, $data) = @_;
	$fmt{$name}
	    or $self->warner()->weep(
		"'$name' invalid for _set_time_format()" );
	my $fmtr = $self->{time_formatter};
	$self->{$name} = $data;
	foreach my $action ( $self->_uses_date_format() ) {
	    my $fmt = $self->_make_date_format( $action );
	    my $width = $fmtr->format_datetime_width( $fmt );
	    $self->{internal}{$action}{width} = $width;
	    $self->{internal}{$action}{format} = $fmt;
	}
	return $self;
    }
}

sub _subtract_epoch {
    my ( $self, $value ) = @_;
    my $epoch = $self->_get_tle_attr( body => 'epoch' );
    defined $epoch
	or return $epoch;
    return $value - $epoch;
}

sub _variant {
    my ( $self, $variant ) = @_;

    my $data;
    if ( defined $variant ) {
	$data = 'HASH' eq ref $variant ? $variant : {	# Shallow clone
	    %{ $self->_get( data => $variant ) || {} }
	};
	foreach my $key ( qw{ station time } ) {
	    $data->{$key} = $self->_get( data => $key );
	}
    } else {
	$data = { %{ $self->_get( 'data' ) } };	# Shallow clone
    }

    return $self->clone( data => $data );
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::FormatValue - Format Astro::App::Satpass2 output as text.

=head1 SYNOPSIS

 use strict;
 use warnings;
 
 use Astro::App::Satpass2::FormatValue;
 use Astro::Coord::ECI;
 use Astro::Coord::ECI::Moon;
 use Astro::Coord::ECI::Sun;
 use Astro::Coord::ECI::Utils qw{ deg2rad };
 
 my $time = time();
 my $moon = Astro::Coord::ECI::Moon->universal( $time );
 my $sun = Astro::Coord::ECI::Sun->universal( $time );
 my $station = Astro::Coord::ECI->new(
     name => 'White House',
 )->geodetic(
     deg2rad(38.8987),  # latitude
     deg2rad(-77.0377), # longitude
     17 / 1000);	# height above sea level, Km
 
 foreach my $body ( $sun, $moon ) {
     my $fmt = Astro::App::Satpass2::FormatValue->new(
	 data => {
	     body => $body,
	     station => $station,
	     time => $time,
	 } );
     print join( ' ', $fmt->date(), $fmt->time(),
	 $fmt->name( width => 10 ),
	 $fmt->azimuth( bearing => 2 ),
	 $fmt->elevation() ), "\n";
 }

=head1 NOTICE

This is alpha code. It has been tested on my box, but has limited
exposure to the wild. Also, the public interface may not be completely
stable, and may change if needed to support
L<Astro::App::Satpass2|Astro::App::Satpass2>. I will try to document any
incompatible changes.

=head1 DETAILS

This class is intended to take care of the details of performing field
formatting for an
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format> object, and
was actually written to format data for C<Template-Toolkit>. It is
B<not> intended to be used outside one of these, though I suppose it
could be.

This class is intended to be initialized with a hash containing data in
known locations. Not coincidentally, the hash corresponds to the hashes
produced by methods of interest in
L<Astro::Coord::ECI|Astro::Coord::ECI> and its subclasses.

=head1 METHODS

This class supports the following public methods.

=head2 Instantiator

=head3 new

 $fmt = Astro::App::Satpass2::FormatValue->new();

This static method instantiates a new value formatter. It takes as
arguments name/value pairs.

Because this class has no mutators you must give it all the information
it needs to do its job when you instantiate it.

The following argument names are recognized:

=over

=item data

This argument is a hash containing the data to be displayed. The keys in
the hash are accessed by the various transformation and formatter
methods. This argument is technically optional, but unless you have
specified C<< title => 1 >> (which see) you will not get a very useful
object if you omit it.

If this hash contains a {time} key, the
L<Astro::Coord::ECI|Astro::Coord::ECI> objects in the C<{body}> and
C<{station}> keys (if any) will be set to that value.

=item date_format

This argument is the string that the C<time_formatter> will use to
format dates. It is assumed that this format will not produce any time
information, though this is not enforced. The default is whatever the
default date format is for the C<time_formatter>.

=item default

This optional argument is a hash used to override the defaults for the
various formatters. The keys are formatter names, and the values of
those keys are hashes containing the specific argument defaults.

=item desired_equinox_dynamical

This optional argument is the desired equinox in dynamical time. If
specified as a non-zero Perl time, inertial coordinates will be
precessed to this equinox. The default is C<0>.

=item fixed_width

This optional argument specifies whether or not fixed-width fields are
to be produced. If true (the default) numeric default widths are applied
where needed. If false the default width is C<''>, which is the
convention for variable-width fields.

=item local_coordinates

This optional argument provides the implementation of the
L<local_coord()|/local_coord> formatter method. You can provide either a
code reference of one of the following strings:

 az_rng --------- Azimuth and range;
 azel ----------- Elevation and azimuth;
 azel_rng ------- Elevation, azimuth and range;
 equatorial ----- Right ascension and declination;
 equatorial_rng - Right ascension, declination, and range.

The code reference will be called with the same arguments as were used
for C<local_coord()>, including the invocant.

The default is C<azel_rng>.

=item overflow

If this optional argument is true (in the Perl sense, i.e. anything but
C<undef>, C<0>, or C<''>) fields will be allowed to overflow their
widths. If false (the default) too-long strings will be truncated on the
right, and too-long numeric fields will generally be C<*>-filled.

=item time_format

This argument is the string that the C<time_formatter> will use to
format times of day. It is assumed that this format will not produce any
date information, though this is not enforced. The default is whatever
the default time format is for the C<time_formatter>.

=item time_formatter

This argument is either the name or an instance of an
L<Astro::App::Satpass2::FormatTime|Astro::App::Satpass2::FormatTime>
subclass. This object is used to format times. The default is
C<Astro::App::Satpass2::FormatTime>.

=item title

If this argument is true, the formatter methods will produce titles
rather than values. In this case the C<data> hash is unused. The default
is false.

=item title_gravity

This argument specifies the value for the
L<title_gravity|/title_gravity> attribute. See the
L<title_gravity()|/title_gravity> documentation for full details.

=item warner

This optional argument must be an instance of
L<Astro::App::Satpass2::Warner|Astro::App::Satpass2::Warner>. If not
provided, a new C<Warner> object will be instantiated.

=back

=head2 Accessors

These are kept to a minimum, since the main purpose of the object is to
provide formatting.

=head3 body

 $fmt->body();

This accessor returns the contents of the C<{body}> key of the original
hash passed to the C<data> argument when the object was instantiated.
It returns a false value if the C<{body}> key exists but is not an
C<Astro::Coord::ECI|Astro::Coord::ECI>, or if the key does not exist.

This accessor exists because the
L<Astro::App::Satpass2::Format::Template|Astro::App::Satpass2::Format::Template>
L<list()|Astro::App::Satpass2::Format::Template/list> method needs to
look at the body to decide what to display.

=head2 Mutators

These also are kept to a minimum.

If called without an argument, all mutators act as accessors, and return
the value of the attribute.

If called with an argument, they change the attribute (or croak if the
new value is invalid), and return their invocant.

=head3 fixed_width

 $fmt->fixed_width( 0 );
 say 'Fixed-width formatting is ',
    $fmt->fixed_width() ? 'on' : 'off';

If false, this boolean attribute causes all widths not explicitly
specified to default to C<''>, which is the convention for
non-fixed-width fields. It can also be set via the C<fixed_width>
argument to C<new()>. The default is C<1> (i.e. C<true>).

If called without an argument, this method acts as an accessor,
returning the current value.

This boolean attribute has a mutator because C<Template-Toolkit> needs
to modify it, and C<Template-Toolkit>-style named arguments can't be
used for C<clone()> because of the way the interface is designed.

=head3 title_gravity

 $fmt->title_gravity( 'bottom' );
 say 'Title gravity is ', $fmt->title_gravity();

This attribute specifies how multiline titles are aligned. The possible
values are C<'top'> or C<'bottom'>. The manifest constants
C<TITLE_GRAVITY_TOP> and C<TITLE_GRAVITY_BOTTOM> are defined to
represent these, but they are not exported.

If you specify C<'bottom'>, you get an extra empty line above the
titles. This is an annoying behavior necessitated by the fact that the
first line of the first title has to be inserted into the output before
we know how many lines are needed to print all the titles. So we force
an extra line with blanks to get the process rolling.

This hack means that you do not want to use C<'bottom'> unless you
intend to actually display all the lines of each title.

The default is C<'top'>.

This attribute has a mutator because C<Template-Toolkit> needs to modify
it.

=head2 Transformations

Some of the methods of interest produce hashes that contain
supplementary data. For example, the output of the
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> C<pass()> method may
contain an <{appulse}> key describing the appulsed body. These methods
give access to such data. If the requested data exists, they typically
return an C<Astro::App::Satpass2::FormatValue> object, though they may
return a reference to an array of them, or to an iterator function. If
the requested data do not exist, they typically return C<undef>.

=head3 appulse

 my $apls = $fmt->appulse();

This method returns an C<Astro::App::Satpass2::FormatValue> object based
on the invocant, with the data coming from the C<{appulse}> key of the
original object's data, augmented with the C<{station}> and C<{time}>
of the original data.

=head3 bodies

 my $array_ref = $fmt->bodies();

For reasons that seemed logical at the time, the
L<Astro::App::Satpass2|Astro::App::Satpass2>
L<position()|Astro::App::Satpass2/position> method produces a hash
containing the time, some other relevant data, and a C<{bodies}> key
which contains a reference to an array of all the relevant bodies.

This method extracts an array of more-normally-structured
C<Astro::App::Satpass2::FormatValue> objects which give access to the
original bodies.

=head3 center

 $center = $fmt->center();

This method returns an C<Astro::App::Satpass2::FormatValue> object based
on the invocant, with the data coming from the C<{center}> key of the
original object's data, augmented with the C<{station}> and C<{time}>
of the original data.

=head3 clone

 my $clone = $fmt->( %arg );

This method performs a shallow clone the invocant. That is to say, the
clone is a separate object, but it shares all contained objects and
references with the original object. If any arguments are passed, they
are used to initialize the cloned object, instead of the corresponding
data from the invocant.

=head3 earth

 my $earth = $fmt->earth();

This method returns an C<Astro::App::Satpass2::FormatValue> object based
on the invocant, with its C<{station}> key set to the center of the
Earth.

=head3 events

 foreach my $event ( @{ $fmt->events() || [] } ) {
     ... do something with the event ...
 }

This method returns a reference to an array of
C<Astro::App::Satpass2::FormatValue> objects manufactured out of the
contents of the C<{events}> key of the invocant's data.

=head3 reflections

 $array_ref = $fmt->reflections();

This method returns a reference to an array of
C<Astro::App::Satpass2::FormatValue> objects which represent the results
of calling C<< $fmt->body()->reflection() >>, passing it the contents of
the C<{station}> and C<{time}> keys. It will return C<undef> if the body
does not support this method, or if it is below the horizon or not lit.

=head3 station

 my $station = $fmt->station();

This method returns an object identical to the invocant, with the
exception that the C<{body}> and C<{station}> contents are exchanged.
With this,

 $fmt->station()->latitude()

(e.g.) gets you the latitude of the observing station, whereas

 $fmt->latitude()

would get you the latitude of the orbiting body.

=head2 Formatters

Each formatter converts the value of a specific key or keys in the
C<data> hash to text. Typically the conversion is to a fixed-width field
unless the C<width> argument is non-numeric. If the underlying item does
not exist, a user-specified string will be returned instead, or spaces
if no string was specified.

All the formatter arguments are passed by name: that is, as name/value
pairs.  Because of the idiosyncrasies of C<Template-Toolkit>, or because
of the author's lack of experience with it, some weirdness has been
introduced into what would have been a straightforward signature:

* C<Template-Toolkit> recognizes special named-argument syntax, and
presents the arguments as a hash appended to the argument list.
Therefore, if the formatters see a hash as the last argument, that hash
will be expanded into a list and prepended to the argument list. Because
C<Template-Toolkit> does B<not> supply an empty hash if none of its
named arguments are seen, you can not pass a hash as the last argument.

* C<Template-Toolkit> seems to have a strong preference for dealing with
arrays as references. But array references are not flattened when passed
as arguments. If the caller wants an array reference flattened, it must
be made into an instance of
L<Astro::App::Satpass2::Wrap::Array|Astro::App::Satpass2::Wrap::Array>.
This is really (I think and hope!) only a problem for whoever writes the
code reference that gets passed to the C<local_coordinates> argument of
C<new()> (i.e. me).

The summary of all this is that arguments are taken in the following
order:

=over

=item 1) arguments from the final hash, if any

=item 2) everything else except

=item 3)
L<Astro::App::Satpass2::Wrap::Array|Astro::App::Satpass2::Wrap::Array>
objects, which are expanded and put last.

=back

Since arguments are passed by name, you can specify the same argument
more than once. If this happens, the C<last> specification of the
argument is the one taken.

One additional complication: for convenience in overriding default
titles, if the list of arguments from item C<(2)> above ('everything
else') has an odd number of elements, C<'title'> is prepended. The net
result of this is that if C<$title> is an
C<Astro::App::Satpass2::FormatValue> object with C<< title => 1 >>,
something like $title->azimuth( '' ) will produce an empty field of the
proper width.

The following arguments are accepted by all formatters:

=over

=item align_left

This argument specifies that the given value be left-aligned in its
field. This defaults to true for text items, and false for numeric
items.

=item literal

This argument specifies text to be displayed in place of the underlying
datum.

=item missing

This argument specifies the text to be filled in if the underlying datum
is not available. It defaults to spaces.

=item title

This argument specifies the text to be used as the title of the
formatter -- that is, the text which is displayed when the formatter is
initialized with C<< title => 1 >>. The default is appropriate to the
formatter.

=back

=head3 almanac

 print $fmt->almanac();

The C<almanac_hash()> method provided by some subclasses of
C<Astro::Coord::ECI> returns a hash which includes an C<{almanac}> key,
which contains various items describing the almanac entry. This method
provides access to the contents of the C<{almanac}> key.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<almanac_pseudo_units|/almanac_pseudo_units> units are accepted;
anything else will result in an exception. The default is
C<description>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<40>.

=back

=head3 altitude

 print $fmt->altitude();

This method formats the altitude of the C<{body}> object above sea
level.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<7>.

=back

=head3 angle

 print $fmt->angle();

This method formats the C<{angle}> value, which typically represents an
appulse angle.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<5>.

=back

=head3 apoapsis

 print $fmt->apoapsis();

This method formats the apoapsis of the C<{body}> object's orbit.

In addition to the standard arguments, it takes the following:

=over

=item as_altitude

If this boolean argument is true (in the Perl sense) the value is given
as altitude above the Earth's surface. If false, the value is given as
distance from the Earth's center. The default is C<1>.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 apogee

 print $fmt->apogee();

This method formats the apogee of the C<{body}> object's orbit. Yes,
this is the same as the apoapsis.

In addition to the standard arguments, it takes the following:

=over

=item as_altitude

If this boolean argument is true (in the Perl sense) the value is given
as altitude above the Earth's surface. If false, the value is given as
distance from the Earth's center. The default is C<1>.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 argument_of_perigee

 print $fmt->argument_of_perigee();

This method formats the argument of perigee from the C<{body}> object's
TLE data.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<4>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<9>.

=back

=head3 ascending_node

 print $fmt->ascending_node();

This method formats the ascending node from the C<{body}> object's TLE
data.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<2>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<right_ascension>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<11>.

=back

=head3 azimuth

 print $fmt->azimuth();

This method formats the azimuth of the C<{body}> object as seen from the
C<{station}> object.

In addition to the standard arguments, it takes the following:

=over

=item bearing

This argument specifies the size of the bearing information to append to
the azimuth. If zero or any non-numeric value, no bearing information
will be appended. The default is C<0>.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<5>.

=back

=head3 b_star_drag

 print $fmt->b_star_drag();

This method formats the B* drag from the C<{body}> object's TLE data..

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<4>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<11>.

=back

=head3 classification

 print $fmt->classification();

This method formats the classification of the C<{body}> object's TLE
data. This will usually be 'U', for 'unclassified'.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<1>.

=back

=head3 date

 print $fmt->date();

This method formats the C<{time}> value using the C<date_format>
template. This is intended to produce the date, without time
information.

In addition to the standard arguments, it takes the following:

=over

=item delta

This argument specifies a number of seconds to add to the value before
it is formatted. The default is C<0>.

=item format

This argument specifies the format to use for formatting the value. The
default is ...

=item gmt

If this boolean argument is true, the value is formatted in GMT,
regardless of how the time formatter is set up. If false, it is
formatted according to the C<time_formatter>'s zone setting. The default
is the C<time_formatter>'s C<gmt> setting.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<5>.

=item units

This argument specifies the units of the field. Any
L<time_units|/time_units> units are accepted; anything else will result
in an exception. The default is C<local>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<>.

=back

=head3 declination

 print $fmt->declination();

This method formats the declination of the C<{body}> object as seen from
the C<{station}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<5>.

=back

=head3 eccentricity

 print $fmt->eccentricity();

This method formats the eccentricity of the C<{body}> object's orbit.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<5>.

=item units

This argument specifies the units of the field. Any
L<dimensionless|/dimensionless> units are accepted; anything else will
result in an exception. The default is C<unity>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<8>.

=back

=head3 effective_date

 print $fmt->effective_date();

This method formats the effective date of the C<{body}> object's TLE
data.

In addition to the standard arguments, it takes the following:

=over

=item format

This argument specifies the format to use for formatting the value. The
default is ...

=item gmt

If this boolean argument is true, the value is formatted in GMT,
regardless of how the time formatter is set up. If false, it is
formatted according to the C<time_formatter>'s zone setting. The default
is the C<time_formatter>'s C<gmt> setting.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<>.

=item units

This argument specifies the units of the field. Any
L<time_units|/time_units> units are accepted; anything else will result
in an exception. The default is C<local>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<>.

=back

=head3 element_number

 print $fmt->element_number();

This method formats the number of the C<{body}> object's TLE data. This
is usually incremented each time a new set is published.

In addition to the standard arguments, it takes the following:

=over

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<4>.

=back

=head3 elevation

 print $fmt->elevation();

This method formats the elevation of the C<{body}> object above the
horizon as seen from the C<{station}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<5>.

=back

=head3 ephemeris_type

 print $fmt->ephemeris_type();

This method formats the ephemeris type of the C<{body}> object's TLE
data. This is supposed to say which model is to be used to calculate the
object's position, but in practice is typically 0 or blank.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<1>.

=back

=head3 epoch

 print $fmt->epoch();

This method formats the epoch from the C<{body}> object's TLE data.

In addition to the standard arguments, it takes the following:

=over

=item format

This argument specifies the format to use for formatting the value. The
default is ...

=item gmt

If this boolean argument is true, the value is formatted in GMT,
regardless of how the time formatter is set up. If false, it is
formatted according to the C<time_formatter>'s zone setting. The default
is the C<time_formatter>'s C<gmt> setting.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<>.

=item units

This argument specifies the units of the field. Any
L<time_units|/time_units> units are accepted; anything else will result
in an exception. The default is C<local>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<>.

=back

=head3 event

 print $fmt->event();

This method formats the contents of C<{event}>, which generally comes
from an L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> C<pass()>
calculation.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<event_pseudo_units|/event_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<localized>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<5>.

=back

=head3 first_derivative

 print $fmt->first_derivative();

This method formats the first derivative from the C<{body}> object's TLE
data. The units are actually angle per minute squared, but this
formatter treats them as angle. That is, it will give you output in
radians per minute squared if you so desire, but not in radians per
second squared.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<10>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<17>.

=back

=head3 fraction_lit

 print $fmt->fraction_lit();

This method formats the fraction of the C<{body}> object which is lit.
This is only available if that object supports the C<phase()> method.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<2>.

=item units

This argument specifies the units of the field. Any
L<dimensionless|/dimensionless> units are accepted; anything else will
result in an exception. The default is C<unity>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<4>.

=back

=head3 illumination

 print $fmt->illumination();

This method formats the contents of C<{illumination}>, which generally
comes from an L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> C<pass()>
calculation.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<event_pseudo_units|/event_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<localized>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<5>.

=back

=head3 inclination

 print $fmt->inclination();

This method formats the orbital inclination from the C<{body}> object's
TLE data.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<4>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<8>.

=back

=head3 inertial

 print $fmt->inertial()

This method formats the C<inertial> attribute of the C<{body}> object,
as C<0> if the attribute is false, or C<1> if it is true.

In addition to the standard arguments, it takes the following:

=over

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<1>.

=back

=head3 international

 print $fmt->international();

This method formats the international launch designator from the
C<{body}> object's TLE data.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<8>.

=back

=head3 latitude

 print $fmt->latitude();

This method formats the latitude of the C<{body}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<4>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<8>.

=back

=head3 local_coord

 print $fmt->local_coord();

This method formats the local coordinates as specified by the
C<local_coordinates> argument when the object was initialized. It has no
arguments of its own, but will pass through any arguments given to the
methods it calls. You can pass arguments selectively by specifying them
as a hash - for example
 $fmt->local_coord(
     title => {
	 azimuth => 'azimuth',
	 elevation => 'elevation',
     },
 );

Scalar arguments will be passed to all called methods, except for
C<append>, which will be appended to the entire formatted value.


=head3 longitude

 print $fmt->longitude();

This method formats the longitude of the C<{body}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<4>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<9>.

=back

=head3 magnitude

 print $fmt->magnitude();

This method formats the contents of C<{magnitude}>, which generally
represent the magnitude of an Iridium flare.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<4>.

=back


=head3 maidenhead

 print $fmt->maidenhead();

This method formats the Maidenhead Grid Locator position of the
C<{body}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the precision of the position, as the number of
grid levels to provide. The default is half the width, truncated to an
integer. If no specific width is provided, the default is C<3>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 mean_anomaly

 print $fmt->mean_anomaly();

This method formats the mean anomaly from the C<{body}> object's TLE
data.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<4>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<9>.

=back

=head3 mean_motion

 print $fmt->mean_motion();

This method formats the mean motion from the C<{body}> object's TLE
data. The units are actually angle per minute, but this formatter treats
them as angle. That is, it will give you output in radians per minute if
you so desire, but not in radians per second.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<10>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<12>.

=back

=head3 mma

 print $fmt->mma();

This method formats the contents of C<{mma}>, which generally indicates
the flaring antenna for an Iridium flare.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<3>.

=back

=head3 name

 print $fmt->name();

This method formats the name of the C<{body}> object. If the name is
missing and you specify C<< missing => 'oid' >> the OID will be
displayed instead.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<24>.

=back

=head3 oid

 print $fmt->oid();

This method formats the OID of the C<{body}> object.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 operational

 print $fmt->operational();

This method formats the operational status of the C<{body}> object. This
is generally only available if the object represents an Iridium
satellite.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<1>.

=back

=head3 periapsis

 print $fmt->periapsis();

This method formats the periapsis of the C<{body}> object's orbit.

In addition to the standard arguments, it takes the following:

=over

=item as_altitude

If this boolean argument is true (in the Perl sense) the value is given
as altitude above the Earth's surface. If false, the value is given as
distance from the Earth's center. The default is C<1>.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 perigee

 print $fmt->perigee();

This method formats the perigee of the C<{body}> object's orbit. Yes,
this is the same as the periapsis.

In addition to the standard arguments, it takes the following:

=over

=item as_altitude

If this boolean argument is true (in the Perl sense) the value is given
as altitude above the Earth's surface. If false, the value is given as
distance from the Earth's center. The default is C<1>.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 period

 print $fmt->period();

This method formats the period of the C<{body}> object's orbit.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any
L<duration|/duration> units are accepted; anything else will result in
an exception. The default is C<composite>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<12>.

=back

=head3 phase

 print $fmt->phase();

This method formats the phase of the C<{body}> object. This is only
available if that object supports the C<phase()> method.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<4>.

=back

=head3 range

 print $fmt->range();

This method formats the distance of the C<{body}> object from the
C<{station}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<1>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<10>.

=back

=head3 revolutions_at_epoch

 print $fmt->revolutions_at_epoch();

This method formats the revolutions at epoch from the C<{body}> object's
TLE data.

In addition to the standard arguments, it takes the following:

=over

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 right_ascension

 print $fmt->right_ascension();

This method formats the right ascension of the C<{body}> object as seen
from the C<{station}> object.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<right_ascension>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<8>.

=back

=head3 second_derivative

 print $fmt->second_derivative();

This method formats the second derivative from the C<{body}> object's
TLE data. The units are actually angle per minute cubed, but this
formatter treats them as angle. That is, it will give you output in
radians per minute cubed if you so desire, but not in radians per second
cubed.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<10>.

=item units

This argument specifies the units of the field. Any
L<angle_units|/angle_units> units are accepted; anything else will
result in an exception. The default is C<degrees>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<17>.

=back

=head3 semimajor

 print $fmt->semimajor();

This method formats the semimajor axis of the C<{body}> object's orbit,
calculated using that object's C<semimajor()> method.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 semiminor

 print $fmt->semiminor();

This method formats the semiminor axis of the C<{body}> object's orbit,
calculated using that object's C<semiminor()> method.

In addition to the standard arguments, it takes the following:

=over

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<0>.

=item units

This argument specifies the units of the field. Any L<length|/length>
units are accepted; anything else will result in an exception. The
default is C<kilometers>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<6>.

=back

=head3 status

 print $fmt->status();

This method formats the contents of C<{status}>, which usually come from
the L<Astro::App::Satpass2|Astro::App::Satpass2> C<position()> method.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<60>.

=back

=head3 time

 print $fmt->time();

This method formats the C<{time}> value using the C<time_format>
template. This is intended to produce the time, without date
information.

In addition to the standard arguments, it takes the following:

=over

=item delta

This argument specifies a number of seconds to add to the value before
it is formatted. The default is C<0>.

=item format

This argument specifies the format to use for formatting the value. The
default is ...

=item gmt

If this boolean argument is true, the value is formatted in GMT,
regardless of how the time formatter is set up. If false, it is
formatted according to the C<time_formatter>'s zone setting. The default
is the C<time_formatter>'s C<gmt> setting.

=item places

This argument specifies the number of decimal places in the field.
Specify a non-numeric value if you do not wish to enforce a specific
number of decimal places. The default is C<5>.

=item units

This argument specifies the units of the field. Any
L<time_units|/time_units> units are accepted; anything else will result
in an exception. The default is C<local>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<>.

=back

=head3 tle

 print $fmt->tle();

This method formats the TLE data from the C<{body}> object. Unlike the
other formatters, which produce a fixed-width string, this formatter
produces a block of text, whatever is contained by the C<{body}>
object's C<tle> attribute if any.


=head3 type

 print $fmt->type();

This method formats the contents of C<{type}>. This usually comes from
the C<flare()> method, and says whether the flare occurred in the am,
day, or pm.

In addition to the standard arguments, it takes the following:

=over

=item units

This argument specifies the units of the field. Any
L<string_pseudo_units|/string_pseudo_units> units are accepted; anything
else will result in an exception. The default is C<string>.

=item width

This argument specifies the width of the field. Specify a non-numeric
value if you do not wish to enforce a specific width. The default is
C<3>.

=back

=head2 Title Control

Titles can consist of multiple lines, wrapped with
L<Text::Wrap|Text::Wrap>. The display is 'top-heavy', meaning that the
column titles are justified to the top.

Nothing special needs to be done to get the first line, other than to
initialize the object C<< title => 1 >>. To get all the lines, you need
to use a C<while> loop, calling C<more_title_lines()> in the test. When
this returns false you B<must> exit the loop, otherwise you loop
infinitely.

=head3 is_valid_title_gravity

Returns a true value if the argument is a valid title gravity setting,
and a false value otherwise. Can be called as a static method, or even a
subroutine, though it is not exported.

=head3 more_title_lines

 my $fmt = Astro::App::Satpass2::Format->new( title => 1 );
 while ( $fmt->more_title_lines() ) {
     print join( ' ',
         $fmt->azimuth( title => 'Azimuth of object',
             bearing => 2 ),
         $fmt->elevation( title => 'Elevation of object' ),
     ), "\n";
 }

This method returns true until there are no more lines of title to
display. It also increments the internal line counter causing the next
line of title to be displayed.

=head3 reset_title_lines

 my $fmt->reset_title_lines();

This method resets the title line logic to its original state. You will
not normally need to call this unless you want to display titles more
than once B<and> you have previously exited a C<more_title_lines()> loop
prematurely.

=head1 UNITS

Most of the format effectors format a quantity that is measured in some
physical units; that is, kilometers, feet, seconds, or whatever. The
C<units=> argument can be used to specify the displayed units for the
field. This mechanism has been subverted in a couple cases to select
among the representations of items that have more than one
representation, even when the different representations are not,
strictly speaking, physical units.

Each format effector that has physical units has an associated
dimension, which determines which units are valid for it. The dimension
specifies units, synonyms for canonical units, and the default units,
though the individual format effector can have its own default (e.g.
L<right_ascension|/right_ascension>).

Typically the default field widths and decimal places are appropriate
for the default units, so if you specify different units you should
probably specify the field width and decimal places as well.

The dimensions are:

=head2 almanac_pseudo_units

The first example is a case where the units mechanism was subverted to
select among alternate representations, rather than to convert between
physical units. The possible pseudo-units are:

C<description> = the text description of the event;

C<event> = the generic name of the event (e.g. C<'horizon'> for rise or
set);

C<detail> = the numeric event detail, whose meaning depends on the event
(e.g. for C<'horizon'>, C<1> is rise and C<0> is set).

The default is C<'description'>.

=head2 angle_units

This dimension represents a geometric angle. The possible units are:

C<bearing> = a compass bearing;

C<decimal> = a synonym for C<degrees>;

C<degrees> = angle in decimal degrees;

C<radians> = angle in radians;

C<phase> = name of phase ('new', 'waxing crescent', and so on);

C<right_ascension> = angle in hours, minutes, and seconds of right
ascension.

When the angle units are specified as C<< units => 'bearing' >>, the
precision of the bearing is specified by the C<bearing> argument. That
is, C<< bearing => 1 >> gets you the cardinal points (C<N>, C<E>, C<S>
and C<W>), C<< bearing => 2 >> gets you the semi-cardinal points, and
similarly for C<< bearing => 3 >>. If C<bearing> is not specified it
defaults to the same value as the C<width> argument, or C<2> if no width
is specified.  The net result is that you need to specify the C<bearing>
argument if you specify C<< width => '' >> and do not like the default
of C<2>. Yes, I could have equivocated on C<places>, but this seemed
more straight forward.

The default is normally degrees, though this is overridden for
L<right_ascension|/right_ascension>.

=head2 dimensionless

A few displayed quantities are simply numbers, having no associated
physical dimension. These can be specified as:

C<percent> = display as a percentage value, without the trailing '%';

C<unity> = display unaltered.

The default is C<unity>.

=head2 duration

This dimension represents a span of time, such as an orbital period. The
units are:

C<composite> = days hours:minutes:seconds.fraction;

C<days> = duration in days and fractions of days;

C<hours> = duration in hours and fractions of hours;

C<minutes> = duration in minutes and fractions of minutes;

C<seconds> = duration in seconds and fractions of seconds.

The default is C<composite>.

=head2 event_pseudo_units

Like L<almanac_pseudo_units|/almanac_pseudo_units>, this is not a
physical dimension, just a way of selecting different representations.
The units are:

C<integer> = event number (see
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE>);

C<localized> = localized event name;

C<string> = unlocalized event name.

The default is C<localized>.

=head2 length

This dimension represents lengths and distances. The possible units are:

C<feet> = US/British feet;

C<ft> = synonym for 'feet';

C<kilometers> = standard kilometers;

C<km> = synonym for kilometers;

C<meters> = standard meters;

C<m> = synonym for 'meters';

C<miles> = statute miles.

The default is C<kilometers>.

=head2 string_pseudo_units

Like L<almanac_pseudo_units|/almanac_pseudo_units>, this is not a
physical dimension, just a way of selecting different representations.
The units are:

C<lower_case> = all lower case;

C<string> = the unmodified string;

C<title_case> = lower case, with initial letters upper case,

C<upper_case> = all upper case.

=head2 time_units

This dimension represents time. The possible units are:

C<days_since_epoch> = the number of days and fractions thereof since the
epoch of the body (undefined if there is no epoch);

C<gmt> = GMT;

C<julian> = Julian day (implies GMT -- you may want to set the C<places>
argument for this);

C<local> = local time (actually, whatever zone the time formatter is set
to);

C<universal> = an alias for C<gmt>;

C<z> = an alias for C<gmt>;

C<zulu> = an alias for C<gmt>.

The default is C<local>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
