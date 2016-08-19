package Astro::App::Satpass2::ParseTime::ISO8601;

use strict;
use warnings;

use Astro::Coord::ECI::Utils 0.059 qw{ looks_like_number SECSPERDAY };
use Time::Local;

use base qw{ Astro::App::Satpass2::ParseTime };

our $VERSION = '0.031';

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

    my $era_re = qr< (?: @{[
	join ' | ', sort keys %era_cvt
    ]} ) >smxi;

    my $make_epoch;
    {
	local $@ = @_;

	$make_epoch = eval {
	    require DateTime;
	    1;
	} ? sub {
	    my ( $y, $mo, $d, $h, $m, $s, $f, $z ) = @_;
	    return DateTime->new(
		year	=> $y,
		month	=> $mo,
		day	=> $d,
		hour	=> $h,
		minute	=> $m,
		second	=> $s,
		nanosecond	=> $f * 1_000_000_000,
		time_zone	=> $z ? 'UTC' : 'local',
	    )->epoch();
	} : sub {
	    my @date = @_;
	    my ( $frc, $z ) = splice @date, -2, 2;
	    --$date[1];
	    return $frc + $z ?
		timegm( reverse @date ) :
		timelocal( reverse @date );
	};
    }

    sub parse_time_absolute {
	my ( $self, $string ) = @_;

	my @zone;
	if ( $string =~ s/ \s* $zone_re \z //smxo ) {
	    @zone = ( $1, $2, $3, $4 );
	} elsif ( $self->{+__PACKAGE__}{tz} ) {
	    @zone = @{ $self->{+__PACKAGE__}{tz} };
	}
	my @date;

	# ISO 8601 date
	if ( $string =~ m< \A
		( [0-9]+ \s* $era_re [^0-9]* |		# year $1
		    [0-9]{4} [^0-9]? |
		    [0-9]+ [^0-9] )
		(?: ( [0-9]{1,2} ) [^0-9]?		# month: $2
		    (?: ( [0-9]{1,2} ) [^0-9]?		# day: $3
		    )?
		)?
	    >smxg ) {
	    @date = ( 0, $1, $2, $3 );

	    unless ( $date[1] =~ s/ \A ( [0-9]+ ) \s* ( $era_re ) [^0-9]? \z /
		$era_cvt{ uc $2 }->( $1 + 0 ) /smxe ) {
		$date[1] =~ s/ [^0-9] \z //smx;
		$date[1] < 70
		    and $date[1] += 2000;
		$date[1] < 100
		    and $date[1] += 1900;
	    }

	# special-case 'yesterday', 'today', and 'tomorrow'.
	} elsif ( $string =~ m{ \A
	    ( (?i: yesterday | today | tomorrow ) ) \D?		# day: $1
	    }smxg ) {
	    my @today = @zone ? gmtime : localtime;
	    @date = ( $special_day_offset{ lc $1 }, $today[5] + 1900,
		$today[4] + 1, $today[3] );

	} else {

	    return;

	}

	$string =~ m< \G
	    (?: ( [0-9]{1,2} ) [^0-9]?			# hour: $1
		(?: ( [0-9]{1,2} ) [^0-9]?		# minute: $2
		    (?: ( [0-9]{1,2} ) [^0-9]?		# second: $3
			( [0-9]* )			# fract: $4
		    )?
		)?
	    )?
	    \z >smxgc or return;
	push @date, $1, $2, $3, $4;

	my $offset = shift @date || 0;
	if ( @zone && ! $zone[0] ) {
	    my ( undef, $sign, $hr, $min ) = @zone;
	    $offset -= $sign . ( ( $hr * 60 + ( $min || 0 ) ) * 60 )
	}

	foreach ( @date ) {
	    defined $_ and s/ [^0-9] \z //smxg;
	}

#	$date[0] -= 1900;
	defined $date[1] or $date[1] = 1;
	defined $date[2] or $date[2] = 1;
	my $frc = pop @date;
	if ( $frc ) {
	    my $denom = '1' . ( '0' x length $frc );
	    $frc /= $denom;
	} else {
	    $frc = 0;
	}

	foreach ( @date ) {
	    defined $_ or $_ = 0;
	}

	return $make_epoch->( @date, $frc, scalar @zone ) + $offset;
    }

}

sub tz {
    my ( $self, @args ) = @_;
    if ( @args ) {
	if ( defined $args[0] && $args[0] ne '' ) {
	    if ( $args[0] =~ m/ \A $zone_re \z /smxo ) {
		$self->{+__PACKAGE__}{tz} = [ $1, $2, $3, $4 ];
	    } else {
		$self->warner()->whinge(
		    "Ignoring invalid zone '$args[0]'" );
		delete $self->{+__PACKAGE__}{tz};
	    }
	} else {
	    delete $self->{+__PACKAGE__}{tz};
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
