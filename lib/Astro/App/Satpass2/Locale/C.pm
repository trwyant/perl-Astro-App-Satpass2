package Astro::App::Satpass2::Locale::C;

use 5.008;

use strict;
use warnings;

use utf8;	# Not actually needed for C locale, but maybe for others

use Astro::Coord::ECI::TLE 0.059 qw{ :constants };
our $VERSION = '0.020_001';

my @event_names;
$event_names[PASS_EVENT_NONE]		= '';
$event_names[PASS_EVENT_SHADOWED]	= 'shdw';
$event_names[PASS_EVENT_LIT]		= 'lit';
$event_names[PASS_EVENT_DAY]		= 'day';
$event_names[PASS_EVENT_RISE]		= 'rise';
$event_names[PASS_EVENT_MAX]		= 'max';
$event_names[PASS_EVENT_SET]		= 'set';
$event_names[PASS_EVENT_APPULSE]	= 'apls';
$event_names[PASS_EVENT_START]		= 'strt';
$event_names[PASS_EVENT_END]		= 'end';
$event_names[PASS_EVENT_BRIGHTEST]	= 'brgt';

# Any hash reference is a true value, but perlcritic seems not to know
# this.

{	## no critic (Modules::RequireEndWithOne)
    '+message'	=> {
    },
    '+template'	=> {
    },
    '-flare'	=> {
	string	=> {
	    'Degrees From Sun'	=> 'Degrees From Sun',
	    'Center Azimuth'	=> 'Center Azimuth',
	    'Center Range'	=> 'Center Range',
	    'night'		=> 'night',
	},
    },
    '-location'	=> {
	string	=> {
	    'Location'		=> 'Location',
	    'Latitude'		=> 'Latitude',
	    'longitude'		=> 'longitude',
	    'height'		=> 'height',
	},
    },
    almanac	=> {
	title	=> 'Almanac',
	Moon	=> {
	    horizon	=> [ 'Moon set', 'Moon rise' ],
	    quarter	=> [
			    'New Moon',
			    'First quarter Moon',
			    'Full Moon',
			    'Last quarter Moon',
	    ],
	    transit	=> [ undef, 'Moon transits meridian' ],
	},
	Sun	=> {
	    horizon	=> [ 'Sunset', 'Sunrise' ],
	    quarter	=> [
			    'Spring equinox',
			    'Summer solstice',
			    'Fall equinox',
			    'Winter solstice',
	    ],
	    transit	=> [ 'local midnight', 'local noon' ],
	    twilight	=> [ 'end twilight', 'begin twilight' ],
	},
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
	table	=> [ @event_names ],
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
	localize_value	=> {
	    Sun		=> 'Sun',
	    Moon	=> 'Moon',
	},
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
	    [ 6.1	=> 'new' ],
	    [ 83.9	=> 'waxing crescent' ],
	    [ 96.1	=> 'first quarter' ],
	    [ 173.9	=> 'waxing gibbous' ],
	    [ 186.1	=> 'full' ],
	    [ 263.9	=> 'waning gibbous' ],
	    [ 276.1	=> 'last quarter' ],
	    [ 353.9	=> 'waning crescent' ],
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
};

__END__

=head1 NAME

Astro::App::Satpass2::Locale::C - Define the C locale for Astro::App::Satpass2

=head1 SYNOPSIS

 my $c_locale = require Astro::App::Satpass2::Locale::C;

=head1 DESCRIPTION

This Perl module defines the C locale (which is the default locale )for
L<Astro::App::Satpass2|Astro::App::Satpass2>.

All you do with this is load it. On a successful load it returns the
locale hash.

=head1 SUBROUTINES

None.

=head1 THE LOCALE DATA

The locale data are stored in a hash. The top-level key is always locale
code. This is either a two-character language code, lower-case (e.g.
C<'en'>, a language code and upper-case country code delimited by an
underscore (e.g. C<'en_US'>, or C<'C'> for the default locale.

The data for each locale key are a reference to a hash. The keys of this
hash are the names of
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
formats (e.g. C<{azimuth}>), the names of top-level reporting templates
preceded by a dash (e.g. C<{'-flare'}>, or the special keys
C<'{+message}'> (error messages) or C<'{+template}'> (templates).

The content of these second level hashes varies with its type, as
follows:

=head2 Format Effectors (e.g. C<{azimuth}>)

These are hashes containing data relevant to that format effector. The
C<{title}> key contains the title for that format effector. Other keys
relevant to the specific formatter may also appear, such as the
C<{table}> key in C<{phase}>, which defines the names of phases in terms
of phase angle. These extra keys are pretty much ad-hoc as required by
the individual format effector.

=head2 Top-level reporting (e.g. C<{'-flare'}>

The only key defined at the moment is C<{string}>, whose content is a
hash reference. This hash is keyed by text appearing as the values in
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
C<literal>, C<missing>, and C<title> arguments, and the corresponding
values are the translations of that text into the relevant locale.

For example, a Spanish localization for C<{'-flare'}> might be something
like

 {
   es => {
     string => {
       night => 'noche',
       ...
     }
   }
 }

=head2 C<{'+message'}>

The value of this key is a hash whose keys are message text as coded in
this program, and whose values are the message text as it should appear
in the relevant locale. These are typically to be consumed by the locale
system's C<__message()> subroutine.

=head2 C<{'+template'}>

The value of this key is a hash whose keys are template names used by
L<Astro::App::Satpass2::Format::Template|Astro::App::Satpass2::Format::Template>,
and whose values are the templates themselves in the relevant locale.

=head1 SEE ALSO

L<Astro::App::Satpass2::Locale|Astro::App::Satpass2::Locale>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
