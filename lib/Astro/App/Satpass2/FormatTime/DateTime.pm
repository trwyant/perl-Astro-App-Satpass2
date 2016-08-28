package Astro::App::Satpass2::FormatTime::DateTime;

use 5.008;

use strict;
use warnings;

use base qw{
    Astro::App::Satpass2::FormatTime
};

use Astro::App::Satpass2::Utils qw{ has_method __reform_date };
use Astro::App::Satpass2::Locale qw{ __preferred };
use DateTime;
use DateTime::TimeZone;

our $VERSION = '0.031_005';

sub format_datetime {
    my ( $self, $tplt, $time, $gmt ) = @_;
    $time = $self->__round_time_value( $time );
    my $class = $self->__datetime_class();
    if ( has_method( $time, $self->METHOD_USED() ) ) {
	return $self->__format_datetime( $time, $tplt );
    } else {
	ref $time
	    and $self->warner()->wail( 'Unsupported time specification' );
	# Oh, for 5.010 and the // operator.
	my @dt_arg;
	$self->{_reform_date}
	    and push @dt_arg, reform_date => $self->{_reform_date};
	my $dt = $class->from_epoch(
	    epoch	=> $time,
	    time_zone	=> $self->_get_zone( $gmt ),
	    locale	=> scalar __preferred(),
	    @dt_arg,
	);
	return $self->__format_datetime( $dt, $tplt );
    }
}

sub reform_date {
    my ( $self, @args ) = @_;
    if ( @args ) {
	( $args[0], $self->{_reform_date} ) = __reform_date( $args[0] );
    }
    return $self->SUPER::reform_date( @args );
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
			    "'$zone' is not a valid time zone name" );
		    $zone = $zed;
		}
		$self->{_tz_obj} = DateTime::TimeZone->new(
		    name => $zone );
	    } else {
		$self->{_tz_obj} = $zone_local ||=
		    DateTime::TimeZone->new( name => 'local' );
	    }
	    return $self->SUPER::tz( $zone );

	} else {
	    return $self->SUPER::tz();
	}
    }

    sub _get_zone {
	my ( $self, $gmt ) = @_;
	defined $gmt
	    or $gmt = $self->gmt();

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

sub __calendar_name {
    my ( undef, $date_time ) = @_;	# Invocant unused
    my $code;
    $code = $date_time->can( 'is_julian' )
	and $code->( $date_time )
	and return 'Julian';
    return 'Gregorian';
}

sub __datetime_class {
    my ( $self ) = @_;
    $self->reform_date()
	and return 'DateTime::Calendar::Christian';
    return 'DateTime';
}

sub __format_datetime_width_adjust_object {
    my ( $self, $obj, $name, $val, $gmt ) = @_;
    my $class = $self->__datetime_class();
    # Note that I can not use new() here because I want to pass the
    # locale argument, and DateTime::Calendar::Christian does not accept
    # that. It works in from_epoch() or now() because
    # DateTime::Calendar::Christian simply passes its arguments through
    # to DateTime, which _does_ accept it.
    $obj or $obj = $class->now(
	time_zone	=> $self->_get_zone( $gmt ),
	locale		=> scalar __preferred(),
    );
    $obj->set( $name => $val );
    return $obj;
}

# my $mod_fmt = $self->__preprocess_strftime_format( $dt_obj, $fmt )
# Preprocess out all the extensions to the strftime format.
# What we're handling here is things of the form %{name:modifiers},
# where the colon and modifiers are optional.
# The modifier is a series of single-character flags followed by a field
# width. The flags are:
#  '-' - left-justify
#  '0' - zero-pad (ineffective if '-' specified)
#  't' - truncate to field width
sub __preprocess_strftime_format {
    my ( $self, $dt_obj, $fmt ) = @_;
    caller->isa( __PACKAGE__ )
	or $self->warner()->weep(
	'__preprocess_strftime_format() is private to Astro-App-Satpass2' );
    $fmt =~ s< ( % [{] ( \w+ | % ) (?: : ( [-0t]* ) ( [0-9]+ ) )? [}] ) >
	< _expand_strftime_format( $dt_obj, $1, $2, $3, $4 ) >smxge;
    return $fmt;
}

{
    my %special = (
	'%'		=> sub { return '%' },
	calendar_name	=> sub {
	    my ( $dt_obj ) = @_;
	    my $code;
	    $code = $dt_obj->can( 'is_julian' )
		and $code->( $dt_obj )
		and return 'Julian';
	    return 'Gregorian';
	},
    );

    sub _expand_strftime_format {
	my ( $dt_obj, $all, $name, $flags, $width ) = @_;
	my $code = $special{$name} || $dt_obj->can( $name )
	    or return $all;
	my $rslt = $code->( $dt_obj );
	my %flg = map { $_ => 1 } split qr{}, defined $flags ? $flags : '';
	if ( $width ) {
	    my $tplt = '%';
	    foreach my $f ( qw{ - 0 } ) {
		$flg{$f}
		    and $tplt .= $f;
	    }
	    $tplt .= '*s';
	    $rslt = sprintf $tplt, $width, $rslt;
	    $flg{t}
		and length $rslt > $width
		and substr $rslt, $width, length $rslt, '';
	}
	return $rslt;
    }
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
The following package-private methods are documented for the convenience
of the author, and may change or be retracted at any time.

=head2 __preprocess_strftime_format

 my $mod = $self->__preprocess_strftime_format( $dt_obj, $fmt );

The functionality documented below is supported, but B<this method is
not.> The method itself is package-private, and will in fact throw an
exception unless called from a subclass of this class.

This package-private method pre-processes a format, finding and
potentially replacing substrings that look like C<'%{name:modifiers}'>.
This is a further extension of the L<DateTime|DateTime> extension,
providing more control of the output.

The arguments are a L<DateTime|DateTime> or C<DateTime-ish> object and
the format that is to be pre-processed. The return is the pre-processed
format.

In the substrings that are (potentially) replaced, the C<'name'>
represents either a special-case string or the name of a method on the
C<$dt_obj> object. If it is neither, the substring is left unmodified.
The special-case names are:

=over

=item %

This causes a literal C<'%'> to be inserted.

=item calendar_name

This causes either C<'Gregorian'> or C<'Julian'> to be inserted. You get
C<'Julian'> only if C<$dt_obj> has an C<is_julian()> method, and that
method returns a true value. Otherwise you get C<'Gregorian'>. There is
no provision for localization, unfortunately.

=back

The colon and modifiers are optional. If present, the modifiers consist
of, in order:

=over

=item zero or more single-character flags;

These modify the formatting of the value, and may appear in any order.
The following flags are implemented:

=over

=item * C<'-'>

This flag causes the output to be left-justified in its field. It is
only effective if the field width (see below) is positive.

=item * C<'0'>

This flag causes the output to be zero-filled on the left. It is only
effective if the field width (see below) is positive, and C<'-'> is not
specified.

=item * C<'t'>

This flag causes the output to be truncated on the right to the field
width (see below). It is only effective if the field width is positive.

=back

=item a field width.

This is a non-negative integer, not beginning with zero, which specifies
the width of the output. Output will be at least this width, but may be
wider unless the C<'t'> flag was specified.

=back

For example, if the C<$dt_obj> represents the Ides of March, 44 BC, and
the template is C<'%{year_with_christian_era:06}-%m-%d'>, the returned
value will be C<'0044BC-%m-%d'>.

 $dt_obj->strftime(
     $self->__preprocess_strftime_format(
         $dt_obj, '%{year_with_christian_era:06}-%m-%d' ) );

would therefore produce C<'0044BC-03-15'>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2016 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
