package Astro::App::Satpass2::FormatTime::DateTime;

use 5.006002;

use strict;
use warnings;

use base qw{
    Astro::App::Satpass2::FormatTime
};

use Astro::App::Satpass2::Copier qw{ __instance };
use Carp;
use DateTime;
use DateTime::TimeZone;
use POSIX ();

our $VERSION = '0.000_07';

sub format_datetime {
    my ( $self, $tplt, $time, $gmt ) = @_;
    if ( __instance( $time, 'DateTime' ) ) {
	return $self->__format_datetime( $time, $tplt );
    } else {
	# Oh, for 5.010 and the // operator.
	my $dt = DateTime->from_epoch(
	    epoch => POSIX::floor( $time + 0.5),
	    time_zone => $self->_get_zone( defined $gmt ? $gmt :
		$self->gmt() ) );
	return $self->__format_datetime( $dt, $tplt );
    }
}

{

    my $zone_gmt;
    my $zone_local;

    sub tz {
	my ( $self, @args ) = @_;

	if ( @args ) {
	    my $zone = $args[0];
	    if ( defined $zone and $zone ne '' ) {
		if ( ! DateTime::TimeZone->is_valid_name( $zone ) ) {
		    my $zed = uc $zone;
		    DateTime::TimeZone->is_valid_name( $zed )
			or croak 'The tz value must be a valid zone name';
		    $zone = $zed;
		}
		$self->{_tz_obj} = DateTime::TimeZone->new(
		    name => $zone );
	    } else {
		$self->{_tz_obj} = $zone_local ||=
		    DateTime::TimeZone->new( name => 'local' );
	    }
	    return $self->SUPER::tz( $args[0] );

	} else {
	    return $self->SUPER::tz();
	}
    }

    sub _get_zone {
	my ( $self, $gmt ) = @_;
	defined $gmt or $gmt = $self->gmt();

	$gmt and return ( $zone_gmt ||= DateTime::TimeZone->new(
	    name => 'UTC' ) );

	$self->{_tz_obj} and return $self->{_tz_obj};

	my $tz = $self->tz();
	if ( defined $tz && $tz ne '' ) {
	    return ( $self->{_tz_obj} = DateTime::TimeZone->new(
		    name => $tz ) );
	} else {
	    return ( $self->{_tz_obj} = $zone_local ||=
		DateTime::TimeZone->new( name => 'local' ) );
	}

    }

}

sub __format_datetime_width_adjust_object {
    my ( $self, $obj, $name, $val ) = @_;
    $obj or $obj = DateTime->new( year => 2100 );
    $obj->set( $name => $val );
    return $obj;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::FormatTime::DateTime - Format time using DateTime->strftime()

=head1 SYNOPSIS

 use Astro::App::Satpass2::FormatTime::DateTime;
 my $tf = Astro::App::Satpass2::FormatTime::DateTime->new();
 print 'It is now ',
     $tf->format_datetime( '%H:%M:%S', time, 1 ),
     " GMT\n";

=head1 NOTICE

This class and its subclasses are private to the
L<Astro::App::Satpass2|Astro::App::Satpass2> package. The author reserves the right to
add, change, or retract functionality without notice.

=head1 DETAILS

This subclass of L<Astro::App::Satpass2::FormatTime|Astro::App::Satpass2::FormatTime>
formats times using C<DateTime->strftime()>. Time zones other than the
default local zone are handled using
L<DateTime::TimeZone|DateTime::TimeZone> objects.

=head1 METHODS

This class provides no public methods over and above those provided by
L<Astro::App::Satpass2::FormatTime|Astro::App::Satpass2::FormatTime> and
L<Astro::App::Satpass2::FormatTime::Strftime|Astro::App::Satpass2::FormatTime::Strftime>.
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

# ex: set textwidth=72 :