package App::Satpass2::ParseTime;

use strict;
use warnings;

use base qw{ App::Satpass2::Copier };

use Carp;
use Astro::Coord::ECI::Utils qw{ looks_like_number };

our $VERSION = '0.000_05';

sub new {
    my ( $class, @args ) = @_;
    ref $class and $class = ref $class;

    if ( __PACKAGE__ eq $class ) {

	@args = grep { defined $_ } @args;

	@args or @args = qw{
	    App::Satpass2::ParseTime::Date::Manip
	    App::Satpass2::ParseTime::ISO8601
	};

	$class = _try (
	    map { split qr{ \s+ }smx, $_ } @args )
	    or return;

    } else {
	$class = _try( $class )
	    or return;
    }

    my $self = {};
    bless $self, $class;
    $self->base( time );
    return $self;
}

sub attributes {
    my ( $self ) = @_;
    return ( $self->SUPER::attributes(), qw{ base perltime tz } );
}

sub base {
    my ( $self, @args ) = @_;
    if ( @args > 0 ) {
	$self->{base} = $self->{absolute} = $args[0];
	return $self;
    }
    return $self->{base};
}

sub delegate {
    my ( $self ) = @_;
    Carp::confess( 'The delegate() method must be overridden' );
}

{

    my @scale = ( 24, 60, 60, 1 );

    sub parse {
	my ( $self, $string, $default ) = @_;

	defined $string and '' ne $string or do {
	    defined $default and $self->{absolute} = $default;
	    return $default;
	};

	if ( $string =~ m/ \A \s* [+-] /smx ) {
	    defined $self->{base} or return;
	    defined $self->{absolute}
		or $self->{absolute} = $self->{base};
	    $string =~ s/ \A \s+ //smx;
	    $string =~ s/ \s+ \z //smx;
	    my $sign = substr $string, 0, 1;
	    substr( $string, 0, 1, '' );
	    my @delta = split qr{ \s* : \s* | \s+ }smx, $string;
	    @delta > 4 and return;
	    push @delta, ( 0 ) x ( 4 - @delta );
	    my $dt = 0;
	    foreach my $inx ( 0 .. 3 ) {
		looks_like_number( $delta[$inx] ) or return;
		$dt += $delta[$inx];
		$dt *= $scale[$inx];
	    }
	    '-' eq $sign and $dt = - $dt;
	    return ( $self->{absolute} = $dt + $self->{absolute} );

	} elsif ( $string =~
	    m/ \A epoch \s+ ( \d+ (?: [.] \d* )? ) \z /smx ) {

	    my $time = $1 + 0;
	    $self->{base} = $self->{absolute} = $time;
	    return $time;

	} else {

	    defined( my $time = $self->parse_time_absolute( $string ) )
		or return;
	    $self->{base} = $self->{absolute} = $time;
	    return $time;

	}

    }

}

sub parse_time_absolute {
    my ( $self, $string ) = @_;
    Carp::confess( 'parse_time_absolute() must be overridden' );
}

sub reset : method {	## no critic (ProhibitBuiltinHomonyms)
    my ( $self ) = shift;
    $self->{absolute} = $self->{base};
    return $self;
}

sub use_perltime {
    return 0;
}

{

    # %trial is indexed by class name. The value is the class to
    # delegate to (which can be the same as the class itself), or undef
    # if the class can not be loaded, or has no delegate.
    my %trial;

    sub _try {
	my ( @args ) = @_;

	my @flatten;

	while ( @args ) {

	    my $try = shift @args;

	    $trial{$try} and return $trial{$try};

	    exists $trial{$try} and next;

	    $try =~ m/ \A \w+ (?: :: \w+ )* \z /smx or do {
		$trial{$try} = undef;
		next;
	    };

	    local $@ = undef;
	    $trial{$try} = eval "require $try; 1" or next;

	    my $delegate = $trial{$try} = eval { $try->delegate() }
		or next;

	    if ( $trial{$delegate} ) {
		foreach ( @flatten ) {
		    $trial{$_} = $delegate;
		}
		return $delegate;
	    }

	    push @flatten, $try;
	    unshift @args, $delegate;
	}

	return;
    }
}

__PACKAGE__->create_attribute_methods();

1;

__END__

=head1 NAME

App::Satpass2::ParseTime - Parse time for App::Satpass2

=head1 SYNOPSIS

 my $pt = App::Satpass2::ParseTime->new();
 defined( my $epoch_time = $pt->parse( $string ) )
   or die "Unable to parse time '$string'";

=head1 NOTICE

This class and its subclasses are private to the
L<App::Satpass2|App::Satpass2> package. The author reserves the right to
add, change, or retract functionality without notice.

=head1 DETAILS

This class provides an interface to the possible time parsers. A
subclass of this class provides (or wraps) a parser, and exposes that
parser through a C<parse_time_absolute()> method.

There are actually three time formats supported by this parser.

Relative times begin with a '+' or a '-', and represent the number of
days, hours, minutes and seconds since (or before) the
most-recently-specified absolute time. The individual components (days,
hours, minutes and seconds) are separated by either colons or white
space. Trailing components (and separators) may be omitted, and default
to 0.

Epoch times are composed of the string 'epoch ' followed by a number,
and represent that time relative to Perl's epoch. It would have been
nice to just accept a number here, but it was impossible to disambiguate
a Perl epoch from an ISO-8601 time without punctuation.

Absolute times are anything not corresponding to the above. These are
the only times actually passed to L</parse_time_absolute>.

This class is a subclass if
L<App::Satpass2::Copier|App::Satpass2::Copier>.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $pt = App::Satpass2::ParseTime->new();

This method instantiates the parser. The actual returned class will be
the first that can be instantiated in the list
L<App::Satpass2::ParseTime::Date::Manip|App::Satpass2::ParseTime::Date::Manip>,
L<App::Satpass2::ParseTime::ISO8601|App::Satpass2::ParseTime::ISO8601>.

You can specify the list of parsers explicitly to C<new()> by passing
the parser short names (without the 'App::Satpass2::ParseTime::') as
arguments to C<new()>, either as a list or as a white-space-delimited
string. The default behavior is equivalent to

 my $pt = App::Satpass2::ParseTime->new( qw{ Date::Manip ISO8601 } );

or to

 my $pt = App::Satpass2::ParseTime->new( 'Date::Manip ISO8601' );

=head2 base

 $pt->base( time );    # Set base time to now
 $base = $pt->base();  # Retrieve current base time

This method is both accessor and mutator for the object's base time.
This time is used (indirectly) when the parse identifies a relative
time.

When called without arguments, it behaves as an accessor, and returns
the current base time setting.

When called with at least one argument, it behaves as a mutator, sets
the base time, and returns the C<$pt> object to allow call chaining.

Subclasses B<may> override this method, but if they do so they B<must>
call C<SUPER::> with the same arguments they themselves were called
with, and return whatever C<SUPER::> returns.

=head2 delegate

 my $delegate = $class->delegate()

This static method returns the name of the class to be instantiated.
Normally a subclass will return its own class name, but if there is more
than one possible wrapper for a given parser (e.g.
L<Date::Manip|Date::Manip>, which gets handled differently based on its
version number), the wrapper should return the name of the desired
class.

This method B<must> be overridden by any subclass.

=head2 copy

 $pt->copy( $copy );

This method copies the values of all attributes (C<base>, C<perltime>,
and C<tz>) to the object passed in the argument. The target object may
be of a different class than the source object, but must support the
given mutator methods.

=head2 parse_time_absolute

 $epoch_time = $pt->parse_time_absolute( $string );

This method parses an absolute time string. It returns seconds since the
epoch, or C<undef> on error.

This method B<must> be overridden by any subclass.

=head2 perltime

 $pt->perltime( 1 );            # Turn on the perltime hack
 $perltime = $pt->perltime();	# Find out whether the hack is on

This method is both accessor and mutator for the object's perltime flag.
This is boolean flag which the subclass may (or may not!) use to get the
summer time straight when parsing time. If the flag is on (and the
subclass supports it) the tz setting is ignored, and an attempt to
specify a time zone in a time to be parsed will produce undefined
results.

When called without arguments, it behaves as an accessor, and returns
the current perltime flag setting.

When called with at least one argument, it behaves as a mutator, sets
the perltime flag, and returns the C<$pt> object to allow call chaining.

This specific method simply records the C<perltime> setting.

Subclasses B<may> override this method, but if they do so they B<must>
call C<SUPER::> with the same arguments they themselves were called
with, and return whatever C<SUPER::> returns.

=head2 parse

 defined( $epoch_time = $pt->parse( $string ) )
   or die "'$string' can not be parsed.";

This method parses a time, returning the resultant Perl time. If the
string fails to parse, C<undef> is returned.

=head2 reset

 $pt->reset();

This method resets the base time for relative times to the value of the
C<base> attribute. It returns the C<$pt> object to allow for call
chaining.

=head2 use_perltime

 $classname->use_perltime()

This static method returns true if the class uses the C<perltime>
mechanism, and false otherwise.

This specific class simply returns false.

Subclasses may override this method, but if they do they B<must not>
call C<SUPER::>.

=head2 tz

 $pt->tz( 'EST5EDT' );          # Specify an explicit time zone
 $pt->tz( undef );              # Specify the default time zone
 $tz = $pt->tz();               # Find out what the time zone is

This method is both accessor and mutator for the object's time zone
setting. What can go here depends on the specific subclass in use.

When called without arguments, it behaves as an accessor, and returns
the current time zone setting.

When called with at least one argument, it behaves as a mutator, sets
the time zone, and returns the C<$pt> object to allow call chaining.

This specific method simply records the C<tz> setting.

Subclasses B<may> override this method, but if they do so they B<must>
call C<SUPER::> with the same arguments they themselves were called
with, and return whatever C<SUPER::> returns. Also, overrides B<must>
interpret an C<undef> argument as a request to set the default time
zone, not as an accessor call.

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
