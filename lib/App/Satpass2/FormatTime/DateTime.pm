package App::Satpass2::FormatTime::DateTime;

use 5.006;

use strict;
use warnings;

use base qw{ App::Satpass2::FormatTime };

use Carp;
use DateTime;
use DateTime::TimeZone;
use Params::Util 0.025 qw{ _INSTANCE };
use POSIX ();

our $VERSION = '0.000_03';

sub strftime {
    my ( $self, $tplt, $time, $gmt ) = @_;
    if ( _INSTANCE( $time, 'DateTime' ) ) {
	return $time->strftime( $tplt );
    } else {
	# Oh, for 5.010 and the // operator.
	my $dt = DateTime->from_epoch(
	    epoch => POSIX::floor( $time + 0.5),
	    time_zone => $self->_get_zone( defined $gmt ? $gmt :
		$self->gmt() ) );
	return $dt->strftime( $tplt );
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

sub __strftime_width_adjust_object {
    my ( $self, $obj, $name, $val ) = @_;
    $obj or $obj = DateTime->new( year => 2100 );
    $obj->set( $name => $val );
    return $obj;
}

1;

__END__

=head1 NAME

App::Satpass2::FormatTime::DateTime - <<< replace boilerplate >>>

=head1 SYNOPSIS

<<< replace boilerplate >>>

=head1 DETAILS

<<< replace boilerplate >>>

=head1 METHODS

This class supports the following public methods:

=head1 ATTRIBUTES

This class has the following attributes:


=head1 SEE ALSO

<<< replace or remove boilerplate >>>

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
