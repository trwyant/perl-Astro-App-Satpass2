package App::Satpass2::Format::Classic;

use strict;
use warnings;

use base qw{ App::Satpass2::Format };

use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::Utils qw{
    deg2rad embodies julianday PI rad2deg TWOPI
};
use Carp;
use Params::Util 0.25 qw{ _INSTANCE };
use POSIX qw{ floor };
use Text::Abbrev;
use Text::Wrap qw{ wrap };

our $VERSION = '0.000_01';

my %mutator = (
    almanac	=> \&_set_almanac,
    angle	=> \&_set_literal,
    appulse	=> \&_set_appulse,
    body	=> \&_set_eci,
    center	=> \&_set_center,
    event	=> \&_set_literal,
    illumination	=> \&_set_literal,
    magnitude	=> \&_set_literal,
    mma		=> \&_set_literal,
    phenomenon	=> \&_set_phenomenon,
    station	=> \&_set_eci,
    status	=> \&_set_literal,
    time	=> \&_set_literal,
    type	=> \&_set_literal,
);

#	The %units hash defines physical dimensions and the allowable
#	units for each. The keys of this hash are the names of physical
#	dimensions (e.g. 'length', 'mass', 'volume', and so on), and the
#	values are hashes defining the dimension.
#
#	Each dimension definition hash must have the following keys:
#
#	default => the name of the default units for the dimension. This
#	value must appear as a key in the factor hash (see below). This
#	default can be overridden by a given format effector.
#
#	factor => a hash defining the legal units for the dimension. The
#	keys are the names of the units (e.g. for length 'kilometers',
#	'meters', 'miles', 'feet'). The value can be any of a number of
#	things defining the units.
#
#	If the factor value is a scalar, it is the conversion factor
#	between the internal units and the displayed units,
#
#	If the factor value is a scalar reference, the key is a synonym
#	for the units represented by the value. The value must appear in
#	the same factor hash.
#
#	If the factor value is a code reference, it specifies an output
#	formatting routine to be used in lieu of the one specified by
#	the format effector. The conversion factor will be 1.
#
#	If the factor value is a hash reference, it means that we need
#	to do something more complicated than just apply a conversion
#	factor. The following hash keys may be specified:
#
#	    append => a literal string to append to the output, reducing
#		the available field width (if any) by the length of the
#		string;
#	    factor => the conversion factor;
#	    formatter => a code reference to the output formatting
#		routine to be used in lieu of the one specified by the
#		format effector.
#
#	Any other value will be placed verbatim in the $opt hash
#	reference passed to the output formatting routine.

my %units = (
    almanac_dimension => {
	default		=> 'description',
	factor	=> {
	    description => \&_format_almanac_description,
	    event	=> \&_format_almanac_event,
	    detail	=> \&_format_almanac_detail,
	},
    },
    angle => {
	default		=> 'degrees',
	factor	=> {
	    bearing	=> \&_format_bearing,
	    decimal	=> \'degrees',
	    degrees	=> 90/atan2(1, 0),
	    radians	=> 1,
	    phase	=> \&_format_phase,
	    rightascension => \&_format_right_ascension,
	},
    },
    date => {
	default		=> 'local',
	factor	=> {
	    local	=> {
		factor	=> 1,
		formatter => \&_format_time,
		gmt	=> 0,
	    },
	    gmt		=> {
		factor	=> 1,
		formatter => \&_format_time,
		gmt	=> 1,
	    },
	    julian	=> \&_format_julian_date,
	    universal	=> \'gmt',
	    zulu	=> \'gmt',
	    days_since_epoch => {
		factor	=> 1/86400,
		formatter => \&_format_time_since_epoch,
	    },
	},
    },
    dimensionless => {
	default		=> 'unity',
	factor	=> {
	    percent	=> {
		append	=> '%',
		factor	=> 100,
	    },
	    unity	=> 1,
	},
    },
    duration => {
	default		=> 'composite',
	factor => {
	    composite	=> 1,
	    seconds	=> {
		factor	=> 1,
		formatter	=> \&_format_number,
	    },
	    minutes	=> {
		factor	=> 1/60,
		formatter	=> \&_format_number,
	    },
	    hours	=> {
		factor	=> 1/3600,
		formatter	=> \&_format_number,
	    },
	    days	=> {
		factor	=> 1/86400,
		formatter	=> \&_format_number,
	    },
	},
    },
    length => {
	default		=> 'kilometers',
	factor	=> {
	    kilometers	=> 1,
	    km		=> \'kilometers',
	    meters	=> 1000,
	    m		=> \'meters',
	    miles	=> 0.62137119,
	    feet	=> 3280.8399,
	    foot	=> \'feet',
	    ft		=> \'feet',
	}
    },
);

#	The %template hash defines the individual format effectors. The
#	hash keys are the format effector names, and the values are
#	references to hashes that define the format effector.
#
#	The following keys are defined for each format effector:
#
#	allow => a reference to a hash keyed by the names of
#	    non-standard arguments to allow. The values must be true.
#
#	fetch => a subroutine to fetch the data. The calling sequence is
#	    ($self, $body, $station, $options), where the $options hash
#	    is derived from the arguments passed in the template.
#
#	forbid => a reference to a hash keyed by the names of standard
#	    arguments to forbid. The values must be true.
#
#	formatter => the subroutine to format the data.
#
#	literal => if true, the value is computed at the time the format
#	    is compiled, and inserted into the format as-is. Should only
#	    be set for white space.
#
#	meta_fetch => subroutine to generate the fetch subroutine. If
#	    this is specified, the fetch key will be ignored. The
#	    calling sequence is ($options), where the $options hash is
#	    the same as for the fetch routine.
#
#	places => the default number of decimal places, where
#	    applicable; can be omitted if not.
#
#	title => the default column title.
#
#	units => the units of the data, if applicable; must be omitted
#	    if not. The entry must appear in the %units hash.
#
#	unit_default => the default units of the data, if not those
#	    specified in the relevant %units entry for the 'units' key.
#
#	width => the default width of the field.

my %template = (
    almanac => {
	fetch => sub {return $_[0]{almanac}},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	},
	formatter => undef,	# Overridden by the units
	title => 'almanac',
	units => 'almanac_dimension',
	width => 40,
    },
    altitude => {	# altitude (was 'a')
	fetch => sub {
	    $_[1] or return;
	    return ($_[1]->geodetic())[2];
	},
	formatter => \&_format_number,
	places => 1,
	title => 'altitude',
	units => 'length',
	width => 7,
    },
    angle => {	# angle (was 'A')
	forbid => {
	    center => 1,
	    station => 1,
	},
	formatter => \&_format_number,
	meta_fetch => sub {
	    return $_[0]{appulse} ?
		sub {$_[0]{appulse}{angle}} :
		sub {$_[0]{angle}};
	},
	places => 1,
	title => 'angle',
	units => 'angle',
	width => 4,
    },
    apoapsis => {	# apoapsis
	allow => {
	    earth => 1,
	},
	formatter => \&_format_number,
	meta_fetch => sub {
	    $_[0]{earth} ?
	    sub {
		return ($_[1] && $_[1]->can('apoapsis')) ?
		$_[1]->apoapsis() : undef
	    } :
	    sub {
		return ($_[1] && $_[1]->can('apoapsis')) ?
		($_[1]->apoapsis() - $_[1]->get('semimajor')) : undef
	    }
	},
	places => 0,
	title => 'apoapsis',
	units => 'length',
	width => 6,
    },
    # apogee cloned from apoapsis, below.
    argumentofperigee => {	# Argument of perigee
	fetch => sub {return _fetch_tle_attr($_[1], 'argumentofperigee')},
	formatter => \&_format_number,
	places => 4,
	title => 'argument of perigee',
	units => 'angle',
	width => 9,
    },
    ascendingnode => {	# Ascending node
	fetch => sub {return _fetch_tle_attr($_[1], 'ascendingnode')},
	formatter => \&_format_number,
	places => 2,
	title => 'ascending node',
	units => 'angle',
	unit_default => 'rightascension',
	width => 11,
    },
    azimuth	=> {	# azimuth of object (was 'Z')
	allow => {
	    bearing => 1,
	},
	fetch => sub {
	    ($_[1] && $_[2]) or return;
	    return ($_[2]->azel($_[1]))[0];
	},
	formatter => \&_format_azimuth,
	places => 1,
	title => 'azimuth',
	units => 'angle',
	width => 5,
    },
    bstardrag => {	# B star drag term
	fetch => sub {return _fetch_tle_attr($_[1], 'bstardrag')},
	formatter => \&_format_number_scientific,
	places => 4,
	title => 'B* drag',
	width => 11,
    },
    classification => {	# Classification
	fetch => sub {return _fetch_tle_attr($_[1], 'classification')},
	formatter => \&_format_string,
	title => '',
	width => 1,
    },
    date	=> {	# Date (was 'j')
	fetch => sub {return $_[0]{time}},
	forbid => {
	    center => 1,
	    station => 1,
	},
	format => [qw{date_format}],
	formatter => \&_format_time,
	title => 'date',
	units => 'date',
	width => 11,
    },
    declination => {
		# declination ('earth' as seen from earth)
		# was 'D' from station, or 'd' from center of Earth
	allow => {
	    earth => 1,
	},
	formatter => \&_format_number,
	meta_fetch => sub {
	    return $_[0]{earth} ?
####		sub {$_[1] ? ($_[1]->equatorial())[1] : undef} :
####		sub {($_[1] && $_[2]) ? ($_[2]->equatorial($_[1]))[1] :
####		    undef};
		sub { ( $_[0]->_fetch_precessed_coordinates(
			    equatorial => $_[1] ) )[1] } :
		sub { ( $_[0]->_fetch_precessed_coordinates(
			    equatorial => $_[1], $_[2] ) )[1] };
	},
	places => 1,
	title => 'declination',
	units => 'angle',
	width => 5,
    },
    eccentricity => {	# Eccentricity of orbit
	fetch => sub {return _fetch_tle_attr($_[1], 'eccentricity')},
	formatter => \&_format_number,
	places => 5,
	title => 'eccentricity',
	width => 8,
    },
    eci_x	=> {
	fetch => sub {
####	    $_[1] or return;
####	    return ($_[1]->eci())[0]
	    return ( $_[0]->_fetch_precessed_coordinates( eci => $_[1] )
		)[0];
	},
	formatter => \&_format_number,
	places => 1,
	title => 'eci x',
	units => 'length',
	width => 10,
    },
    eci_y	=> {
	fetch => sub {
####	    $_[1] or return;
####	    return ($_[1]->eci())[1]
	    return ( $_[0]->_fetch_precessed_coordinates( eci => $_[1] )
		)[1];
	},
	formatter => \&_format_number,
	places => 1,
	title => 'eci y',
	units => 'length',
	width => 10,
    },
    eci_z	=> {
	fetch => sub {
	    # Z-axis does not precess.
	    $_[1] or return;
	    return ($_[1]->eci())[2]
	},
	formatter => \&_format_number,
	places => 1,
	title => 'eci z',
	units => 'length',
	width => 10,
    },
    effective	=> {	# effective date
	fetch => sub {return _fetch_tle_attr($_[1], 'effective')},
	format => [qw{date_format time_format}],
	formatter => \&_format_time,
	title => 'effective date',
	units => 'date',
	width => 20,
    },
    elementnumber => {	# Element set number
	fetch => sub {return _fetch_tle_attr($_[1], 'elementnumber')},
	formatter => \&_format_integer,
	title => 'element set number',
	width => 4,
    },
    elevation	=> {	# elevation of object (was 'E')
	fetch => sub {
	    ($_[1] && $_[2]) or return;
	    return ($_[2]->azel($_[1]))[1];
	},
	formatter => \&_format_number,
	places => 1,
	title => 'elevation',
	units => 'angle',
	width => 5,
    },
    ephemeristype => {	# Ephemeris type
	fetch => sub {return _fetch_tle_attr($_[1], 'ephemeristype')},
	formatter => \&_format_integer,
	title => 'ephemeris type',
	width => 1,
    },
    epoch	=> {	# epoch (was 'p')
	fetch => sub {return _fetch_tle_attr($_[1], 'epoch')},
	forbid_units => {
	    days_since_epoch => 1,
	},
	format => [qw{date_format time_format}],
	formatter => \&_format_time,
	title => 'epoch',
	units => 'date',
	width => 20,
    },
    event	=> {	# event (was 'v')
	fetch => sub {return $_[0]{event}},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	},
	formatter => \&_format_event,
	title => 'event',
	width => 5,
    },
    firstderivative => {	# First derivative of mean motion
	fetch => sub {return _fetch_tle_attr($_[1], 'firstderivative')},
	formatter => \&_format_number_scientific,
	places => 10,
	title => 'first derivative of mean motion',
	units => 'angle',
	width => 17,
    },
    fraction_lit => {	# Fraction of object illuminated (% with '#') (was 'L')
	fetch => sub {
	    $_[1] or return;
	    $_[1]->can ('phase') or return;
	    return ($_[1]->phase())[1];
	},
	formatter => \&_format_number,
	places => 2,
	title => 'fraction lit',
	units => 'dimensionless',
	width => 4,
    },
    id	=> {	# id of object. (was 'i')
	fetch => sub {
	    $_[1] or return;
	    return $_[1]->get('id')
	},
	formatter => \&_format_string,
	title => 'oid',
	width => 6,
    },
    illumination => {	# Lighting / illumination (lit/shdw/day) (was 'l')
	fetch => sub {return $_[0]{illumination}},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	},
	formatter => \&_format_event,
	title => 'illumination',
	width => 5,
    },
    inclination => {	# Inclination of orbit
	fetch => sub {return _fetch_tle_attr($_[1], 'inclination')},
	formatter => \&_format_number,
	places => 4,
	title => 'inclination',
	units => 'angle',
	width => 8,
    },
    international => {	# International launch designator
	fetch => sub {return _fetch_tle_attr($_[1], 'international')},
	formatter => \&_format_string,
	title => 'international launch designator',
	width => 8,
    },
    latitude => {	# latitude (was 't')
	fetch => sub {
	    $_[1] or return;
	    return ($_[1]->geodetic())[0];
	},
	formatter => \&_format_number,
	places => 4,
	title => 'latitude',
	units => 'angle',
	width => 8,
    },
    longitude => {	# longitude (was 'g')
	fetch => sub {
	    $_[1] or return;
	    return ($_[1]->geodetic())[1];
	},
	formatter => \&_format_number,
	places => 4,
	title => 'longitude',
	units => 'angle',
	width => 9,
    },
    magnitude	=> {	# magnitude of object. (was 'm')
	formatter => \&_format_number,
	forbid => {
	    appulse => 1,
	    station => 1,
	},
	meta_fetch => sub {
	    $_[0]{center} ? sub {$_[0]{center}{magnitude}} :
	    sub {$_[0]{magnitude}}
	},
	places => 1,
	title => 'magnitude',
	width => 4,
    },
    meananomaly => {	# Mean anomaly
	fetch => sub {return _fetch_tle_attr($_[1], 'meananomaly')},
	formatter => \&_format_number,
	places => 4,
	title => 'mean anomaly',
	units => 'angle',
	width => 9,
    },
    meanmotion => {	# Mean motion
	fetch => sub {return _fetch_tle_attr($_[1], 'meanmotion')},
	formatter => \&_format_number,
	places => 10,
	title => 'mean motion',
	units => 'angle',
	width => 12,
    },
    mma	=> {	# MMA or other flare source (was 'M')
	fetch => sub {return $_[0]{mma}},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	},
	formatter => \&_format_string,
	title => 'mma',
	width => 3,
    },
    n => {	# newline
	fetch => sub { return "\n" },
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	    title => 1,
	},
	formatter => \&_format_string,
	literal => 1,
	title => '',
	width => 1,
    },
    name	=> {	# name of object. (was 'n')
	formatter => \&_format_string,
	meta_fetch => sub {
	    (lc ($_[0]{missing} || '') eq 'oid') ?
	    sub {
		$_[1] or return;
		return $_[1]->get('name') || $_[1]->get('id') || '';
	    } :
	    sub {
		$_[1] or return;
		return $_[1]->get('name');
	    }
	},
	title => 'name',
	width => 24,	# Per http://celestrak.com/NORAD/documentation/tle-fmt.asp
    },
    operational	=> {	# 'status' attribute of Iridium object.
	fetch => sub {
	    $_[1] or return;
	    $_[1]->attribute('status') or return;
	    return $_[1]->get('status');
	},
	formatter => \&_format_string,
	width => 1,
    },
    percent	=> {	# literal percent (was '%')
	fetch => sub {return '%'},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	    title => 1,
	},
	formatter => \&_format_string,
	title => '',
	width => 1,
    },
    periapsis => {	# periapsis
	allow => {
	    earth => 1,
	},
	formatter => \&_format_number,
	meta_fetch => sub {
	    $_[0]{earth} ?
	    sub {
		return ($_[1] && $_[1]->can('periapsis')) ?
		$_[1]->periapsis() : undef
	    } :
	    sub {
		return ($_[1] && $_[1]->can('periapsis')) ?
		($_[1]->periapsis() - $_[1]->get('semimajor')) : undef
	    }
	},
	places => 0,
	title => 'periapsis',
	units => 'length',
	width => 6,
    },
    # perigee cloned from periapsis, below
    period	=> {	# period (was 'Y', and 'y' before that)
	fetch => sub {
	    $_[1] or return;
	    $_[1]->can('period') or return;
	    return $_[1]->period();
	},
	formatter => \&_format_period,
	title => 'period',
	units => 'duration',
	width => 12,
    },
    phase	=> {	# phase of object, string with '#' (was 'z')
	fetch => sub {
	    $_[1] or return;
	    $_[1]->can ('phase') or return;
	    return ($_[1]->phase())[0];
	},
	formatter => \&_format_number,
	places => 0,
	title => 'phase',
	units => 'angle',
	width => 4,
    },
    provider => {
	fetch => sub {
	    return $_[0]->provider();
	},
	formatter => \&_format_string,
	width => 0,
    },
    range	=> {	# range of object (was 'r')
	fetch => sub {
	    ($_[1] && $_[2]) or return;
	    return ($_[2]->azel($_[1]))[2];
	},
	formatter => \&_format_number,
	places => 1,
	title => 'range',
	units => 'length',
	width => 10,
    },
    revolutionsatepoch => {	# Revolutions at epoch
	fetch => sub {return _fetch_tle_attr($_[1], 'revolutionsatepoch')},
	formatter => \&_format_integer,
	title => 'revolutions at epoch',
	width => 6,
    },
    right_ascension => {
		# right ascension ('earth' from center of Earth)
		# was 'C' from station, or 'c' from center of Earth
	allow => {
	    earth => 1,
	},
	formatter => \&_format_number,
	meta_fetch => sub {
	    $_[0]{earth} ?
####	    sub {$_[1] ? ($_[1]->equatorial())[0] : undef} :
####	    sub {($_[1] && $_[2]) ? ($_[2]->equatorial($_[1]))[0] : undef}
	    sub { ( $_[0]->_fetch_precessed_coordinates( equatorial =>
			$_[1] ) )[0] } :
	    sub { ( $_[0]->_fetch_precessed_coordinates( equatorial =>
			$_[1], $_[2] ) )[0] }
	},
	places => 0,
	title => 'right ascension',
	unit_default => 'rightascension',
	units => 'angle',
	width => 8,
    },
    secondderivative => {	# Second derivative of mean motion
	fetch => sub {return _fetch_tle_attr($_[1], 'secondderivative')},
	formatter => \&_format_number_scientific,
	places => 10,
	title => 'second derivative of mean motion',
	units => 'angle',
	width => 17,
    },
    semimajor => {	# semimajor axis
	fetch => sub {
	    return ($_[1] && $_[1]->can ('semimajor')) ?
		$_[1]->semimajor() :
		undef;
	},
	formatter => \&_format_number,
	places => 0,
	title => 'semimajor axis',
	units => 'length',
	width => 6,
    },
    semiminor => {	# semiminor axis
	fetch => sub {
	    return ($_[1] && $_[1]->can ('semiminor')) ?
		$_[1]->semiminor() :
		undef;
	},
	formatter => \&_format_number,
	places => 0,
	title => 'semiminor axis',
	units => 'length',
	width => 6,
    },
    space => {	# spaces
	fetch => sub {return ''},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	    title => 1,
	},
	formatter => \&_format_string,
	literal => 1,
	title => '',
	width => 1,
    },
    status => {	# status (was 's')
	fetch => sub {return $_[0]{status}},
	forbid => {
	    appulse => 1,
	    center => 1,
	    station => 1,
	},
	formatter => \&_format_string,
	title => 'status',
	width => 60,
    },
    time	=> {	# time of day. (was 'h')
	fetch => sub {return $_[0]{time}},
	forbid => {
	    center => 1,
	    station => 1,
	},
	format => [qw{time_format}],
	formatter => \&_format_time,
	title => 'time',
	units => 'date',
	width => 8,
    },
    tle => {	# Raw tle data
	fetch => sub {return _fetch_tle_attr($_[1], 'tle')},
	formatter => \&_format_text_block,
	title => '',
    },
);

# Clone %apogee and %perigee from %apoapsis and %periapsis,
# respectively.
$template{apogee} = _clone_template('apoapsis', title => 'apogee');
$template{perigee} = _clone_template('periapsis', title => 'perigee');

# Explicitly forbid the 'units' argument in format effectors that have
# no associated units.
foreach my $fmtr ( keys %template ) {
    exists $template{$fmtr}{units}
	or $template{forbid}{units} = 1;
}

my %template_title_modifier = (
    appulse => 'appulse %s',
    center => 'center %s',
    station => 'station %s',
);

my %format_macro_definitions = (
    az_rng	=> '%azimuth($*,bearing) %range($*);',
    azel	=> '%elevation($*) %azimuth($*,bearing);',
    azel_rng	=> '%elevation($*) %azimuth($*,bearing) %range($*);',
    equatorial	=> '%right_ascension($*) %declination($*);',
    equatorial_rng => '%right_ascension($*) %declination($*) %range($*);',
    local_coord	=> '%azel_rng($*);',
);

my %format_template_definitions = (
    almanac	=> '%date %time %*almanac%n',
    date_time	=> '%date %time%n',
    flare => '%-date %-time %-12name %local_coord %magnitude %5angle(appulse,title=degrees from sun,missing=night) %azimuth(center,bearing) %6.1range(center)%n',
    list_inertial => '%id %-name %-epoch %-period%n',
    list_fixed => '%id %name %latitude %longitude %altitude%n',
    location	=> <<'EOD',
Location: %*name%n
          Latitude %*.4latitude, longitude %*.4longitude, height %*.0altitude(units=meters) m%n
EOD
    pass =>
    '%time %local_coord %latitude %longitude %altitude %-illumination %-event%n',
    pass_oid => '%n%id; - %-*name;  %date%n',
    pass_appulse =>
    '%time %local_coord(appulse)       %angle(appulse) degrees from %-name(appulse)%n',
    phase => '%date %time %8name %phase(title=phase angle) %-16phase(units=phase) %.0fraction_lit(units=percent)%n',
    position	=>
	'%16name(missing=oid) %local_coord %epoch %illumination%n',
    position_nomma	=> '%30space;%-status%n',
    position_status	=> '%30space;MMA %mma %-status%n',
    position_flare	=>
	'%30space;MMA %mma mirror angle %angle magnitude %magnitude%n',
    tle	=> '%tle',
    tle_celestia => <<'EOD',
%n
# Keplerian elements for %*name%n
# Generated by %*provider%n
# Epoch: %*epoch UT%n
%n
Modify "%*name" "Sol/Earth" {%n
    EllipticalOrbit {%n
	Epoch  %*.*epoch(units=julian)%n
	Period  %*.*period(units=days)%n
	SemiMajorAxis  %*.*semimajor%n
	Eccentricity  %*.*eccentricity%n
	Inclination  %*.*inclination%n
	AscendingNode  %*.*ascendingnode(units=degrees)%n
	ArgOfPericenter  %*.*argumentofperigee%n
	MeanAnomaly  %*.*meananomaly%n
    }%n
    UniformRotation {%n
	Inclination  %*.*inclination%n
	MeridianAngle  90%n
	AscendingNode  %*.*ascendingnode(units=degrees)%n
    }%n
}%n
EOD
    tle_verbose => <<'EOD',
NORAD ID: %*id%n
    Name: %*name%n
    International launch designator: %*international%n
    Epoch of data: %#epoch GMT%n
    Effective date of data: %*effective(missing=<none>) GMT%n
    Classification status: %classification%n
    Mean motion: %*.*meanmotion degrees/minute%n
    First derivative of motion: %*.*firstderivative degrees/minute squared%n
    Second derivative of motion: %*.*secondderivative degrees/minute cubed%n
    B Star drag term: %*bstardrag%n
    Ephemeris type: %ephemeristype%n
    Inclination of orbit: %*.*inclination degrees%n
    Right ascension of ascending node: %*.*ascendingnode%n
    Eccentricity: %eccentricity%n
    Argument of perigee: %*.*argumentofperigee degrees from ascending node%n
    Mean anomaly: %*.*meananomaly; degrees%n
    Element set number: %*elementnumber%n
    Revolutions at epoch: %*revolutionsatepoch%n
    Period (derived): %*period%n
    Semimajor axis (derived): %*.*semimajor kilometers%n
    Perigee altitude (derived): %*.*perigee kilometers%n
    Apogee altitude (derived): %*.*apoapsis kilometers%n
EOD
);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new( @args );

    $self->_set_time_format_initial();

    $self->{macro} = {};	# Macro definitions
    $self->{template} = {};	# Templates

    while ( my ( $name, $def ) = each %format_macro_definitions ) {
	$self->macro( $name => $def );
    }
    while ( my ( $name, $def ) = each %format_template_definitions ) {
	$self->template( $name => $def );
    }
    return $self;
}

sub almanac {
    my ( $self, $almanac_hash ) = @_;
    if ( defined $almanac_hash ) {
	return $self->_set( phenomenon => $almanac_hash )
	    ->_format_execute( format => 'almanac' );
    } else {
	return '';
    }
}

sub config {
    my ( $self, %args ) = @_;
    my @data = $self->SUPER::config( %args );
    foreach my $action ( sort keys %{ $self->{formatter} } ) {
	my @mod = ( format_effector => $action );
	my $hash = $self->{formatter}{$action};
	foreach my $name ( sort keys %{ $hash } ) {
	    push @mod, $name, $hash->{$name};
	}
	push @data, \@mod;
    }
    foreach my $name ( sort keys %{ $self->{macro} } ) {
	next if $args{changes} &&
	    defined $self->{macro}{$name} &&
	    $self->{macro}{$name} eq $format_macro_definitions{$name};
	push @data, [ macro => $name, $self->{macro}{$name} ];
    }
    foreach my $name ( sort keys %{ $self->{template} } ) {
	# The regex is ad-hocery to prevent the unsupported celestia
	# stuff from being included unless necessary.
	next if ( $args{changes} || $name =~ m/ celestia /smx ) &&
	    defined $self->{template}{$name} &&
	    $self->{template}{$name} eq $format_template_definitions{$name};
	push @data, [ template => $name, $self->{template}{$name} ];
    }
    return @data;
}

sub date_format {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->_set_time_format( date_format => @args );
	return $self->SUPER::date_format( @args );
    } else {
	return $self->SUPER::date_format();
    }
}

sub effectors_used {
    my ( $self, $name ) = @_;
    my $used = $self->_template_fetcher( $name )->{used} || {};
    return wantarray ? (%$used) : {%$used};
}

#	$value = _fetch_tle_attr($obj, $name)
#
#	Check to see if the object represents an Astro::Coord::ECI::TLE
#	object. If so, return the named attribute; if not return undef.

sub _fetch_tle_attr {
    my ($obj, $name) = @_;
    return embodies($obj, 'Astro::Coord::ECI::TLE') ?
	$obj->get($name) :
	undef;
}

sub flare {
    my ( $self, $flare ) = @_;
    if ( defined $flare ) {
	$flare->{type} eq 'day' or delete $flare->{appulse};
	return $self->_set( phenomenon => $flare )
	    ->_format_execute( format => 'flare' );
    } else {
	return $self->_format_execute( header => 'flare' );
    }
}

my %tplt_abbr = abbrev (keys %template);

# Regular expression used to parse format effectors out of a template.
my $tplt_regex = qr{
    %				# Leading percent
    ( [ +\-0#]* )		# sprintf-style modifiers
    ( \d* | \* )		# Field width
    (?: [.] ( \d* | [*] ) )?	# Decimal places
    ( \w+ )			# Name of format effector
    (?: [(] ( .*? ) [)] )?	# Optional arguments in parens
    ;?				# Optional trailing semicolon
}smx;

# $self->_format_compiler( $tplt );
# Compile a template to an intermediate form which is easier to execute,
# so we don't have to slog through the decoding every time. The argument
# is the actual value of the template, not its name.
sub _format_compiler {
    my ($self, $tplt) = @_;
    defined $tplt or confess "Programming error - Undefined template";
    my @parts;
    my %used;

    # Literal newlines are ignored in templates. If you want a newline
    # you must use %n.
    $tplt =~ s/ \n //smxg;

    # Expand macros (duh!)
    $tplt = $self->_macro_expand( $tplt );

    # For each format effector in the template
    my $loc = 0;
    while ($tplt =~ m/ $tplt_regex /smxg) {

	# Stuff any literal text before the template into the compiled
	# template.
	my $len = $-[0] - $loc;
	$len > 0 and push @parts, substr $tplt, $loc, $len;

	# Save the individual pieces/parts of the template from the
	# match variables.
	my ($align, $width, $places, $action, $args) =
	    ($1, $2, $3, $4, $5);

	# The format effector may have been abbreviated. Expand it.
	$action = $tplt_abbr{$action}
	    or croak "No format effector for ",
		substr $tplt, $-[0], $+[0] - $-[0];

	# Stash the data for this format effector for easy access.
	my $info = $template{$action}
	    or confess "Programming error - no \$template{$action}";

	# Record a use of this format effector, for the benefit of
	# effectors_used().
	$used{$action}++;

	# Provide values for the sprintf-ish information that may not
	# have been specified.
	defined $align or $align = '';
	defined $width or $width = '';
	defined $places or $places = '';

	# Parse the parenthesized arguments to the format effector, if
	# any. This gets us code fragments to return the desired body
	# and station objects, and a hash of argument values.
	my ($bdy_c, $sta_c, $opt) = $self->_format_args_meta(
	    $action, $info, $args);

	# Compute the value to be used as the field width. If explicitly
	# specified, we use either the specified number, or '' if
	# specified as '*'. If not specified, we default to either the
	# object-specific width, the object-specific default (needed
	# because setting date_format or time_format may change the
	# default width) or the format effector's default.
	my $wid_v = $width eq '*' ? '' :
	    $width ne '' ? $width :
	    defined $self->{formatter}{$action}{width} ?
		$self->{formatter}{$action}{width} :
		defined $self->{formatter_default}{$action}{width} ?
		$self->{formatter_default}{$action}{width} :
		$info->{width};

	# If we have a specific width and the bearing argument was
	# specified, we must adjust the width to include the width of
	# the bearing.
	if ($wid_v) {
	    $opt->{bearing}
		and $wid_v += $opt->{bearing} + 1;
	    $wid_v += length($opt->{append});
	}

	# Compute the value to be used as the number of decimal places.
	# If explicitly specified, we use either the specified number,
	# or '' if specified as '*'. If not specified, we default to
	# either the object-specific default or the format effector's
	# default.
	my $plc_v = $places eq '*' ? '' :
	    $places ne '' ? $places :
	    defined $self->{formatter}{$action}{places} ?
		$self->{formatter}{$action}{places} :
		$info->{places};

	# If we have an explicit title, we use it. Otherwise we
	# fabricate a title from the title associated with the format
	# effector (which can come from either the formatter object or
	# the format effector itself) and the name of the selected
	# object.
	my $ttl_v = do {
	    if (defined $opt->{title}) {
		$opt->{title};
	    } else {
		my $sel = $opt->{selected};
		my $raw_ttl =
		    defined $self->{formatter}{$action}{title} ?
			$self->{formatter}{$action}{title} :
		    defined $info->{title} ? $info->{title} : '';
		if (ref $raw_ttl) {
		    defined $raw_ttl->{$sel} ? $raw_ttl->{$sel} :
			$raw_ttl->{body};
		} else {
		    my $mod_fmt = $template_title_modifier{$sel};
		    $mod_fmt ? sprintf $mod_fmt, $raw_ttl : $raw_ttl;
		}
	    }
	};

	# Compute the units. This is easy because _format_args_meta()
	# did all the heavy lifting for us.
	my $unit_v = $opt->{units};

	# Compute a code fragment to retrieve the value we are going to
	# format.
	my $fet_c = $info->{meta_fetch} ?
	    $info->{meta_fetch}->($opt) :
	    $info->{fetch};

	# Compute the string to be substituted in if the value is
	# unavailable. This is either an explicit string, an
	# object-specific default for this format effector, or the empty
	# string, truncated or space-padded as necessary to get the
	# specified width if any.
	my $missing = $opt->{missing} || $self->{formatter}{$action}{missing};
	my $miss_v = defined $missing ?
	    $wid_v ? substr(
		sprintf("%$align${wid_v}s", $missing),
		0, $wid_v) : $missing :
	    $wid_v ? ' ' x $wid_v : '';

	# Manufacture the code that does the actual formatting.
	my $fmtr = sub {
	    if (defined (my $data = $fet_c->(
			$self, $bdy_c->(), $sta_c->(), $opt))) {
		my $rslt = $opt->{formatter}->($self, $align,
		    $wid_v, $plc_v, $info, $data, $opt);
		return defined $rslt ? $rslt : $miss_v;
	    } else {
		return $miss_v;
	    }
	};

	if ( $info->{literal} ) {
	    # If we're a literal value, compute it now and push it onto
	    # the compiled format, merging with the previous literal if
	    # one is there.
	    my $str = $fmtr->();

	    if ( @parts && !ref $parts[-1] ) {
		$parts[-1] .= $str;
	    } else {
		push @parts, $str;
	    }

	} else {

	    # Make up and push onto the compiled format a hash representing
	    # this format effector.
	    push @parts, {
		align => $align,
		format => $fmtr,
		title => $ttl_v,
		units => $unit_v,
		width => $wid_v,
	    };

	}


	# Move our current location to the end of the format effector,
	# so we can go 'round again.
	$loc = $+[0];
    }

    # If there is any leftover constant text in the template after we
    # found the last format effector, push it onto the compiled
    # template.
    {
	my $len = length ($tplt) - $loc;
	$len > 0 and push @parts, substr $tplt, $loc, $len;
    }

    # Our result is to be interpreted as a hash contining the following
    # keys:
    #  code => a reference to the array containing the compiled
    #      template;
    #  used => a reference to the hash that contains the number of times
    #      each format effector is used.
    # If called in list context, we return this as (effectively) an
    # array. If in scalar context, we make a hash reference out of the
    # result, and return that.
    my @rslt = (code => \@parts, used => \%used);
    return wantarray ? @rslt : {@rslt};
}

{	# Not a template handler; handles the format arguments.

    # All valid arguments must appear here. The keys in the individual
    # argument definitions are:
    #   selector - If true, the argument selects the object to format.
    #     Only one selector may be specified.
    #   default - If specified, it provides a default value for the
    #     argument. If not specified, the default is 1.
    #   standard - If true, the argument is allowed unless the format
    #     effector explicitly forbids it. If false, it is not allowed
    #     unless the format effector explicitly allows it.
    my %argument_def = (
	appulse	=> {
	    selector => 1,
	    standard => 1,
	},
	body	=> {
	    selector => 1,
	    standard => 1,
	},
	bearing	=> {
	    default => 2,
	},
	center	=> {
	    selector => 1,
	    standard => 1,
	},
	earth	=> {
	},
	missing	=> {
	    standard => 1,
	},
	station	=> {
	    standard => 1,
	},
	title	=> {
	    standard => 1,
	},
	units	=> {
	    standard => 1,
	},
    );
    my %tplt_args = abbrev( keys %argument_def );

    sub _format_args_list { return ( sort keys %argument_def ) }

    sub _format_args_meta {
	my ($self, $action, $info, $meta) = @_;
	my %args = (
	    formatter => $info->{formatter},
	    unit_factor => 1,
	);
	my $type;
	$type = $info->{units}
	    and $args{units} =
		($info->{unit_default} || $units{$type}{default});
	exists $self->{formatter}{$action}{units}
	    and $args{units} = $self->{formatter}{$action}{units};
	if (defined $meta) {
	    foreach (split ',', $meta) {
		s/^\s+//;
		s/\s+$//;
		my ($name, $arg) = split '=', $_, 2;
		defined $name or next;	# Might not have any arguments.
		defined $tplt_args{$name}
		    or croak "%$action($name) is not a known argument";
		$name = $tplt_args{$name};
		$argument_def{$name}{standard}
			and not $info->{forbid}{$name}
		    or not $argument_def{$name}{standard}
			and $info->{allow}{$name}
		    or croak "%$action($name) is not allowed";
		defined $arg
		    or $arg = exists $argument_def{$name}{default} ?
			$argument_def{$name}{default} : 1;
		$args{$name} = $arg;
		if ( $argument_def{$name}{selector} ) {
		    exists $args{selected}
			and croak 'Only one of ', join( ', ',
			grep { $argument_def{$_}{selector} }
			sort keys %argument_def ), ' allowed';
		    $args{selected} = $name;
		}
	    }
	}
	unless ($args{selected}) {
	    $args{body} = 1;
	    $args{selected} = 'body';
	}
	my $body = $args{fetch_body} =
	    $args{center} ? sub {$self->{center}{body}} :
	    $args{appulse} ? sub {$self->{appulse}{body}} :
		sub {$self->{body}};
	my $station = sub {$self->{station}};
	if ($args{station}) {
	    ($body, $station) = ($station, $body);
	    $args{selected} = 'station';
	}
	if ($args{units}) {
	    $type
		or croak "%$action does not allow units= specification";
	    my $to;
	    exists $units{$type}{factor}{$args{units}}
		and $to = $args{units};
	    unless ($to) {
		my $units;
		my $re = qr/@{[quotemeta $args{units}]}/;
		foreach (keys %{$units{$type}{factor}}) {
		    m/$re/ or next;
		    $units
			and croak "%$action units abbreviation '$to' ",
			    "not unique";
		    $units = $_;
		}
		$units
		    or croak "%$action units '$args{units}' not valid";
		$to = $units;
	    }
	    $info->{forbid_units}{$to}
		and croak "%$action units '$args{units}' not valid";
	    my $factor;
	    {	# Using as single-iteration loop.
		$factor = $units{$type}{factor}{$to};
		if (my $ref = ref $factor) {
		    if ($ref eq 'SCALAR') {
			$to = $$factor;
			redo;
		    } elsif ($ref eq 'HASH') {
			foreach (keys %$factor) {
			    $args{$_} = $factor->{$_};
			}
			$factor = delete $args{factor};
			defined $factor
			    or confess "Programming error - undefined ",
				"factor in $type $to";
			ref $factor and redo;
		    } elsif ($ref eq 'CODE') {
			$args{formatter} = $factor;
			$factor = 1;
		    } else {
			confess "Programming error - Unknown reference",
			    " $ref in $type $to";
		    }
		}
	    }
	    $args{units} = $to;
	    $args{unit_factor} = $factor;
	}
	defined $args{append} or $args{append} = '';
	return ($body, $station, \%args);
    }
}

sub _format_execute {
    my ( $self, $type, $name ) = @_;
    my $xqt = $self->can('_format_execute_' . $type)
	or confess "Programming error - invalid type '$type'";
    my $tx = $self->_template_fetcher( $name )->{code};
    my $output = $xqt->($self, $tx);
    if (defined $output) {
	$output =~ s/ [ \t]+ \n /\n/smxg;
	$output =~ s/ [ \t]+ \z //smx;
    }
    return $output;
}

sub _format_execute_format {
    my ($self, $tx) = @_;
    my $output = '';
    foreach (@$tx) {
	$output .= ref $_ ? $_->{format}->() : $_;
    }
    return $output;
}

sub _format_execute_header {
    my ($self, $tx) = @_;
    my @columns;
    my $max = 1;
    foreach my $field (@$tx) {
	my ($aln, $wd, $txt) = ref $field ?
	    ($field->{align}, $field->{width}, $field->{title}) :
	    ('', length $field, $field);
	my @lines;
	my $lt = length $txt;
	if (!defined $wd || $wd eq '') {
	    push @lines, $txt;
	} elsif ($lt > $wd) {
	    local $Text::Wrap::columns = $wd + 1;
	    local $Text::Wrap::huge = 'overflow';
	    my $wrapped = wrap ('', '', $txt);
	    chomp $wrapped;
	    @lines = reverse map {substr (sprintf ("%$aln${wd}s", $_), 0, $wd)}
		split ("\n", $wrapped);
	    @lines > $max and $max = @lines;
	} elsif ($lt < $wd) {
	    push @lines, sprintf "%$aln${wd}s", $txt;
	} else {
	    push @lines, $txt;
	}
	push @columns, {width => $wd, lines => \@lines};
    }
    my $output = '';
    while (--$max >= 0) {
	foreach my $field (@columns) {
	    $output .= defined $field->{lines}[$max] ?
		$field->{lines}[$max] : ' ' x $field->{width};
	}
	$max and $output .= "\n";
    }
    return $output;
}

sub _format_almanac_description {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    return _format_string($self, $align, $width, $places, $info,
	$value->{description}, $opt);
}

sub _format_almanac_detail {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    return _format_integer($self, $align, $width, $places, $info,
	$value->{detail}, $opt);
}

sub _format_almanac_event {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    return _format_string($self, $align, $width, $places, $info,
	$value->{event}, $opt);
}

sub _format_azimuth {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;

    if (exists $opt->{bearing}) {
	my $bearing_width = $opt->{bearing} || 2;
	$width and $width -= $bearing_width + 1;
	my $bearing_align = $align;
	$bearing_align =~ m/-/
	    or $bearing_align .= '-';
	return $self->_format_number(
	    $align, $width, $places, $info, $value, $opt) . ' ' .
	$self->_format_bearing(
	    $bearing_align, $bearing_width, $places, $info, $value, $opt);
    } else {
	return $self->_format_number(
	    $align, $width, $places, $info, $value, $opt);
    }
}

{

    my @bearing = (
	[qw{N E S W}],
	[qw{N NE E SE S SW W NW}],
	[qw{N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW}],
   );

    sub _format_bearing {
	my ($self, $align, $width, $places, $info, $value, $opt) = @_;
	my $inx = !$width ? 2 : $width >= 3 ? 2 : $width - 1;
	my $tags = $bearing[$inx];
	my $bins = @$tags;
	$inx = floor ($value / TWOPI * $bins + .5) % $bins;
	return _format_string($self, $align, $width, $places, $info,
	    $tags->[$inx], $opt);
    }
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
	my ($self, $align, $width, $places, $info, $value, $opt) = @_;
	return _format_string($self, $align, $width, $places, $info,
	    $evnt[$value], $opt);
    }

}

sub _format_integer {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    (defined $value && $value ne '')
	or return $width ? ' ' x $width : '';
    $value *= $opt->{unit_factor};
    my $buffer = sprintf "%$align${width}d", $value;
    ($width && length $buffer > $width)
	and $buffer = '*' x $width;
    return $buffer;
}

sub _format_julian_date {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    return _format_number(
	$self, $align, $width, $places, $info, julianday($value),
	$opt);
}

sub _format_number {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    (defined $value && $value ne '')
	or return $width ? ' ' x $width : '';
    defined $places or $places = '';
    $value *= $opt->{unit_factor};
    my $append = $opt->{append} || '';
    ($align eq '' && $width eq '' && $places eq '')
	and return $value . $append;
    my $fwid = $width ? ($width - length $append) : '';
    my $ps = $places eq '' ? '' : ".$places";
    my $buffer = sprintf "%$align$fwid${ps}f", $value;
    # The following line is because sprintf '%.1f', 0.04 produces
    # '-0.0'. This may not be a bug, given what 'perldoc -f sprintf'
    # says, but it sure looks like a wart to me.
    $buffer =~ s/ \A ( \s* ) - ( 0* [.]? 0* \s* ) \z /$1 $2/smx;
    ($places eq '' && $buffer =~ m/\./) and $buffer =~ s/ 0+ \z //smx;
    if ($fwid && length $buffer > $fwid && $fwid >= 7) {
	$buffer = sprintf "%$align$fwid.@{[$fwid - 7]}e", $value;
	$buffer =~ s/e([-+]?)0(\d\d)$/e$1$2/;	# Normalize
    }
    $buffer .= $append;

    ($width && length $buffer > $width)
	and $buffer = '*' x $width;
    return $buffer;
}

sub _format_number_scientific {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    (defined $value && $value ne '')
	or return $width ? ' ' x $width : '';
    $value *= $opt->{unit_factor};
    my $append = $opt->{append} || '';
    ($align eq '' && $width eq '' && $places eq '')
	and return $value . $append;
    my $fwid = $width ? ($width - length $append) : '';
    my $ps = $places eq '' ? '' : ".$places";
    my $buffer = sprintf "%$align$fwid${ps}e", $value;
    $buffer =~ s/e([-+]?)0(\d\d)$/e$1$2/;	# Normalize
    $buffer .= $append;
    ($width && length $buffer > $width)
	and $buffer = '*' x $width;
    return $buffer;
}

sub _format_period {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    my $secs = floor ($value + .5);
    my $mins = floor ($secs / 60);
    $secs %= 60;
    my $hrs = floor ($mins / 60);
    $mins %= 60;
    my $days = floor ($hrs / 24);
    $hrs %= 24;
    if ($days > 0) {
	my $dw = $width - 9;
	$dw < 1 and return '*' x $width;
	my $buffer = sprintf ('%*d %02d:%02d:%02d',
	    $dw, $days, $hrs, $mins, $secs);
	($width && length $buffer > $width) and return '*' x $width;
	return _format_string($self, $align, $width, $places, $info,
	    $buffer);
    } else {
	($width && $width < 8) and return '*' x $width;
	return _format_string($self, $align, $width, $places, $info,
	    sprintf ('%02d:%02d:%02d', $hrs, $mins, $secs));
    }
}

{
    my @table = (
	[6.1 => 'new'], [83.9 => 'waxing crescent'],
	[96.1 => 'first quarter'], [173.9 => 'waxing gibbous'],
	[186.1 => 'full'], [263.9 => 'waning gibbous'],
	[276.1 => 'last quarter'], [353.9 => 'waning crescent'],
    );

    sub _format_phase {
	my ($self, $align, $width, $places, $info, $value, $opt) = @_;
	my $angle = rad2deg($value);
	foreach (@table) {
	    $_->[0] > $angle or next;
	    return _format_string($self, $align, $width, $places,
		$info, $_->[1]);
	}
	return _format_string($self, $align, $width, $places,
	    $info, $table[0][1]);
    }
}

#	Format angle in radians to hours, minutes, and seconds of
#	(presumably) right ascension.

sub _format_right_ascension {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    my $sec = $value / PI * 12;
    my $hr = floor($sec);
    $sec = ($sec - $hr) * 60;
    my $min = floor($sec);
    $sec = ($sec - $min) * 60;
    my $ps = $places eq '' ? '' : ".$places";
    my $buffer = sprintf ("%$align${width}s", sprintf (
	    "%02d:%02d:%02${ps}f",
	    $hr, $min, $sec));
    return ($width && length $buffer > $width) ?
	'*' x $width : $buffer;
}

sub _format_string {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    defined $value or $value = '';
    ($align eq '' && $width eq '') and return $value . '';
    my $buffer = sprintf "%$align${width}s", $value;
    ($width && length $buffer > $width)
	and $buffer = substr $buffer, 0, $width;
    return $buffer;
}

sub _format_text_block {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    return $value . '';
}

sub _format_time {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    my $fmt = join (' ', map {$self->$_()} @{$info->{format}});
    my $gmt = $opt->{gmt} || $self->gmt();
    my $buffer = $self->time_formatter()->strftime(
	$fmt, $value, $opt->{gmt} || undef );
    return _format_string($self, $align, $width, $places, $info,
	$buffer, $opt);
}

sub _format_time_since_epoch {
    my ($self, $align, $width, $places, $info, $value, $opt) = @_;
    my $body = $opt->{fetch_body}->()
	or return;
    my $epoch = eval {$body->get('epoch')} or return;
    return _format_number($self, $align, $width, $places, $info,
	$value - $epoch, $opt);
}

{

    my %check = (
	missing => sub {},
	places => sub {$_[2] =~ m/\D/ and croak "Places must be an integer"},
	title => sub {},
	width => sub {$_[2] =~ m/\D/ and croak "Width must be an integer"},
	units => sub {
	    my ( $action, $name, $val ) = @_;
	    my $units = $template{$action}{units}
		or croak "%$action does not support units";
	    exists $units{$units}{factor}{$val}
		or croak "'$val' is not a valid '$units'";
	    return;
	},
    );
    my @names = sort keys %check;
    sub format_effector {
	my ($self, $action, @args) = @_;
	$template{$action}
	    or croak "No such format effector as '$action'";
	if (@args) {
	    while (@args) {
		my ( $name, $val ) = splice @args, 0, 2;
		$check{$name}
		    or croak "No such format effector attribute as '$name'";
		delete $self->{_template_cache};
		if (defined $val) {
		    $check{$name}->( $action, $name, $val );
		    $self->{formatter}{$action}{$name} = $val;
		} else {
		    delete $self->{formatter}{$action}{$name};
		    %{$self->{formatter}{$action}}
			or delete $self->{formatter}{$action};
		}
	    }
	    return $self;
	} else {
	    my @data;
	    $self->{formatter}{$action}
		or return wantarray ? @data : \@data;
	    foreach (@names) {
		exists $self->{formatter}{$action}{$_}
		    and push @data, $_ => $self->{formatter}{$action}{$_};
	    }
	    return wantarray ? @data : \@data;
	}
    }
}

sub gmt {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->time_formatter()->gmt( @args );
	return $self->SUPER::gmt( @args );
    } else {
	return $self->SUPER::gmt();
    }
}

sub list {
    my ( $self, $body ) = @_;
    if ( defined $body ) {
	return $self->_set( body => $body )->_format_execute( format =>
	    $body->get( 'inertial' ) ? 'list_inertial' : 'list_fixed' );
    } else {
	return $self->_format_execute( header => 'list_inertial' );
    }
}

sub local_coord {
    my ( $self, @args ) = @_;
    if ( @args ) {
	my $val = $args[0];
	defined $val or $val = 'azel_rng';
	$self->macro( $val ) and $val ne 'local_coord'
	    or croak "Unsupported local coordinate specification '$val'";
	$self->macro( local_coord => "%$val(\$*);" );
	return $self->SUPER::local_coord( @args );
    } else {
	return $self->SUPER::local_coord();
    }
}

sub location {
    my ( $self, $station ) = @_;
    if ( defined $station ) {
	return (
	    $self->_set( body => $station )->_format_execute(
		format => 'location' ) );
    } else {
	return '';
    }
}

sub macro {
    my ( $self, @args ) = @_;
    my $name = shift @args;
    if ( @args ) {
	my $def = shift @args;
	if ( defined $def ) {
	    $name =~ m/ \W /smx
		and croak "Macro name '$name' contains invalid characters";
	    exists $template{$name}
		and croak "Macro name '$name' duplicates format effector name";
	    $def =~ s/ \n //smxg;
	    $self->{macro}{$name} = $def;
	} else {
	    delete $self->{macro}{$name};
	}
	# We must delete the compiled formats since macros are expanded
	# during compilation.
	delete $self->{_template_cache};
	$self->{_macro_count} = scalar keys %{ $self->{macro} };
    }
    return $self->{macro}{$name};
}

sub _macro_expand {
    my ( $self, $string ) = @_;
    my $limit = $self->{_macro_count};
    while ( --$limit >= 0 ) {
	my @replace;
	while ( $string =~ m/ ( % ( \w+ ) ( \( .*? \) )? ;? ) /smxg ) {
	    exists $self->{macro}{$2} or next;
	    push @replace, [ $-[0], $1, $2, $3 ];
	}
	foreach ( reverse @replace ) {
	    my ( $base, $replace, $name, $args ) = @{ $_ };
	    defined $args or $args = '';
	    $args =~ s/ \A \( //smx;
	    $args =~ s/ \) \z //smx;
	    ( my $expand = $self->{macro}{$name} ) =~ s/ \$ \* /$args/smxg;
	    substr( $string, $base, length $replace ) = $expand;
	}
	@replace or last;
    }
    return $string;
}

sub pass {
    my ( $self, $pass ) = @_;
    if ( defined $pass ) {
	my $output;
	my $line = 0;
	foreach my $event ( @{ $pass->{events} } ) {
	    $self->_set( phenomenon => $event );

	    if ( ! $line++ ) {
		my $hdr = $self->_format_execute( format => 'pass_oid' );
		if ( $hdr eq $self->{_pass_oid_header} ) {
		    # We use this ad-hocery to supress the leading blank
		    # line for convenience in testing.
		    $pass->{body} and $output .= "\n";
		} else {
		    $output .= $self->{_pass_oid_header} = $hdr;
		}
	    }

	    $event->{body}->universal( $event->{time} );
	    $output .= $self->_format_execute( format => 'pass' );
	    if ( $event->{appulse} ) {
		$output .= $self->_format_execute( format => 'pass_appulse' );
	    }
	}
	return $output;
    } else {
	$self->{_pass_oid_header} = '';
	return $self->_format_execute( header => 'pass' );
    }
}

sub phase {
    my ( $self, $body ) = @_;
    if ( defined $body ) {
	return $self->_set( body => $body, time => $body->universal() )
	    ->_format_execute( format => 'phase' );
    } else {
	return $self->_format_execute( header => 'phase' );
    }
}

sub position {
    my ( $self, $hash ) = @_;
    if ( defined $hash ) {
	my $body = $hash->{body};
	my $questionable = $hash->{questionable};
	my $sta = $hash->{station};
	my $sun = $hash->{sun};
	my $twilight = $hash->{twilight};
	defined $twilight or $twilight = deg2rad( -6 );	# civil
	my $time = $body->universal();
	$self->_set( body => $body, time => $time, station => $sta );
	my $output = '';
	my $time_out = $self->_format_execute( format => 'date_time' );
	$time_out eq $self->{_position_time}
	    or $output .= ( $self->{_position_time} = $time_out );
	if ( $sun && $sta && $body->represents( 'Astro::Coord::ECI::TLE' ) ) {
	    my $illum = ($sta->azel ($body))[1] < 0 ? PASS_EVENT_NONE :
		($sta->azel ($sun))[1] > $twilight ?
		PASS_EVENT_DAY :
		($body->azel ($sun))[1] > $body->dip() ? PASS_EVENT_LIT
		: PASS_EVENT_SHADOWED;
	    $output .= $self->_set( illumination => $illum )
		->_format_execute( format => 'position' );
	    if ( $body->can_flare( $questionable ) ) {
		$body->_set( horizon => 0 );
		foreach my $info ( $body->reflection( $sta, $time ) ) {
		    $output .= $self->_set(
			phenomenon => $info,
			station => $sta,	# Phenom may clobber
		    )->_format_execute( format =>
			!exists $info->{mma} ? 'position_nomma' :
			$info->{status} ? 'position_status' :
			'position_flare' );
		}
	    }
	} else {
	    $output .= $self->_set( illumination => undef )
		->_format_execute( format => 'position' );
	}
	return $output;
    } else {
	$self->{_position_time} = '';
	return $self->_format_execute( header => 'position' );
    }
}

# $fmt->_set($name => $value ...);

# This method sets the values of the given attributes. More than one
# $name => $value pair may be specified. An exception is thrown on
# encountering a $name that refers to a non-existent attribute; all
# attributes specified prior to the non-existent one are set.
# 
# The return is the formatter object, to allow call chaining.

#  Attributes

# Most attributes specify data to be formatted, though a few specify how
# to format the data. The names of the attributes are given with, in
# parentheses, the intended use ('data' or 'format'), and the data type
# ('integer', 'real', 'string', 'body', or 'hash' (reference)) if that
# is relevant.

# The 'body' data type is to be understood as representing an
# Astro::Coord::ECI object. Typically this means either an object of
# class Astro::Coord::ECI (or a subclass thereof), or an object of class
# Astro::Coord::ECI::TLE::Set, which contains at least one object of
# class Astro::Coord::ECI::TLE (or a subclass thereof).

# The attributes of the formatter are:

# almanac(data,hash)

# This attribute is intended to hold almanac data. Specifically, the
# content is expected to be the {almanac} key from one of the hashes
# returned by an almanac_hash() method.

# The user would normally not set this directly, but pass the individual
# hashes returned by almanac_hash() to the 'phenomenon' pseudo-attribute
# (which see).

# angle(data,real)

# This attribute is intended to hold the mirror angle from one of the
# hashes returned by the Astro::Coord::ECI::TLE::Iridium->flare()
# method, though it can be used to hold any angle to be reported.

# The user would normally set this by passing the entire Iridium flare
# hash to the 'phenomenon' pseudo-attribute (which see).

# appulse(data,hash)

# This attribute is intended to hold the {appulse} data which may be
# returned by the Astro::Coord::ECI::TLE->pass() method, though the user
# can store any similarly-constructed hash in it. The {body} sub-key is
# the body selected by the 'appulse' format effector argument.

# The user would normally set this by passing the entire pass hash to
# the 'phenomenon' pseudo-attribute (which see).

# body(data,body)

# This attribute is intended to hold the body of primary interest to the
# user of the individual formatter object. Typically it will be either a
# satellite or an astronomical object. This is the body which is
# selected by the 'body' format effector argument, or by not specifying
# any of the other selector arguments.

# This is set by the 'phenomenon' pseudo-attribute.

# center(data,hash)

# This attribute is intended to hold the {center} data returned by the
# Astro::Coord::ECI::TLE::Iridium->flare() method, though the user can
# store any similarly-constructed hash in it. The {body} sub-key is the
# body selected by the 'center' format effector argument.

# The user would normally set this by passing the entire flare hash to
# the 'phenomenon' pseudo-attribute (which see).

# event(data,integer)

# This attribute is intended to hold the {event} data returned by the
# Astro::Corod::ECI::TLE->pass() method. This is one of the PASS_EVENT_*
# constants, which are dualvars. The numeric value is used by the
# %event; format effector to generate a string describing the event.

# The user would normally set this by passing the entire pass hash to
# the 'phenomenon' pseudo-attribute (which see).

# illumination(data,integer)

# This attribute is intended to hold the {illumination} data returned by
# the Astro::Corod::ECI::TLE->pass() method. This is one of the
# PASS_EVENT_* constants, which are dualvars. The numeric value is used
# by the %illumination; format effector to generate a string describing
# the illumination, typically 'lit', 'shdw', or 'day'.

# The user would normally set this by passing the entire pass hash to
# the 'phenomenon' pseudo-attribute (which see).

# magnitude(data,real)

# This attribute is intended to hold the {magnitude} data returned by
# the Astro::Coord::ECI::TLE::Iridium->flare() method. The value is used
# by the %magnitude; format effector.

# The user would normally set this by passing the entire flare hash to
# the 'phenomenon' pseudo-attribute.

# mma(data,real)

# This attribute is intended to hold the {mma} data returned by the
# Astro::Coord::ECI::TLE::Iridium->flare() method. The value is used by
# the %mma; format effector.

# The user would normally set this by passing the entire flare hash to
# the 'phenomenon' pseudo-attribute.

# phenomenon(data,hash)

# This has been called a pseudo-attribute in the documentation because,
# although you can use the set() method to set it, there is actually no
# attribute with this name, and get('phenomenon') is an error.

# What actually happens when you set(phenomenon => \%hash) is that
# selected attributes are set according to the keys found in %hash. The
# following attributes are set by this pseudo-attribute from hash keys
# of the same name: almanac, angle, appulse, body, center, event,
# illumination, magnitude, mma, station, status, time, and type. For all
# attributes in the list except 'station', the attribute is set to undef
# if the corresponding key does not appear in the hash. The 'station'
# key is an exception for pragmatic reasons.

# station(data,body)

# This attribute is intended to hold an Astro::Coord::ECI object
# representing the observer's location.

# status(data,string)

# This attribute is intended to hold the {status} key returned by
# Astro::Coord::ECI::TLE::Iridium->flare(). This value is used by the
# %status; format effector.

# The user would normally set this by passing the entire flare hash to
# the 'phenomenon' pseudo-attribute.

# time(data,number)

# This attribute holds the value to be formatted by the %date; and
# %time; format effectors.

# type(data,string)

# This attribute is intended to hold the {type} key returned by
# Astro::Coord::ECI::TLE::Iridium->flare(). This value is used by the
# %type; format effector.

# The user would normally set this by passing the entire flare hash to
# the 'phenomenon' pseudo-attribute.

sub _set {
    my ($self, @args) = @_;
    while (@args) {
	my $name = shift @args;
	my $code = $mutator{$name}
	    or croak "Unknown or read-only ", __PACKAGE__,
	    " attribute '$name'";
	$code->($self, $name, shift @args);
    }
    return $self;
}

sub _set_almanac {
    my ($self, $name, $value) = @_;
    if (defined $value) {
	ref $value eq 'HASH'
	    or croak "Value of almanac must be a hash reference";
    }
    return ($self->{$name} = $value);
}

sub _set_appulse {
    my ($self, $name, $value) = @_;
    if (defined $value) {
	ref $value eq 'HASH'
	    or croak "Value of appulse must be a hash reference";
	exists $value->{body} or croak "Appulse hash must contain a body";
	return ($self->{$name} = $value);
    } else {
	delete $self->{$name};
	return;
    }
}

sub _set_center {
    my ($self, $name, $value) = @_;
    if (defined $value) {
	ref $value eq 'HASH'
	    or croak "Value of center must be a hash reference";
	exists $value->{body} or croak "Center hash must contain a body";
	return ($self->{$name} = $value);
    } else {
	delete $self->{$name};
	return;
    }
}

sub _set_eci {
    (defined $_[2] && !embodies($_[2], 'Astro::Coord::ECI'))
	and croak "'$_[1]' value must be subclass of Astro::Coord::ECI";
    return ($_[0]{$_[1]} = $_[2]);
}

sub _set_literal {
    return ($_[0]{$_[1]} = $_[2])
}

sub _set_phenomenon {
    my ($self, $name, $data) = @_;
    ref $data
	or croak "Scalar phenomenon not understood";
    ref $data eq 'HASH'
	or croak "Reference to ", ref $data, " not understood";
    $self->_set(map {$_ => $data->{$_}} qw{body time
	angle center magnitude mma status type
	almanac
	event appulse illumination});
    # For pragmatic reasons we do not delete the station if it does not
    # appear in the input hash - but we do set it if it does appear.
    $data->{station} and $self->_set(station => $data->{station});
    if ($self->{time}) {
	$self->{body}
	    and $self->{body}->universal($self->{time});
	$self->{appulse}
	    and $self->{appulse}{body}->universal($self->{time});
    }
    return $data;
}

{

    my %attr;	# Names of *_format attributes.
    my %fmt;	# Format effectors that use *_format attribtutes

    foreach my $key (keys %template) {
	my $fmt = $template{$key}{format} or next;
	foreach (@$fmt) {
	    $attr{$_}++;
	    push @{$fmt{$_} ||= []}, $key;
	}
    }

    sub _set_time_format {
	my ($self, $name, $data) = @_;
	my $key = $fmt{$name}
	    or confess "Programming error. '$name' invalid for ",
	    "_set_time_format()";
	$self->{$name} = $data;
	# We must delete the compiled templates since the widths of
	# fields may change as a result of changing date_format or
	# time_format.
	delete $self->{_template_cache};

	foreach my $tplt (@$key) {
	    my $info = $template{$tplt};
	    my $tf = join (' ', map {$self->$_()} @{$info->{format}});
	    $self->{formatter_default}{$tplt}{width} =
		$self->time_formatter()->strftime_width( $tf );
	}
	return;
    }

    # Compute default field widths based on initial values of time
    # formats.
    sub _set_time_format_initial {
	my ( $self ) = @_;
	foreach my $name ( keys %attr ) {
	    $self->$name( $self->$name() );
	}
	return;
    }
}

sub template {
    my ( $self, $name, @value ) = @_;
    if ( @value ) {
	if ( defined $value[0] ) {
	    $self->{template}{$name} = $value[0];
	} else {
	    delete $self->{template}{$name};
	}
        delete $self->{_template_cache};
	return $self;
    } else {
        return $self->{template}{$name};
    }
}

sub _template_fetcher {
    my ( $self, $name ) = @_;
    defined $name or croak 'Template name undefined';
    defined $self->{template}{$name}
	or croak "Template '$name' not defined";
    return ( $self->{_template_cache}{$name} ||=
	$self->_format_compiler( $self->{template}{$name} ) );
}

sub time_format {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->_set_time_format( time_format => @args );
	return $self->SUPER::time_format( @args );
    } else {
	return $self->SUPER::time_format();
    }
}

sub tle {
    my ( $self, $body ) = @_;
    if ( defined $body ) {
	return $self->_set( body => $body )->_format_execute( format => 'tle' );
    } else {
	return '';
    }
}

# TODO when we get the code right, _tle_celestia loses its leading
# underscore and gets documented.
sub _tle_celestia {
    my ( $self, $body ) = @_;
    if ( defined $body ) {
	return $self->_set( body => $body )->_format_execute(
	    format => 'tle_celestia' );
    } else {
	return '';
    }
}

sub tle_verbose {
    my ( $self, $body ) = @_;
    if ( defined $body ) {
	return $self->_set( body => $body )->_format_execute( 
	    format => 'tle_verbose' );
    } else {
	return '';
    }
}

sub tz {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->time_formatter()->tz( @args );
	return $self->SUPER::tz( @args );
    } else {
	return $self->SUPER::tz();
    }
}

########################################################################
#
#	General-purpose internal routines

#	$hash = _clone_template($name, $arg => $val ...)
#
#	This subroutine does a shallow clone on the named template item,
#	replacing the values of the desired arguments. A reference to
#	the cloned hash is returned.

sub _clone_template {
    my ($name, %args) = @_;
    my $clone = {};
    foreach my $key (keys %{ $template{$name} }) {
	$clone->{$key} = $template{$name}{$key};
    }
    foreach my $key (keys %args) {
	if (defined $args{$key}) {
	    $clone->{$key} = $args{$key};
	} else {
	    delete $clone->{$key};
	}
    }
    return $clone;
}

#	@coords = $self->_fetch_precessed_coordinates( $method, $body );
#	@coords = $self->_fetch_precessed_coordinates( $method, $body,
#			$station );
#
#	This method fetches the coordinates of the given body which are
#	specified by the given method. These must be inertial, and are
#	precessed if desired. If the body is not defined, nothing is
#	returned. If the station is passed, the coordinates are relative
#	to it; if it is undefined, nothing is returned.

sub _fetch_precessed_coordinates {
    my ( $self, $method, @args ) = @_;
    defined $args[0] or return;
    @args < 2 or defined $args[1] or return;
    if ( my $equinox = $self->desired_equinox_dynamical() ) {
	@args > 1 and $args[1]->universal( $args[0]->universal() );
	@args = map { $_->clone()->precess_dynamical( $equinox ) } @args;
    }
    my $body = pop @args;
    return $body->$method( @args );
}

#	@names = _names($type);
#
#	This subroutine returns all names of the given type. This has
#	nothing to do with formatting, but helps me test to see what
#	abbreviations are unique.
#
#	The valid types are:
#
#	    argument - the names of valid format effector arguments;
#	    format - the names of valid format effectors;
#	    unit=... - the names of valid units for the given dimension.

sub _names {
    my ($type) = @_;
    if (!defined $type) {
	return (sort qw{argument format}, map {"unit=$_"} keys %units);
    } elsif ($type eq 'argument') {
	return _format_args_list();
    } elsif ($type eq 'format') {
	return (sort keys %template);
    } elsif ($type =~ m/^unit=(.+)/) {
	$units{$1}
	    or croak "Illegal _names type '$type'";
	return (sort keys %{$units{$1}{factor}});
    } else {
	croak "Illegal _names type '$type'";
    }
}

#	$abbrev = _shortest_abbrev($type,$name)
#
#	This subroutine returns the shortest abbreviation of the given
#	name of the given type. The types are as for _names(). This has
#	nothing to do with formatting, but since abbreviations are
#	allowed, I wanted to test to know when the shortest unique one
#	changed.
#
#	You get an exception if the type is invalid, and undef if the
#	name is.

{
    my %abbrs;
    sub _shortest_abbrev {
	my ($type, $name) = @_;
	unless ($abbrs{$type}) {
	    my @data = _names($type);
	    my %abbrev;
	    foreach my $word (@data) {
		foreach my $len (1 .. length $word) {
		    my $short = substr $word, 0, $len;
		    push @{$abbrev{$short} ||= []}, $word;
		}
	    }
	    my %expand;
	    foreach my $short (sort keys %abbrev) {
		if (@{$abbrev{$short}} == 1) {
		    my $word = $abbrev{$short}[0];
		    exists $expand{$word}
			or $expand{$word} = $short;
		}
	    }
	    foreach my $word (@data) {
		exists $expand{$word}
		    or $expand{$word} = $word;
	    }
	    $abbrs{$type} = \%expand;
	}
	return $abbrs{$type}{$name};
    }
}

1;

__END__

=head1 NAME

App::Satpass2::Format::Classic - Format App::Satpass2 output as text.

=head1 SYNOPSIS

 use App::Satpass2::Format::Classic;
 use Astro::Coord::ECI;
 use Astro::Coord::ECI::Moon;
 use Astro::Coord::ECI::Sun;
 use Astro::Coord::ECI::Utils qw{ deg2rad };
 # 
 my $time = time();
 my $moon = Astro::Coord::ECI::Moon->universal($time);
 my $sun = Astro::Coord::ECI::Sun->universal($time);
 my $station = Astro::Coord::ECI->new(
     name => 'White House',
 )->geodetic(
     deg2rad(38.8987),  # latitude
     deg2rad(-77.0377), # longitude
     17 / 1000);	# height above sea level, Km
 my $fmt = App::Satpass2::Format::Classic->new();
 #
 print $fmt->location();
 print $fmt->location( $station );
 print $fmt->position();
 foreach my $body ($sun, $moon) {
     print $fmt->position( {
             station => $station,
	     sun => $sun,
	     body => $body,
	     } );
 }

=head1 NOTICE

This is alpha code. It has been tested on my box, but has limited
exposure to the wild. Also, the public interface may not be completely
stable, and may change if needed to support
L<App::Satpass2|App::Satpass2>. I will try to document any incompatible
changes.

=head1 DETAILS

This class is intended to perform output formatting for
L<App::Satpass2|App::Satpass2>, producing output similar to that
produced by the F<satpass> script distributed with
L<Astro::Coord::ECI|Astro::Coord::ECI>. It is a subclass of
L<App::Satpass2::Format|App::Satpass2::Format>, and conforms to that
interface.

This class does its job using a templating system. Each of the defined
formatting methods makes use of one or more named templates to generate
its output. Each template may contain format effectors (think C<sprintf>
on steroids) to define what is actually produced. Literal new lines in
templates are ignored; if you want a literal C<"\n"> in your output you
must use the C<%n> format effector.

The names and contents of the templates used by each formatter are
described below. The templates may be retrieved or modified using the
L<template()|/template> method.

In addition, this class supports something called a C<macro>, which is
used to implement the L<local_coord|App::Satpass2::Format/local_coord>
functionality. A macro is a named template fragment, which is
substituted into a template the first time it is used. Macros may be
defined in terms of other macros, but defining a macro in terms of
itself (either directly or indirectly) is unsupported, and probably will
result in deep recursion errors from Perl. So don't do that. Macros may
be retrieved or modified using the L</macro> method.

For example, the default local coordinate is C<azel_rng>. This is
implemented by the equivalent of

 use App::Satpass2::Format::Classic;
 my $f = App::Satpass2::Format::Classic->new();
 $f->macro( local_coord => '%azel_rng($*)' );

The C<($*)> causes any arguments to the macro to passed through to
C<%azel_rng($*)>, which is in fact another macro, the equivalent of

 $f->macro( azel_rng =>
   '%elevation($*); %azimuth($*,bearing); %range($*);' );

The C<%elevation($*)> and so forth are actual format effectors, calling
for the appropriate data to be substituted into the template.

=head1 METHODS

This class supports the following public methods. Methods inherited from
L<App::Satpass2::Format|App::Satpass2::Format> are documented here if
this class adds significant functionality.

=head2 Instantiator

=head3 new

 $fmt = App::Satpass2::Format::Classic->new();

This static method instantiates a new formatter.

=head2 Accessors and Mutators

=head3 date_format

 print "Date format: '", $fmt->date_format(), "'\n";
 $fmt->date_format( '%Y-%m-%d' );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<date_format()|App::Satpass2::Format/date_format> method, and performs
the same function. It also looks at the new format and attempts (note
the weasel word!) to adjust the default field width appropriately.

=head3 local_coord

 print 'Local coord: ', $fmt->local_coord(), "\n";
 $fmt->local_coord( 'azel_rng' );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<local_coord()|App::Satpass2::Format/local_coord> method, and performs
the same function.

When used as a mutator, it performs its function by checking to see if
there is already a L</macro> of the given name, and if so defining
L</macro> C<local_coord> to be the given macro.  If there is no
L</macro> with the given name, the method croaks. If the given name is
C<undef>, the default of C<azel_rng> is restored.

=head3 time_format

 print "Time format: '", $fmt->time_format(), "'\n";
 $fmt->time_format( '%Y-%m-%d' );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<time_format()|App::Satpass2::Format/time_format> method, and performs
the same function. It also looks at the new format and attempts (note
the weasel word!) to adjust the default field width appropriately.

=head2 Formatters

=head3 almanac

 print $fmt->almanac();
 print $fmt->almanac( $almanac_hash );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<almanac()|App::Satpass2::Format/almanac> method, and performs the same
function. It uses template C<almanac>, which defaults to

 %date %time %*almanac%n

=head3 flare

 print $fmt->flare();
 print $fmt->flare( $flare_hash );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<flare()|App::Satpass2::Format/flare> method, and performs the same
function. It uses template C<flare>, which defaults to

 %-date %-time %-12name %local_coord %magnitude
   %5angle(appulse,title=degrees from sun,missing=night)
   %azimuth(center,bearing) %6.1range(center)%n

The above template is wrapped to fit on the page.

=head3 list

 print $fmt->list();
 print $fmt->list( $body );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<list()|App::Satpass2::Format/list> method, and performs the same
function. It uses template C<list_inertal>, which defaults to

  %id %-name %-epoch %-period%n

for inertial bodies (i.e. pretty much all of them), and template
C<list_fixed>, which defaults to

  %id %name %latitude %longitude %altitude%n

for Earth-fixed bodies.

=head3 location

 print $fmt->location();
 print $fmt->location( $eci );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<location()|App::Satpass2::Format/location> method, and performs the
same function. It uses template C<location>, which defaults to

 Location: %*name;%n
           Latitude %*.4latitude, longitude %*.4longitude,
           height %*.0altitude(units=meters) m%n

The above template is wrapped to fit on the page.

=head3 pass

 print $fmt->pass();
 print $fmt->pass( $body );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<pass()|App::Satpass2::Format/pass> method, and performs the same
function. It uses template C<pass>, which defaults to

 %time %local_coord %latitude %longitude %altitude %-illumination %-event%n

to display the events of individual passes. It uses template
C<pass_oid>, which defaults to

 %n%id - %-*name  %date%n

to identify the satellite and the date at the beginning of each pass;
but only if they have changed between passes. If they have not, you just
get a blank line between  passes.

It uses template C<pass_appulse> to display the body the satellite
appulses with, if any. This defaults to

 %time %local_coord(appulse)       %angle(appulse) degrees from
    %-name(appulse)%n

The above template is wrapped to fit on the page.

=head3 phase

 print $fmt->phase();
 print $fmt->phase( $body );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<phase()|App::Satpass2::Format/phase> method, and performs the same
function. It uses template C<phase>, which defaults to

 %date %time %8name %phase(title=phase angle)
   %-16phase(units=phase) %.0fraction_lit(units=percent)%n

to display the phase of the given body. The above format has been
wrapped to fit on the line.

=head3 position

 print $fmt->position();
 print $fmt->position( $position_hash );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<position()|App::Satpass2::Format/position> method, and performs the
same function. It uses template C<position>, which defaults to

 %16name(missing=oid) %local_coord %epoch %illumination%n

It also uses template C<date_time> to place the date and time in the
output stream before any positions for a given date and time are
displayed. This template defaults to

 %date %time%n

If the C<date_time> template is set to the empty string, this
functionality is disabled.

In addition, if the body specified in the position hash is an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> whose can_flare()
method returns true, one or more extra lines of information will be
provided. Each line will be formatted using the appropriate one of the
following templates:

=over

=item position_flare

This template will be used if a flare from the given MMA is
geometrically possible, regardless of its magnitude. It defaults to

 %30space;MMA %mma mirror angle %angle magnitude %magnitude%n

=item position_status

This template will be used if a flare from the given MMA is not
geometrically possible. It defaults to

 %30space;MMA %mma %-status%n

=item position_nomma

This template will be used if no flares are possible (typically because
the body is not illuminated). It defaults to

 %30space;%-status%n

=back

=head3 tle

 print $fmt->tle();
 print $fmt->tle( $body );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<tle()|App::Satpass2::Format/tle> method, and performs the same
function. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, or something
equivalent. It uses template C<tle>, which defaults to

 %tle

Note the absence of the trailing newline, which is assumed to be part of
the tle data itself.

=begin comment

# TODO when the code works, _tle_celestia loses its leading underscore.
# =head3 _tle_celestia

 print $fmt->tle_celestia( $body );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<tle_celestia()|App::Satpass2::Format/tle_celestia> method, and
performs the same function. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, or something
equivalent.

This method is unsupported because I have not yet gotten results that
put the International Space Station where it actually is.

This method uses template C<tle_celestia>, which defaults to

 # Keplerian elements for %*name%n
 # Generated by %*provider%n
 # Epoch: %*epoch UT%n
 %n
 Modify "%*name" "Sol/Earth" {%n
     EllipticalOrbit {%n
         Epoch  %*.*epoch(units=julian)%n
         Period  %*.*period(units=days)%n
         SemiMajorAxis  %*.*semimajor%n
         Eccentricity  %*.*eccentricity%n
         Inclination  %*.*inclination%n
         AscendingNode  %*.*ascendingnode(units=degrees)%n
         ArgOfPericenter  %*.*argumentofperigee%n
         MeanAnomaly  %*.*meananomaly%n
     }%n
     UniformRotation {%n
         Inclination  %*.*inclination%n
         MeridianAngle  90%n
         AscendingNode  %*.*ascendingnode(units=degrees)%n
     }%n
 }%n

Note that the above template is B<not> wrapped, and produces multiline
output.

=end comment

=head3 tle_verbose

 print $fmt->tle_verbose( $body );

This method overrides the L<App::Satpass2::Format|App::Satpass2::Format>
L<tle_verbose()|App::Satpass2::Format/tle_verbose> method, and performs
the same function. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, or something
equivalent. It uses template C<tle_verbose>, which defaults to

 NORAD ID: %*id;%n
     Name: %*name%n
     International launch designator: %*international%n
     Epoch of data: %#epoch GMT%n
     Effective date of data: %*effective(missing=<none>) GMT%n
     Classification status: %classification%n
     Mean motion: %*.*meanmotion degrees/minute%n
     First derivative of motion: %*.*firstderivative degrees/minute squared%n
     Second derivative of motion: %*.*secondderivative degrees/minute cubed%n
     B Star drag term: %*bstardrag%n
     Ephemeris type: %ephemeristype%n
     Inclination of orbit: %*.*inclination degrees%n
     Right ascension of ascending node: %*.*ascendingnode%n
     Eccentricity: %eccentricity%n
     Argument of perigee: %*.*argumentofperigee degrees from ascending node%n
     Mean anomaly: %*.*meananomaly degrees%n
     Element set number: %*elementnumber%n
     Revolutions at epoch: %*revolutionsatepoch%n
     Period (derived): %*period%n
     Semimajor axis (derived): %*.*semimajor kilometers%n
     Perigee altitude (derived): %*.*perigee kilometers%n
     Apogee altitude (derived): %*.*apoapsis kilometers%n

Note that the above template is not wrapped, and produces multiline
output.

=head2 Other Methods

The following other methods are provided.

=head3 effectors_used

 %hash = $fmt->effectors_used( $name );

This method is not inherited from
L<App::Satpass2::Format|App::Satpass2::Format>. It returns a hash
containing the number of times each format effector is used in the named
template. Format effectors not appearing in the template are not
represented in the hash.  If called in scalar context the return is a
reference to a copy of the hash (that is, changing the returned data
does not effect the data stored in the object).

=head3 format_effector

 $fmt->format_effector( $name => $attr => $value ... );
 use YAML;
 print Dump( $fmt->format_effector( $name ) );

This method is not inherited from
L<App::Satpass2::Format|App::Satpass2::Format>. It alters defaults for
the given format effector. The altered defaults apply only to the
formatter object the method is called on. The $name argument specifies
the format effector to change (no abbreviations allowed here), and the
$attr => $value pairs specify the new defaults.

The valid $attr values are 'missing', 'places', 'title', 'units', and
'width', to change the default replacement text, number of decimal
places, title, units of measure, and field width respectively.  The
'places' and 'width' settings must be whole numbers or ''. Setting
'places' or 'width' to '' specifies that no restriction be imposed on
these attributes, and is equivalent to specifying '*' in the template.
Attempting to set 'units' on a format effector that does not support
units will result in an exception.

Setting any attribute to C<undef> restores its previous default.

If called without any $attr => $value pairs, the return is a reference
to a hash containing the current default settings for the object. Global
defaults will not be represented in the hash.

If called with at least one $attr => $value pair, the return is the
formatter object itself, to allow call chaining.

=head3 macro

 print $fmt->macro( 'foo' );
 $fmt->macro( foo => '%azimuth %elevation' );

This method is not inherited from
L<App::Satpass2::Format|App::Satpass2::Format>. It returns the
definition of a macro, or defines it (or redefines it) if the definition
argument is provided. The definition is the provided argument (which may
contain format effectors), with literal C<"\n"> characters removed. If
the definition is C<undef>, the macro is deleted.

The method always returns the definition of the macro; if the macro does
not exist, it returns C<undef>.

Note that the name of a format effector may not be used as a macro name.

=head3 template

 print "Template 'almanac' is '", $fmt->template( 'almanac' ), "'\n";
 $fmt->template( almanac => '%time %*almanac%n' );

This method is not inherited from
L<App::Satpass2::Format|App::Satpass2::Format>.

If called with a single argument (the name of a template) this method is
an accessor that returns the named template. If the named template does
not exist, this method croaks.

If called with two arguments (the name of a template and the template
itself), this method is a mutator that sets the named template. If the
template is C<undef>, the named template is deleted. The object itself
is returned, to allow call chaining.

=head1 FORMAT EFFECTORS

Data from the arguments of the individual formatter routines can be
placed in the output by inserting format effectors into the relevant
template. 

Each format effector begins with a percent sign ('%') followed in order
by flags, field width, decimal places, effector name, effector arguments
in parentheses, and ending with an optional semicolon (';') if needed.
Of these, only the percent sign and the effector name are required.

The flags are those recognized by sprintf, and serve pretty much the
same purpose; in fact, they are in general passed to sprintf for
execution. The legal flags are:

 space  prefix positive number with space;
 +      prefix positive number with plus sign;
 -      left-justify within field;
 0      right-justify with zeros, not spaces;
 #      alternate representation.

The field width is a positive integer. If omitted, the default varies
with the format effector. If specified as '*', no width restriction is
imposed. The default for a given format effector can be changed using
the L<format_effector()|/format_effector> method.

The decimal places specification is a decimal point ('.' regardless of
locale) followed by a positive integer. If omitted, the default varies
with the format effector. If specified as '.*', you get whatever the
sprintf format (usually '%f' or '%e') gives, but with trailing zeroes to
the right of the decimal point eliminated. The default for a given
format effector can be changed using the
L<format_effector()|/format_effector> method. Not all format effectors
make use of this; whether a given format effector uses it or not will be
documented with the effector. If a format effector does not use it, any
specification of decimal places will be ignored.

As a special case for those format effectors that return a number in
floating-point (not integer or scientific notation), if the alignment
flags are omitted, and both width and decimal places are specified as
'*', the number is formatted to its natural Perl representation (i.e. as
though it were being displayed unformatted).

The format effector determines what data are inserted, and to a certain
extend how it is inserted. The effector names are word characters (i.e.
they match '\w'), and may not begin with a digit. Format effector names
may be abbreviated as long as that abbreviation is unique, but the
author can not and does not commit to maintaining the uniqueness of
abbreviations when more effectors are added.

The format effector arguments modify the operation of the format
effector in various ways, and are specified in parentheses after the
effector name. If no arguments are specified, the parentheses may be
omitted also. The following arguments are legal for all format effectors
unless otherwise stated in the documentation for a given effector:

 appulse - selects data from the appulsing body if any;
 body - selects data from the satellite;
 center - selects data from the flare center if any;
 missing - text to display if the datum is missing;
 station - selects data from the observing station;
 title - overrides the title of the field;
 units - specifies the units to display the data in.

Other arguments may be legal for specific effectors; these are
documented with the individual format effectors.

Argument names can be abbreviated, as long as those abbreviations are
unique. Again, the author can not and does not commit to keeping those
abbreviations unique if other arguments are added.

The 'body' argument is the default, and never needs to be specified. The
'appulse', 'body', and 'center' arguments are mutually exclusive, and
only one of the three may be specified.

Some of the format effectors normally display the position of the
satellite relative to the station. The 'station' argument swaps
satellite and station for the purpose of computing the display. This may
result in displaying the position of the station from the satellite (for
relative coordinates such as azimuth), or of the station itself (for
absolute coordinates such as latitude).

The 'missing' argument specifies text to be displayed if the datum
required for the template is unavailable. This defaults to an empty
string.

The 'title' argument overrides the title of the field. The desired title
is specified after an equals sign, and may not contain a comma. For
example:

 %elevation(title=degrees above horizon);

The 'units' argument specified the units in which to display the datum.
These must be both known to this formatter and valid for the dimension
of the datum. You can not, for example, request that the azimuth be
displayed in miles.

It is not an error to request information that is not available from the
formatted data. Missing information will be represented by blanking
the field, or replacing it with the 'missing' string if one was
specified.

How oversized data are handled depends on the type of data. String data
are truncated. If numeric data will not fit in the allowed field, the
field is filled with asterisks ('*') Fortran-style.

The following format effectors are implemented:

=head2 %almanac

This format effector displays almanac data. The decimal places
specification is ignored.

The C<appulse>, C<center>, and C<station> arguments are not supported.
All other standard arguments are supported.

The dimension is L</almanac_dimension>, which really sort of subverts
the dimension mechanism to let you display either the text description
of the almanac event, the event type, or the event code number.

The default field width is 40, and the default title is 'almanac'.

=head2 %altitude

This format effector displays the geodetic altitude of the body
specified by the argument above the geoid.

All standard arguments are supported.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 7, the default number of decimal places is 1,
and the default title is 'altitude'.

=head2 %angle

This format effector displays the value of the angle datum from the
L<flare()|/flare> method. If the C<appulse> argument is specified, it
displays the angle of appulse.

The C<center> and C<station> arguments are not supported. All other
standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 4, the default number of decimal places is 1,
and the default title is 'angle'.

=head2 %apoapsis

This format effector displays the apoapsis of the desired object's orbit
in kilometers. If the object does not support the apoapsis() method, the
field is blanked.

All standard arguments are supported. Additionally, the C<earth>
argument causes the apoapsis to be computed as distance from the center
of the Earth. Otherwise the equatorial radius of the Earth is
subtracted, to give (approximate) altitude.

The dimension is L<length|/length>. The default units are kilometers. If
the 'earth' argument is specified, the apoapsis is measured from the
center of the Earth; otherwise the equatorial radius of the Earth is
subtracted, to give (approximate) altitude.

The default field width is 6, the default number of decimal places is 0,
and the default title is 'apoapsis'.

=head2 %apogee

This format effector is a synonym for C<apoapsis>. The only difference
is that the default title is 'apogee'.

=head2 %argumentofperigee

This format effector displays the value of the 'argumentofperigee'
attribute of the desired object, in degrees. If the object does not
represent an L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object,
the field is blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 9, the default number of decimal places is 4,
and the default title is 'argument of perigee'.

=head2 %ascendingnode

This format effector displays the value of the 'ascendingnode' attribute
of the desired object. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are rightascension.

The default field width is 9, the default number of decimal places is 4,
and the default title is 'ascending node'.

=head2 %azimuth

This format effector displays the azimuth of the body from the station
(or of the station from the body if 'station' is specified).

All standard arguments are supported. In addition, the C<bearing>
argument is supported, which causes the equivalent compass bearing to be
appended to the numeric value. The value of the argument is the width of
the bearing field, defaulting to 2. This width plus 1 is added to the
width of the %azimuth field itself when laying out the output.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 5, the default number of decimal places is 1,
and the default title is 'azimuth'.

=head2 %bstardrag

This format effector displays the value of the 'bstardrag' attribute of
the desired object, in scientific notation. If the object does not
represent Astro::Coord::ECI::TLE, the field is blanked.

The C<units> argument is not supported. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 11, the default number of decimal places is
4, and the default title is 'B* drag'.

=head2 %classification

This format effector displays the value of the 'classification'
attribute of the desired object (typically 'U'). If the object does not
represent an L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object,
the field is blanked. The decimal places specification is ignored.

The C<units> argument is not supported. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 1, and the default title is blank.

=head2 %date

This format effector displays the date specified by the 'time' datum, in
the C<strftime()> format specified by the C<date_format> attribute. Note
that it is assumed that the C<date_format> will not display time of day,
but this assumption  is not enforced. The decimal places specification
is ignored.

The C<center> and C<station> arguments are not supported. All other
standard arguments are supported.

The dimension is L<date|/date>.

The default field width is computed when the 'date_format' attribute is
set, by doing some trial formats and checking the length of the output.
This should be sufficient in most cases, but if it does not in your
locale, you can always specify an explicit field width. You will
definitely have to specify a field width if you also specified
C<units=julian> or C<units=days_since_epoch>.

If the date is being displayed as an interval since the epoch, the
'appulse' or 'body' arguments specify the source of the epoch. If no
epoch is available from the specified source, the field will be empty.
If the date is being displayed in some form other than interval since
the epoch, the 'appulse' and 'body' arguments have no effect.

=head2 %declination

This format effector displays the declination of the body as seen from
the station (or of the station as seen from the body if 'station' is
specified).

All standard arguments are supported. In addition, the C<earth> argument
displays declination as seen from the center of the Earth, rather than
from the observing station.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 5, the default number of decimal places is 1,
and the default title is 'declination'.

=head2 eccentricity

This format effector displays the value of the 'eccentricity' attribute
of the desired object. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked.

All standard arguments are supported.

The dimension is L<dimensionless|/dimensionless>. The default units are
unity.

The default field width is 8, the default number of decimal places is
5, and the default title is 'eccentricity'.

=head2 %eci_x

This format effector displays the ECI X coordinate of the desired
object.

All standard arguments are supported.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 10, the default number of decimal places is
1, and the default title is 'eci x'.

=head2 %eci_y

This format effector displays the ECI Y coordinate of the desired
object.

All standard arguments are supported.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 10, the default number of decimal places is
1, and the default title is 'eci x'.

=head2 %eci_z

This format effector displays the ECI Z coordinate of the desired
object.

All standard arguments are supported.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 10, the default number of decimal places is
1, and the default title is 'eci x'.

=head2 %effective

This format effector displays the effective date of the TLE in whatever
format is specified by the L</date_format> and L</time_format>
attributes.  You will probably get strange output if the L</date_format>
format displays time or the L</time_format> format displays date. It is
not an error to specify the 'appulse', 'center' or 'station' arguments,
but you are unlikely to get anything but a blank field. You will also
get a blank field if the effective date has not been set.

All standard arguments are supported.

The dimension is L<date|/date>.

The default field width is computed whenever the L</date_format> or
L</time_format> attributes is set. If you specify 'units=julian' you
should specify an explicit field width and number of decimal places.

=head2 %elementnumber

This format effector displays the value of the 'elementnumber' attribute
of the desired object.  If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked. The decimal places specification is ignored.

The C<units> argument is not supported. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 4, and the default title is 'element set
number'.

=head2 %elevation

This format effector displays the elevation of the body as seen from the
station (or of the station as seen from the body if 'station' is
specified).

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 5, the default number of decimal places is 1,
and the default title is 'elevation'.

=head2 %ephemeristype

This format effector displays the value of the 'ephemeristype' attribute
of the desired object.  If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked. The decimal places specification is ignored.

The C<units> argument is not supported. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 1, and the default title is 'ephemeris type'.

=head2 %epoch

This format effector displays the epoch of the body in whatever format
is specified by the L</date_format> and L</time_format> attributes. You
will probably get strange output if the L</date_format> format displays
time or the L</time_format> format displays date. It is not an error to
specify the 'appulse', 'center' or 'station' arguments, but you are
unlikely to get anything but a blank field.

All standard arguments are supported, but C<units=days_since_epoch> is
forbidden, since it is always 0.

The dimension is L<date|/date>.

The default field width is computed whenever the L</date_format> or
L</time_format> attributes is set. If you specify C<units=julian> you
should specify an explicit field width and number of decimal places.

=head2 %event

This format effector displays the L<pass()|/pass> event. This is
expected to be an integer whose value is one of the
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> C<PASS_EVENT_*>
constants. The display is a string corresponding to that constant. This
will probably be empty unless it appears in a template which is used by
the L<pass()|/pass> method. The decimal places specification is ignored.

The C<appulse>, C<center>, C<station>, and C<units> arguments are
forbidden. All other standard arguments are supported.

There is no associated dimension.

The default field width is 5, and the default title is 'event'.

=head2 %firstderivative

This format effector displays the value of the 'firstderivative'
attribute of the desired object in degrees per minute squared, in
scientific notation. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>, which is incorrect; the true units are
angle per unit time squared. This means that you can get output in
radians per minute squared should you so desire, but not degrees per
second squared, since there is no mechanism to specify the units of the
denominator.

The default field width is 17, the default number of decimal places is
10, and the default title is as much of 'first derivative of mean
motion' as will fit.

=head2 %fraction_lit

This format effector displays the fraction of the desired body which is
lit. If the desired body does not implement the 'phase' method, the
field will be blanked.

All standard arguments are supported.

The dimension is L<dimensionless|/dimensionless>. The default units are
unity.

The default field width is 4, the default number of decimal places is 2,
and the default title is 'fraction lit'.

=head2 %id

This format effector displays the 'id' attribute of the desired body.
The decimal places specification is ignored.

The C<units> argument is forbidden. All other standard arguments are
allowed.

There is no associated dimension.

The default field width is 6, and the default title is 'id'.

=head2 %illumination

This format effector displays the value of the 'illumination' datum
passed to the the L<pass()|/pass> or C<position()|/position> methods,
which is encoded the same way as L<%event|/event>. The decimal
places specification is ignored.

The C<appulse>, C<center> and C<station> arguments are forbidden. All
other standard arguments are supported.

The dimension is L<dimensionless|/dimensionless>. The default units are
unity.

The default field width is 5, and the default title is 'illumination'.

=head2 %inclination

This format effector displays the value of the 'inclination' attribute
of the desired object. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 8, the default number of decimal places is 4,
and the default title is 'inclination'.

=head2 %international

This format effector displays the value of the 'international' attribute
of the desired object. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked. The decimal places specification is ignored.

The C<units> argument is forbidden. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 8, and the default title is as much of
'international launch designator' as will fit.

=head2 %latitude

This format effector displays the geodetic latitude of the selected
body.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 8, the default number of decimal places is 4,
and the default title is 'latitude'.

=head2 %longitude

This format effector displays the geodetic longitude of the selected
body.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 9, the default number of decimal places is 4,
and the default title is 'latitude'.

=head2 %magnitude

This format effector displays the 'magnitude' datum passed to the
L<flare()|/flare> method.

The C<appulse>, C<station>, and C<units> arguments are forbidden. All
other standard arguments are supported.

There is no associated dimension.

The default field width is 4, the default number of decimal places is 1,
and the default title is 'magnitude'.

=head2 %meananomaly

This format effector displays the value of the 'meananomaly' attribute
of the desired object. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 9, the default number of decimal places is 4,
and the default title is 'meananomaly'.

=head2 %meanmotion

This format effector displays the value of the 'meanmotion' attribute of
the desired object in degrees per minute. If the object does not
represent an L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object,
the field is blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>, which is incorrect since the true
units are angle per unit time. This means that you can get output in
radians per minute should you so desire, but not degrees per second,
since there is no mechanism to specify the units of the denominator.

The default field width is 12, the default number of decimal places is
10, and the default title is 'mean motion'.

=head2 %mma

This format effector displays the current value of the 'mma' datum
passed to the L<flare()|/flare> method. The decimal places
specification is ignored.

The C<appulse>, C<center>, C<station>, and C<units> arguments are
forbidden. All other standard arguments are supported.

There is no associated dimension.

The default field width is 3, and the default title is 'mma'.

=head2 %name

This format effector displays the name of the selected body. The decimal
places specification is ignored.

The C<units> argument is forbidden. All other standard arguments are
supported. If you specify C<missing=oid>, the object's ID will be
inserted if the name is not available. All other values for C<missing>
will be used verbatim if the name is not available.

There is no associated dimension.

The default field width is 24, and the default title is 'name'.

=head2 %operational

This format effector displays the operational status of the selected
body from its 'status' attribute. If the body does not support this
attribute, the field is blanked. The decimal places specification is
ignored.

The C<units> argument is forbidden. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 1, and the default title is blank.

=head2 %percent

This format effector displays a literal percent sign ('%'). It is only
needed in a context where the percent sign would otherwise be
interpreted as introducing a format effector. The decimal places
specification is ignored.

The C<appulse>, C<center>, C<station>, and C<units> arguments are
forbidden. All other standard arguments are supported.

There is no associated dimension.

The default field width is 1, and the default title is blank.

=head2 %periapsis

This format effector displays the periapsis of the desired object's
orbit in kilometers. If the object does not support the periapsis()
method, the field is blanked.

All standard arguments are supported. Additionally, the C<earth>
argument causes the periapsis to be computed as distance from the center
of the Earth. Otherwise the equatorial radius of the Earth is
subtracted, to give (approximate) altitude.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 6, the default number of decimal places is 0,
and the default title is 'periapsis'.

=head2 %perigee

This format effector is a synonym for C<periapsis>. The only difference
is that the default title is 'perigee'.

=head2 %period

This format effector displays the period of the desired object, in days
(if applicable), hours, minutes, and seconds. If the desired object does
not support the period() method, it displays blanks.

All standard arguments are supported.

The dimension is L<duration|/duration>. The default units are composite.

The default field width is 12, and the default title is 'period'.

=head2 %phase

This format effector displays the phase of the desired object, in
degrees. If the desired object does not support the phase() method, it
displays blanks.

All standard arguments are supported.

The dimension is L<angle|/angle>. The default units are degrees.

The default field width is 4, the default number of decimal places is 0,
and the default title is 'phase'.

=head2 %provider

This format effector displays the value of the provider attribute of the
formatter object. The decimal places specification is ignored.

The C<units> argument is forbidden. All other standard arguments are
supported.

The default field width is 0.

=head2 %range

This format effector displays the range from the station to the desired
object in.

All standard arguments are supported. If you specify C<station> the
range is computed in the opposite direction, but you get the same
number.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 10, the default number of decimal places is
1, and the default title is 'range'.

=head2 %revolutionsatepoch

This format effector displays the value of the 'revolutionsatepoch'
attribute of the desired object.  If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked. The decimal places specification is ignored.

The C<units> argument is forbidden. All other standard arguments are
supported.

There is no associated dimension.

The default field width is 6, and the default title is 'revolutions at
epoch'.

=head2 %right_ascension

This format effector displays the right ascension of the desired object.

All standard arguments are supported. In addition, the C<earth> argument
displays declination as seen from the center of the Earth, rather than
from the observing station. If C<earth> is not specified, specifying
C<station> displays the right ascension of the station as seen from the
desired object.

The dimension is L<angle|/angle>. The default units are rightascension
(i.e. hours, minutes, and seconds of right ascension).

If you specify a number of decimal places when displaying as hours,
minutes and seconds, it applies to the seconds field of the right
ascension, so %10.1right_ascension; would display something like (e.g.)
'10:23:45.3'.

The default field width is 8, the default number of decimal places is 0,
and the default title is 'right ascension'.

=head2 %secondderivative

This format effector displays the value of the 'secondderivative'
attribute of the desired object in degrees per minute cubed, in
scientific notation. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, the field is
blanked.

All standard arguments are supported.

The dimension is L<angle|/angle>, which is incorrect since the true
units are angle per unit time cubed. This means that you can get output
in radians per minute cubed should you so desire, but not degrees per
second cubed, since there is no mechanism to specify the units of the
denominator.

The default field width is 17, the default number of decimal places is
10, and the default title is as much of 'second derivative of mean
motion' as will fit.

=head2 %semimajor

This format effector displays the semimajor axis of the desired object's
orbit in kilometers. If the object does not support the semimajor()
method, the field is blanked.

All standard arguments are supported.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 6, the default number of decimal places is 0,
and the default title is 'semimajor axis'.

=head2 %semiminor

This format effector displays the semiminor axis of the desired object's
orbit in kilometers. If the object does not support the semiminor()
method, the field is blanked.

All standard arguments are supported.

The dimension is L<length|/length>. The default units are kilometers.

The default field width is 6, the default number of decimal places is 0,
and the default title is 'semimajor axis'.

=head2 %space

This format effector displays spaces. The decimal places specification
is ignored.

The C<appulse>, C<center>, C<station>, C<title>, and C<units> arguments
are forbidden. All other standard arguments are supported.

There is no associated dimension.

The default field width is 1, and the default title is blank.

=head2 %status

This format effector displays the string representing the status of a
potential Iridium flare. If this appears in a template not used by the
L<position()|/position> method, it will display blanks. The decimal
places specification is ignored.

The C<appulse>, C<center>, C<station>, and C<units> arguments are
forbidden. All other standard arguments are supported.

There is no associated dimension.

The default field width is 60, and the default title is 'status'.

=head2 %time

This format effector displays the time specified to the
L<flare()|/flare> or L<pass()|/pass> methods, in the C<strftime()> format
specified by the L<time_format|/time_format> attribute. Note that it is
assumed that this attribute will not display the date, but this
assumption  is not enforced.

The C<center> and C<station> arguments are forbidden. All other standard
arguments are supported.

The dimension is L<date|/date>. The default units are local unless the
L<gmt|App::Satpass2::Format/gmt> attribute is set.

The default field width is computed when the L<time_format|/time_format>
attribute is set, by doing some trial formats and checking the length of
the output.  This should be sufficient in most cases, but if it does not
in your locale, you can always specify an explicit field width. You will
definitely have to specify a field width if you also specified
C<units=julian> or C<units=days_since_epoch>.

If the time is being displayed as an interval since the epoch, the
C<appulse> or C<body> arguments specify the source of the epoch. If no
epoch is available from the specified source, the field will be empty.
If the time is being displayed in some form other than interval since
the epoch, the C<appulse> and C<body> arguments have no effect.

=head2 %tle

This format effector displays the value of the C<tle> attribute of the
desired object. If the object does not represent an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object or this
attribute is otherwise not available, the field is blanked. The decimal
places specification is ignored.

The C<units> argument is forbidden. All other standard arguments are
supported.

There is no associated dimension.

Note that the C<tle> attribute is an image of the TLE data used to
model the body, and so is a multiline field. Field widths will be
ignored. The title is blank.

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
L<%right_ascension|/%right_ascension>).

Typically the default field widths and decimal places are appropriate
for the default units, so if you specify different units you should
probably specify the field width and decimal places as well. Note that
for C<units=percent> (only available for quantities that are explicitly
dimensionless) the specified (or defaulted) field width will be
increased by 1 to accommodate the trailing '%'.

The dimensions are:

=head2 almanac_dimension

The first example is a case where the units mechanism was subverted to
select among alternate representations, rather than to convert between
physical units. The possible pseudo-units are:

description = the text description of the event;

event = the generic name of the event (e.g. 'horizon' for rise or set);

detail = the numeric event detail, whose meaning depends on the event
(e.g. for 'horizon', 1 is rise and 0 is set).

The default is 'description'.

=head2 angle

This dimension represents a geometric angle. The possible units are:

bearing = a compass bearing;

decimal	= a synonym for 'degrees';

degrees = angle in decimal degrees;

radians = angle in radians;

phase = name of phase ('new', 'waxing crescent', and so on);

rightascension = angle in hours, minutes, and seconds of rightascension.

The default is degrees, though this is overridden for
L<%right_ascension|/%right_ascension>.

=head2 date

This is another set of pseudo-units, which can be specified as follows:

local = local standard time;

gmt = Greenwich mean time;

julian = Greenwich mean time represented as Julian days and fractions;

universal = a synonym for 'gmt';

zulu = another synonym for 'gmt';

days_since_epoch = decimal days since the epoch of the body passed to
the formatter method, (or empty if there is none, or if it has no epoch
attribute).

The default is 'local', though setting the 'gmt' attribute of the
formatter changes this to 'gmt'.

=head2 dimensionless

A few displayed quantities are simply numbers, having no associated
physical dimension. These can be specified as:

percent = display as a percentage, with trailing '%'; one will be added
to the specified or adjusted field width to allow for the '%';

unity = display unaltered.

The default is 'unity'.

=head2 duration

This dimension represents a span of time, such as an orbital period. The
units are:

composite = days hours:minutes:seconds.fraction;

days = duration in days and fractions of days;

hours = duration in hours and fractions of hours;

minutes = duration in minutes and fractions of minutes;

seconds = duration in seconds and fractions of seconds.

The default is 'composite'.

=head2 length

This dimension represents lengths and distances. The possible units are:

feet = US/British feet;

foot = synonym for 'feet';

ft = synonym for 'feet';

kilometers = standard kilometers;

km = synonym for kilometers;

meters = standard meters;

m = synonym for 'meters';

miles = statute miles.

The default is 'kilometers'.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
