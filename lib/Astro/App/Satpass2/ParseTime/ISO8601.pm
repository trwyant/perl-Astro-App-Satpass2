package Astro::App::Satpass2::ParseTime::ISO8601;

use strict;
use warnings;

use Astro::Coord::ECI::Utils 0.059 qw{ looks_like_number SECSPERDAY };
use Time::Local;

use base qw{ Astro::App::Satpass2::ParseTime };

our $VERSION = '0.021';

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
		( \d{4} \D? | \d{2} \D )			# year: $1
		(?: ( \d{1,2} ) \D?				# month: $2
		    (?: ( \d{1,2} ) \D?				# day: $3
		    )?
		)?
	    >smxg ) {
	    @date = ( 0, $1, $2, $3 );

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
	    (?: ( \d{1,2} ) \D?			# hour: $1
		(?: ( \d{1,2} ) \D?		# minute: $2
		    (?: ( \d{1,2} ) \D?		# second: $3
			( \d* )			# fract: $4
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
	    defined $_ and s/ \D+ //smxg;
	}

	if ( $date[0] < 70 ) {
	    $date[0] += 100;
	} elsif ( $date[0] >= 100 ) {
	    $date[0] -= 1900;
	}
	$date[1] = defined $date[1] ? $date[1] - 1 : 0;
	defined $date[2] or $date[2] = 1;
	my $frc = pop @date;

	foreach ( @date ) {
	    defined $_ or $_ = 0;
	}

	my $time = @zone ?
	    timegm( reverse @date ) :
	    timelocal( reverse @date );

	if ( defined $frc  && $frc ne '') {
	    my $denom = '1' . ( '0' x length $frc );
	    $time += $frc / $denom;
	}

	return $time + $offset;
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

Copyright (C) 2009-2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
