package Astro::App::Satpass2::Locale::C;

use 5.008;

use strict;
use warnings;

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
