package Astro::App::Satpass2::ParseTime::ISO8601;

use strict;
use warnings;

use Astro::App::Satpass2::Utils qw{ __reform_date };
use Astro::Coord::ECI::Utils 0.059 qw{ looks_like_number SECSPERDAY };
use Time::Local;

use base qw{ Astro::App::Satpass2::ParseTime };

our $VERSION = '0.031_002';

{
    local $@ = undef;

    use constant HAVE_DATETIME => eval {
	require DateTime;
	1;
    } || 0;

    use constant HAVE_JULIAN_SUPPORT => eval {
	require DateTime::Calendar::Christian;
	1;
    } || 0;

}

my $zone_re = qr{ (?i: ( Z | UT | GMT ) |
    ( [+-] ) ( \d{1,2} ) :? ( \d{1,2} )? ) }smx;

sub delegate {
    return __PACKAGE__;
}

{

    my %special_day_offset = (
	yesterday => -SECSPERDAY(),
	today => 0,
	tomorrow => SECSPERDAY(),
    );

    my $era_ad = sub { return $_[0] };
    my $era_bc = sub { return 1 - $_[0] };
    my %era_cvt = (
	AD	=> $era_ad,
	BC	=> $era_bc,
	BCE	=> $era_bc,
	CE	=> $era_ad,
    );

    # Note that we have to reverse sort the keys because otherwise 'BC'
    # gets matched before we have a chance to try 'BCE'.
    my $era_re = qr< (?: @{[
	join ' | ', reverse sort keys %era_cvt
    ]} ) >smxi;

    my $make_epoch = HAVE_DATETIME ? sub {
	my ( $self, $zone, $offset, @date ) = @_;
	$zone ||= 'local';
	if ( defined( my $special = $special_day_offset{$date[0]} ) ) {
	    my $dt = DateTime->today(
		time_zone	=> $zone,
	    );
	    splice @date, 0, 3, $dt->year(), $dt->month(), $dt->day();
	    $offset += $special;
	}
	my %dt_arg;
	@dt_arg{ qw<
	    year month day hour minute second nanosecond
	> } = @date;
	$dt_arg{nanosecond} *= 1_000_000_000;
	$dt_arg{time_zone} = $zone;
	$self->{_reform_date}
	    and return DateTime::Calendar::Christian->new(
		%dt_arg,
		reform_date	=> $self->{_reform_date},
	    )->epoch() + $offset;
	return DateTime->new( %dt_arg )->epoch() + $offset;
    } : sub {
	my ( undef, $zone, $offset, @date ) = @_;
	if ( defined( my $special = $special_day_offset{$date[0]} )
	    ) {
	    my @today = $zone ? gmtime : localtime;
	    splice @date, 0, 3, @today[ 5, 4, 3 ];
	    $date[0] += 1900;
	    $offset += $special;
	} else {
	    --$date[1];
	}
	$offset += pop @date;
	if ( $zone ) {
	    return timegm( reverse @date ) + $offset;
	} else {
	    return timelocal( reverse @date ) + $offset;
	}
    };

    sub parse_time_absolute {
	my ( $self, $string ) = @_;

	my @date;

	my $special_only;

	# ISO 8601 date
	if ( $string =~ m< \A
		( ( [0-9]+ ) \s* ( $era_re ) [^0-9]? |	# year $1, $2 era $3
		    [0-9]{4} [^0-9]? |
		    [0-9]+ [^0-9] )
		(?: ( [0-9]{1,2} ) [^0-9]?		# month: $4
		    (?: ( [0-9]{1,2} ) [^0-9]?		# day: $5
		    )?
		)?
	    >smxg ) {

	    if ( $3 ) {
		@date = ( $era_cvt{ uc $3 }->( $2 + 0 ), $4, $5 );
	    } else {
		@date = ( $1, $4, $5 );
		$date[0] =~ s/ [^0-9] \z //smx;
		$date[0] < 70
		    and $date[0] += 2000;
		$date[0] < 100
		    and $date[0] += 1900;
	    }

	    defined $date[1]
		or $date[1] = 1;
	    defined $date[2]
		or $date[2] = 1;

	# special-case 'yesterday', 'today', and 'tomorrow'.
	} elsif ( $string =~ m{ \A
	    ( yesterday | today | tomorrow ) \b [^0-9]?	# day: $1
	    }smxgi ) {
	    # Handle this when we make the epoch, since we do not yet
	    # know the zone.
	    @date = ( lc $1, 0, 0 );
	    $special_only = 1;

	} else {

	    return;

	}

	if ( $string =~ m< \G
		( [0-9]{1,2} ) [^0-9+-]?		# hour: $1
		(?: ( [0-9]{1,2} ) [^0-9+-]?		# minute: $2
		    (?: ( [0-9]{1,2} ) [^0-9+-]?	# second: $3
			( [0-9]* )			# fract: $4
		    )?
		)?
	    >smxgc ) {
	    push @date, $1, $2 || 0, $3 || 0, $4 ? ".$4" : 0;
	    $special_only = 0;
	} else {
	    push @date, ( 0 ) x 4;
	}

	# We might have gobbled part of the zone.
	not $special_only
	    and $string =~ m/ \G (?<= [^0-9] ) /smxgc
	    and pos $string -= 1;
	my ( $zone ) = $string =~ m/ \G ( .* ) /smxgc;

	my ( $z, $offset ) = $self->_interpret_zone( $zone );
	defined $offset
	    or return;

	return $make_epoch->( $self, $z, $offset, @date );
    }

}

sub _interpret_zone {
    my ( $self, $zone, $fatal ) = @_;
    defined $zone
	and $zone =~ s/ \A \s+ //smx;
    $zone
	or return ( @{ $self->{ __PACKAGE__() }{tz} || [ undef, 0 ] } );
    if ( $zone =~ m/ \A $zone_re \z /smxo ) {
	$1
	    and return ( UTC => 0 );
	my $offset = ( ( $3 || 0 ) * 60 + ( $4 || 0 ) ) * 60;
	$2
	    and '-' eq $2
	    or $offset = - $offset;
	return ( UTC => $offset );
    } else {
	HAVE_DATETIME
	    and DateTime::TimeZone->is_valid_name( $zone )
	    and return ( $zone => 0 );
	$fatal
	    and $self->warner()->wail( "Invalid time zone '$zone'" );
	return;
    }
}

sub reform_date {
    my ( $self, @args ) = @_;
    if ( @args ) {
	not $args[0]
	    or HAVE_JULIAN_SUPPORT
	    or $self->warner()->wail(
	    'No reform date support without DateTime::Calendar::Christian' );
	( $args[0], $self->{_reform_date} ) = __reform_date( $args[0] );
    }
    return $self->SUPER::reform_date( @args );
}

sub tz {
    my ( $self, @args ) = @_;
    if ( @args ) {
	if ( defined $args[0] && $args[0] ne '' ) {
	    $self->{ __PACKAGE__() }{tz} = [
		$self->_interpret_zone( $args[0], 1 ) ];
	} else {
	    delete $self->{ __PACKAGE__() }{tz};
	}
    }
    return $self->SUPER::tz( @args );
}

1;

=head1 NAME

Astro::App::Satpass2::ParseTime::ISO8601 - Astro::App::Satpass2 minimal ISO-8601 parser

=head1 SYNOPSIS

No user-serviceable parts inside.

=head1 DETAILS

This class parses ISO-8601 dates. It does not do ordinal days or weeks,
but it is rather permissive on punctuation, and permits the convenience
dates C<'yesterday'>, C<'today'>, and C<'tomorrow'>.

This class understands ISO-8601 time zone specifications of the form
'Z', 'UT', 'GMT' and C<[+-]\d{1,2}:?\d{,2}>, but it knows nothing about
shifts for summer time. So C<2009/7/1 12:00:00 -5> is 5:00 PM GMT, not
4:00 PM. An attempt to set any other time zone will result in a warning,
and the system default zone being used.

As an extension to the ISO-8601 standard, years can be followed by an
era specification, which is one of C<'AD'>, C<'BC'>, C<'BCE'>, or
C<'CE'> without regard to case. The era indicator may be separated from
the year by white space, and be followed by a non-digit separator
character.

Unless the era is specified, years less than C<70> will have C<2000>
added, and years at least equal to C<70> but less than C<100> will have
C<1900> added.

If L<DateTime|DateTime> can be loaded, it will be used to get an epoch
from the parsed date. Otherwise L<Time::Local|Time::Local> will be used.
L<Time::Local|Time::Local> has its own quirks when it sees a year in the
distant past. See its documentation for more information.

=head1 METHODS

This class supports no public methods over and above those documented in
its superclass
L<Astro::App::Satpass2::ParseTime|Astro::App::Satpass2::ParseTime>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2016 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
