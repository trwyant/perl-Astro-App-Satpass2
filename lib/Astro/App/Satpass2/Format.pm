package Astro::App::Satpass2::Format;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Copier };

use Carp;
use Clone ();
use Astro::App::Satpass2::FormatTime;
use Astro::App::Satpass2::Utils qw{ load };

our $VERSION = '0.000_07';

use constant DEFAULT_LOCAL_COORD => 'azel_rng';

# Note that the fact that new() works when called from
# Astro::App::Satpass2::Test is unsupported and undocumented, and the
# functionality may be revoked or changed without warning.

my %static = (
    desired_equinox_dynamical => 0,
    gmt		=> 0,
    header	=> 1,
    local_coord	=> DEFAULT_LOCAL_COORD,
    provider	=> 'Astro::App::Satpass2',
);

sub new {
    my ( $class, %args ) = @_;
    ref $class and $class = ref $class;
    $class eq __PACKAGE__
	and 'Astro::App::Satpass2::Test' ne caller
	and croak __PACKAGE__, ' may not be instantiated. ',
	    'Use a subclass';
    my $self = { %static };
    bless $self, $class;
    exists $args{tz} or $args{tz} = $ENV{TZ};
    $self->time_formatter( delete $args{time_formatter} );
    $args{date_format}
	or $self->date_format( $self->time_formatter()->DATE_FORMAT() );
    $args{time_format}
	or $self->time_format( $self->time_formatter()->TIME_FORMAT() );
    while ( my ( $name, $value ) = each %args ) {
	$self->can( $name ) or croak "Method '$name' does not exist";
	$self->$name( $value );
    }
    return $self;
}

sub attribute_names {
    my ( $self ) = @_;
    return ( $self->SUPER::attribute_names(),
	qw{ date_format desired_equinox_dynamical gmt
	    header local_coord provider time_format time_formatter tz
	} );
}

{

    my %original_value = (
	date_format	=> sub {
	    return $_[0]->time_formatter()->DATE_FORMAT()
	},
	time_format	=> sub {
	    return $_[0]->time_formatter()->TIME_FORMAT()
	},
    );

    foreach my $key ( keys %static ) {
	$original_value{ $key } ||= sub {
	    return $static{$key};
	};
    }

    sub config {
	my ( $self, %args ) = @_;
	my @data;

	foreach my $name ( $self->attribute_names() ) {
	    my $val = $self->$name();
	    no warnings qw{ uninitialized };
	    next if $args{changes} &&
		$val eq ( $original_value{$name} ?
		    $original_value{$name}->( $self, $name ) :
		    undef );
	    push @data, [ $name, $args{decode} ? $self->decode( $name )
		: $val ];
	}

	return wantarray ? @data : \@data;
    }

}

{

    my %decoder = (
	desired_equinox_dynamical => sub {
	    my ( $self, $method, @args ) = @_;
	    my $rslt = $self->$method( @args );
	    @args and return $rslt;
	    $rslt or return $rslt;
	    return $self->{time_formatter}->strftime(
		$self->{time_formatter}->ISO_8601_FORMAT(),
		$rslt, 1 );
	},
	time_formatter => sub {
	    my ( $self, $method, @args ) = @_;
	    my $rslt = $self->$method( @args );
	    @args and return $rslt;
	    return ref $rslt || $rslt;
	},
    );

    sub decode {
	my ( $self, $method, @args ) = @_;
	my $dcdr = $decoder{$method}
	    or return $self->$method( @args );
	my $type = ref $dcdr
	    or confess "Programming error -- decoder for $method is scalar";
	'CODE' eq $type
	    and return $dcdr->( $self, $method, @args );
	confess "Programming error -- decoder for $method is $type";
    }
}

sub local_coord {
    my ( $self, @args ) = @_;
    if ( @args ) {
	defined $args[0] or $args[0] = DEFAULT_LOCAL_COORD;
	$self->{local_coord} = $args[0];
	return $self;
    } else {
	return $self->{local_coord};
    }
}

sub time_formatter {
    my ( $self, @args ) = @_;
    if ( @args ) {
	my $fmtr = $args[0];
	defined $fmtr and $fmtr ne ''
	    or $fmtr = 'Astro::App::Satpass2::FormatTime';
	ref $fmtr or do {
	    my $class = load( $fmtr,
		'Astro::App::Satpass2::FormatTime' )
		or croak "Can not load $fmtr";
	    $fmtr = $class->new();
	};
	my $old = $self->{time_formatter}
	    and $self->{time_formatter}->copy( $fmtr );
	$self->{time_formatter} = $fmtr;
	if ( ! $old || $old->FORMAT_TYPE() ne $fmtr->FORMAT_TYPE() ) {
	    $self->date_format( $fmtr->DATE_FORMAT() );
	    $self->time_format( $fmtr->TIME_FORMAT() );
	}
	return $self;
    } else {
	return $self->{time_formatter};
    }
}

sub tz {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->{tz} = $args[0];
	return $self;
    } else {
	return $self->{tz};
    }
}

__PACKAGE__->create_attribute_methods();

1;

=head1 NAME

Astro::App::Satpass2::Format - Format Astro::App::Satpass2 output

=head1 SYNOPSIS

No user-serviceable parts inside.

=head1 DETAILS

This formatter is an abstract class providing output formatting
functionality for L<Astro::App::Satpass2|Astro::App::Satpass2>. It should not be
instantiated directly.

This class is a subclass of
L<Astro::App::Satpass2::Copier|Astro::App::Satpass2::Copier>.

=head1 METHODS

This class supports the following public methods:

=head2 Instantiator

=head3 new

 $fmt = Astro::Satpass::Format::Some_Subclass_Thereof->new(...);

This method instantiates a formatter. It may not be called on this
class, but may be called on a subclass. If you wish to modify the
default attribute values you can pass the relevant name/value pairs as
arguments. For example:

 $fmt = Astro::Satpass::Format::Some_Subclass_Thereof->new(
     date_format => '%Y%m%d',
     time_format => 'T%H:%M:%S',
 );

=head2 Accessors and Mutators

=head3 date_format

 print 'Date format: ', $fmt->date_format(), "\n";
 $fmt->date_format( '%d-%b-%Y' );

The C<date_format> attribute is maintained on behalf of subclasses of
this class, which B<may> (but need not) use it to format dates. This
method B<may> be overridden by subclasses, but the override B<must> call
C<SUPER::date_format>, and return values consistent with the following
description.

This method acts as both accessor and mutator for the C<date_format>
attribute. Without arguments it is an accessor, returning the current
value of the C<date_format> attribute.

If passed an argument, that argument becomes the new value of
C<date_format>, and the object itself is returned so that calls may be
chained.

The interpretation of the argument is up to the subclass, but
it is recommended for sanity's sake that the subclasses interpret this
value as a C<POSIX::strftime> format producing a date (but not a time),
if they use this attribute at all.

The default value, if used by the subclass at all, should produce a
numeric date of the form year-month-day. For formatters that use
C<strftime()>, this will be '%Y-%m-%d'.

B<Note> that this value will be reset to its default if the
L<time_formatter|/time_formatter> attribute is modified and the new
object has a different C<FORMATTER_TYPE()> than the old one.

=head3 desired_equinox_dynamical

 print 'Desired equinox: ',
     strftime( '%d-%b-%Y %H:%M:%S dynamical',
         gmtime $fmt->desired_equinox_dynamical() ),
     "\n"; 
 $fmt->desired_equinox_dynamical(
     timegm( 0, 0, 12, 1, 0, 100 ) );	# J2000.0

The C<desired_equinox_dynamical> attribute is maintained on behalf of
subclasses of this class, which B<may> (but need not) use it to
calculate inertial coordinates. If the subclass does not make use of
this attribute it B<must> document the fact.

This method B<may> be overridden by subclasses, but the override B<must>
call C<SUPER::desired_equinox_dynamical>, and return values consistent
with the following description.

This method acts as both accessor and mutator for the
C<desired_equinox_dynamical> attribute. Without arguments it is an
accessor, returning the current value of the
C<desired_equinox_dynamical> attribute.

If passed an argument, that argument becomes the new value of
C<desired_equinox_dynamical>, and the object itself is returned so that
calls may be chained.

The interpretation of the argument is up to the subclass, but it is
recommended for sanity's sake that the subclasses interpret this value
as a dynamical time (even though it is represented as a normal Perl
time) if they use this attribute at all. If the value is true (in the
Perl sense) inertial coordinates should be precessed to the dynamical
time represented by this attribute. If the value is false (in the Perl
sense) they should not be precessed.

=head3 gmt

 print 'Time zone: ', ( $fmt->gmt() ? 'GMT' : 'local' ), "\n";
 $fmt->gmt( 1 );

The C<gmt> attribute is maintained on behalf of subclasses of this
class, which B<may> (but need not) use it to decide whether to display
dates in GMT or in the local time zone. This method B<may> be overridden
by subclasses, but the override B<must> call C<SUPER::gmt>, and return
values consistent with the following description.

This method acts as both accessor and mutator for the C<gmt>
attribute. Without arguments it is an accessor, returning the current
value of the C<gmt> attribute. This value is to be interpreted as a
Boolean under the usual Perl rules.

If passed an argument, that argument becomes the new value of
C<gmt>, and the object itself is returned so that calls may be
chained.

=head3 header

 print 'Headers are ', $fmt->header(), "on\n" : "off\n";
 $fmt->header( 0 );

The C<header> attribute is maintained on behalf of subclasses of this
class, which B<may> (but need not) use it to decide whether to display
header information before the actual data. This method B<may> be
overridden by subclasses, but the override B<must> call
C<SUPER::header>, and return values consistent with the following
description.

This method acts as both accessor and mutator for the C<header>
attribute. Without arguments it is an accessor, returning the current
value of the C<header> attribute. This value is to be interpreted as a
Boolean under the usual Perl rules.

If passed an argument, that argument becomes the new value of C<header>,
and the object itself is returned so that calls may be chained.

=head3 local_coord

 print 'Local coord: ', $fmt->local_coord(), "\n";
 $fmt->local_coord( 'azel_rng' );

The C<local_coord> attribute is maintained on behalf of subclasses of
this class, which B<may> (but need not) use it to determine what
coordinates to display. This method B<may> be overridden by subclasses,
but the override B<must> call C<SUPER::local_coord>, and return values
consistent with the following description.

This method acts as both accessor and mutator for the C<local_coord>
attribute. Without arguments it is an accessor, returning the current
value of the C<local_coord> attribute.

If passed an argument, that argument becomes the new value of
C<local_coord>, and the object itself is returned so that calls may be
chained. The interpretation of the argument is up to the subclass, but
it is recommended for sanity's sake that the subclasses support at least
the following values if they use this attribute at all:

 az_rng --------- azimuth and range;
 azel ----------- azimuth and elevation;
 azel_rng ------- azimuth, elevation and range;
 equatorial ----- right ascension and declination;
 equatorial_rng - right ascension, declination and range.

It is further recommended that C<azel_rng> be the default.

=head3 provider

 print 'Provider: ', $fmt->provider(), "\n";
 $fmt->provider( 'Astro::App::Satpass2 v' . Astro::App::Satpass2->VERSION() );

The C<provider> attribute is maintained on behalf of subclasses of this
class, which B<may> (but need not) use it to identify the provider of
the data for informational purposes. This method B<may> be overridden by
subclasses, but the override B<must> call C<SUPER::provider>, and return
values consistent with the following description.

This method acts as both accessor and mutator for the C<provider>
attribute. Without arguments it is an accessor, returning the current
value of the C<provider> attribute.

If passed an argument, that argument becomes the new value of
C<provider>, and the object itself is returned so that calls may be
chained.

=head3 time_format

 print 'Time format: ', $fmt->time_format(), "\n";
 $fmt->time_format( '%H:%M:%S' );

The C<time_format> attribute is maintained on behalf of subclasses of
this class, which B<may> (but need not) use it to format times. This
method B<may> be overridden by subclasses, but the override B<must> call
C<SUPER::time_format>, and return values consistent with the following
description.

This method acts as both accessor and mutator for the C<time_format>
attribute. Without arguments it is an accessor, returning the current
value of the C<time_format> attribute.

If passed an argument, that argument becomes the new value of
C<time_format>, and the object itself is returned so that calls may be
chained.

The interpretation of the argument is up to the subclass, but
it is recommended for sanity's sake that the subclasses interpret this
value as a C<POSIX::strftime> format producing a time (but not a date),
if they use this attribute at all.

The default value, if used by the subclass at all, should produce a
numeric time of the form hour:minute:second. For formatters that use
C<strftime()>, this will be '%H:%M:%S'.

B<Note> that this value will be reset to its default if the
L<time_formatter|/time_formatter> attribute is modified and the new
object has a different C<FORMATTER_TYPE()> than the old one.

=head3 time_formatter

This method acts as both accessor and mutator for the object used to
format times. It will probably be a
L<Astro::App::Satpass2::FormatTime|Astro::App::Satpass2::FormatTime>
object of some sort, and will certainly conform to that interface. When
setting the value, you can specify either a class name or an object. If
a class name, the leading C<Astro::App::Satpass2::FormatTime::> can be
omitted.

B<Note> that setting this will reset the L<date_format|/date_format> and
L<time_format|/time_format> attributes to values appropriate to the
new time formatter's class, if the new formatter object has a different
C<FORMATTER_TYPE()> than the old one.

=head3 tz

 print 'Time zone: ', $fmt->tz()->name(), "\n";
 $fmt->tz( 'MST7MDT' );

The C<tz> attribute is maintained on behalf of subclasses of this class,
which B<may> (but need not) use it to format times. This method B<may>
be overridden by subclasses, but the override B<must> call C<SUPER::tz>,
and return values consistent with the following description.

This method acts as both accessor and mutator for the C<tz> attribute.
Without arguments it is an accessor, returning the current value of the
C<tz> attribute.

If passed an argument, that argument becomes the new value of C<tz>, and
the object itself is returned so that calls may be chained.

If no argument is passed, the current value of C<tz> is returned.

The use of the argument is up to the subclass, but it is
recommended for sanity's sake that the subclasses interpret this value
as a time zone to be used to derive the local time if they use this
attribute at all.

A complication is that subclasses may need to validate zone values. It
is to be hoped that their digestions will be rugged enough to handle the
usual conventions, since convention rather than standard seems to rule
here.

=head2 Formatters

These methods are intended to take raw data produced by various methods
of L<Astro::Coord::ECI|Astro::Coord::ECI> and its subclasses, and turn
them into text. Subclasses B<should> override these. The overrides
B<must not> call the superclass' method, because in general there isn't
one.

The formatters are named after the L<Astro::App::Satpass2|Astro::App::Satpass2>
methods they are intended to serve. In general, they take a single
argument, format it as a string, and return the string.  If there is no
argument, or if the argument is undefined, they should return the
desired column headers or similar information as and if appropriate.
They may also use a missing or undefined argument as a signal to
initialize themselves, if that is necessary.

=head3 almanac

 print $fmt->almanac();
 print $fmt->almanac( $almanac_hash );

This method is intended to format an almanac entry for the
L<almanac|Astro::App::Satpass2/almanac> and L<quarters|Astro::App::Satpass2/quarters>
commands. Its argument is a hash reference, which is presumed to be
output from the C<almanac_hash()> method of such
L<Astro::Coord::ECI|Astro::Coord::ECI> subclasses that have such a
method.

=head3 flare

 print $fmt->flare( $flare_hash );

This method is intended to format an Iridium flare for the
L<flare|Astro::App::Satpass2/flare> command. Its argument is a
hash reference, which is presumed to be output from the
L<Astro::Coord::ECI::TLE::Iridium|Astro::Coord::ECI::TLE::Iridium>
C<flare()> method.

=head3 list

 print $fmt->list( $body );

This method is intended to format a brief description for the
L<list|Astro::App::Satpass2/list> command. Its argument is presumed to be an
L<Astro::Coord::ECI|Astro::Coord::ECI> object. This description should
be appropriate for a satellite.

=head3 location

 print $fmt->location( $station );

This method is intended to format a brief description for the
L<location|Astro::App::Satpass2/location> command. Its argument is presumed to
be an L<Astro::Coord::ECI|Astro::Coord::ECI> object. This description
should be appropriate for a ground station.


=head3 pass

 print $fmt->pass( $pass );

This method is intended to format a description of a satellite pass for
the L<pass|Astro::App::Satpass2/pass> command. Its argument is presumed to be
one of the hash references returned by the
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> C<pass()> method.

=head3 phase

 print $fmt->phase( $phase_info );

This method is intended to format a description of the phase of a body
for the L<phase|Astro::App::Satpass2/phase> command.  Its argument is presumed
to be the hash reference returned by the C<phase()> method of such
subclasses of C<Astro::Coord::ECI|Astro::Coord::ECI> that have such a
method.

=head3 position

 print $fmt->position( \%hash );

This method is intended to format the position of the body, and possibly
other data, for the L<position|Astro::App::Satpass2/position> command. Its
argument is a hash containing relevant data. The following hash keys are
required:

 {body} - the satellite or other body whose position is to be given
 {station} - the observing station.

Both required hash keys must contain
L<Astro::Coord::ECI|Astro::Coord::ECI> objects, and the C<{body}> must
have its time set to the desired time.

In addition, the following keys are recommended:

 {questionable} - do flare calculations for questionable sources;
 {sun} - the Sun, with its time set the same as {body};
 {twilight} - twilight, in radians (negative).

Yes, this is more complex than the others, but the function is more
ad-hoc.

=head3 tle

 print $fmt->tle( $body );

This method is intended to format the TLE of a body for the
L<tle|Astro::App::Satpass2/tle> command. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object.

=begin comment

# TODO when the code works, _tle_celestia loses its leading underscore.
# =head3 _tle_celestia

 print $fmt->tle_celestia( $body );

This method is intended to format the TLE data for a body appropriately
for input to the Celestia program. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object.

This method is also unsupported because I have not yet gotten results
that put the International Space Station where it actually is.

=end comment

=head3 tle_verbose

 print $fmt->tle_verbose( $body );

This method is intended to format the TLE data of a body for the
L<tle|Astro::App::Satpass2/tle> command with C<-verbose> specified. The output
is expected to be a labeled dump. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object.

=head2 Other Methods

The following other methods are provided.

=head3 config

 use YAML;
 print Dump ( $pt->config( changes => 1 );

This method retrieves the configuration of the formatter as an array of
array references. The first element of each array reference is a method
name, and the subsequent elements are arguments to that method. Calling
the given methods with the given arguments should reproduce the
configuration of the formatter. If called in scalar context, it returns
a reference to the array.

There are two named arguments:

=over

=item changes

If this boolean argument is true (in the Perl sense), only changes from
the default configuration are reported.

=item decode

If this boolean argument is true (in the Perl sense), the
L<decode()|/decode> method is used to obtain the configuration values.

=back

Subclasses that add other ways to configure the object B<must> override
this method. The override B<must> call C<SUPER::config()>, and include
the result in the returned data.

=head2 decode

 $fmt->decode( 'desired_equinox_dynamical' );

This method wraps other methods, converting their returned values to
human-readable. The arguments are the name of the method, and its
arguments if any. The return values of methods not explicitly documented
below are not modified.

The following methods return something different when invoked via this
method:

=over

=item desired_equinox_dynamical

If called as an accessor, the returned time is converted to an ISO-8601
time in the GMT zone. If called as a mutator, you still get back the
object reference.

=item time_formatter

If called as an accessor, the class name of the object being used to
format the time is returned. If called as a mutator, you still get back
the object reference.

=back

If a subclass overrides this method, the override should either perform
the decoding itself, or delegate to C<SUPER::decode>.

=head1 SEE ALSO

L<Astro::App::Satpass2|Astro::App::Satpass2>, which is the intended user of this
functionality.

L<Astro::Coord::ECI|Astro::Coord::ECI> and associated modules, which are
the intended providers of data for this functionality.

L<Astro::App::Satpass2::Format::Classic|Astro::App::Satpass2::Format::Classic>, which
is a subclass of this module. It is a templating system producing text
output which, by default, resembles the output of the original satpass
script.

L<Astro::App::Satpass2::Format::Dump|Astro::App::Satpass2::Format::Dump>, which is a
subclass of this module. It is intended for debugging, and simply dumps
its arguments in Data::Dumper, JSON, or YAML format depending on how it
is configured and what modules are installed

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2011 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
