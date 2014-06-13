package Astro::App::Satpass2::FormatTime::DateTime;

use 5.008;

use strict;
use warnings;

use base qw{
    Astro::App::Satpass2::FormatTime
};

use Astro::App::Satpass2::Utils qw{ instance };
use DateTime;
use DateTime::TimeZone;

our $VERSION = '0.020';

sub format_datetime {
    my ( $self, $tplt, $time, $gmt ) = @_;
    $time = $self->__round_time_value( $time );
    if ( instance( $time, 'DateTime' ) ) {
	return $self->__format_datetime( $time, $tplt );
    } else {
	# Oh, for 5.010 and the // operator.
	my $dt = DateTime->from_epoch(
	    epoch	=> $time,
	    time_zone	=> $self->_get_zone( defined $gmt ? $gmt :
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
			or $self->warner()->wail(
			    'The tz value must be a valid zone name' );
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

Astro::App::Satpass2::FormatTime::DateTime - Format time using DateTime

=head1 SYNOPSIS

None. All externally-available functionality is provided by either the
superclass or one of the subclasses.

=head1 NOTICE

This class and its subclasses are private to the
L<Astro::App::Satpass2|Astro::App::Satpass2> package. The author
reserves the right to add, change, or retract functionality without
notice.

=head1 DETAILS

This subclass of
L<Astro::App::Satpass2::FormatTime|Astro::App::Satpass2::FormatTime> is
an abstract class for formatting dates and times using
L<DateTime|DateTime>. What you really want to use is one of its
subclasses:
L<Astro::App::Satpass2::FormaTime::DateTime::Cldr|Astro::App::Satpass2::FormaTime::DateTime::Cldr>
or
L<Astro::App::Satpass2::FormaTime::DateTime::Strftime|Astro::App::Satpass2::FormaTime::DateTime::Strftime>


=head1 METHODS

This class provides no public methods over and above those provided by
L<Astro::App::Satpass2::FormatTime|Astro::App::Satpass2::FormatTime>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
