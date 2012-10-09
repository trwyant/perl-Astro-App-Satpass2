package Astro::App::Satpass2::ParseTime::Date::Manip::v5;

use strict;
use warnings;

use Astro::Coord::ECI::Utils qw{ looks_like_number };
use Time::Local;

use base qw{ Astro::App::Satpass2::ParseTime };

use Astro::App::Satpass2::Utils qw{ load_package };

our $VERSION = '0.009';

my $invalid;

BEGIN {
    eval {
	load_package( 'Date::Manip' )
	    or return;
	my $ver = Date::Manip->VERSION();
	$ver =~ s/ _ //smxg;
	$ver < 6
	    and do {
		Date::Manip->import();
		1;
	    }
	    or $invalid = sprintf
		'%s assumes a Date::Manip version < 6. You have %s',
		__PACKAGE__, Date::Manip->VERSION();
	1;
    } or $invalid = ( $@ || 'Unable to load Date::Manip' );
}

my ( $default_zone ) = eval {
    grep { m{ \A TZ= }smx } Date_Init()
};

my $epoch_offset = timegm( 0, 0, 0, 1, 0, 70 );

sub delegate {
    return __PACKAGE__;
}

sub parse_time_absolute {
    my ( $self, $string ) = @_;
    $invalid and $self->warner()->wail( $invalid );
    my $time = UnixDate( $string, '%s' ) - $epoch_offset;
    if ( $self->perltime() ) {
	$time = timelocal( gmtime $time );
    }
    return $time;
}

sub perltime {
    my ( $self, @args ) = @_;
    $invalid and $self->warner()->wail( $invalid );
    if ( @args ) {
	my $zone = $args[0] ? 'GMT' : $self->tz();
	$zone = defined $zone ? "TZ=$zone" : $default_zone;
	Date_Init( $zone );
    }
    return $self->SUPER::perltime( @args );
}

sub use_perltime {
    return 1;
}

sub tz {
    my ( $self, @args ) = @_;
    $invalid and $self->warner()->wail( $invalid );
    if ( @args ) {
	if ( $args[0] || looks_like_number( $args[0] ) ) {
	    $ENV{TZ} = $args[0];	## no critic (RequireLocalizedPunctuationVars)
	    $self->perltime() or Date_Init( "TZ=$args[0]" );
	} else {
	    delete $ENV{TZ};
	    $self->perltime() or Date_Init( $default_zone );
	}
    }
    return $self->SUPER::tz( @args );
}

1;

=head1 NAME

Astro::App::Satpass2::ParseTime::Date::Manip::v5 - Astro::App::Satpass2 wrapper for Date::Manip v5 or less

=head1 SYNOPSIS

No user-serviceable parts inside.

=head1 DETAILS

This class wraps L<Date::Manip|Date::Manip> version 5.54 or lower, and
uses it to parse dates. It uses the C<perltime> mechanism, since these
versions of L<Date::Manip|Date::Manip> do not understand summer time.

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

Copyright (C) 2009-2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
