package Astro::App::Satpass2::FormatValue::Formatter;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2::Utils qw{ has_method };

our $VERSION = '0.000_01';

#	The %dimensions hash defines physical dimensions and the
#	allowable units for each. The keys of this hash are the names of
#	physical dimensions (e.g. 'length', 'mass', 'volume', and so
#	on), and the values are hashes defining the dimension.
#
#	Each dimension definition hash must have the following keys:
#
#	align_left => boolean
#	    This optional key, if true, specifies that the value is to
#	    be aligned to the left in its field. This value can be
#	    overridden in the {define} key, or when the formatter is
#	    called.
#
#	default => the name of the default units for the dimension. This
#	    value must appear as a key in the define hash (see below).
#	    This default can be overridden by a given format effector.
#
#	define => a hash defining the legal units for the dimension. The
#	    keys are the names of the units (e.g. for length
#	    'kilometers', 'meters', 'miles', 'feet'). The value is a
#	    hash containing zero or more of the following keys:
#
#	    alias => name
#	        This optional key specifies that the name is just an
#	        alias for another key, which must exist in the define
#	        hash. No other keys need be specified.
#
#	    align_left => boolean
#		This optional key, if true, specifies that the value is
#		to be aligned to the left of its field. It can be
#		overridden by a value specified when the formatter is
#		called.
#
#	    factor => number
#		A number to multiply the value by to do the conversion.
#
#	    formatter => name
#		This optional key specifies the name of the formatter
#		routine to use instead of the normal one.
#
#	    method => _name
#		This optional key specifies a method to call. The method
#		is passed the value being formatted, and the method's
#		return becomes the new value to format. If both {factor}
#		and {method} are specified, {method} is done first.
#
#	formatter => name
#	    This key specifies the formatter to use for the units. It
#	    can be overridden in the {define} key.

my %dimensions = (

    almanac_pseudo_units	=> {
	default	=> 'description',
	define	=> {
	    event	=> {},
	    detail	=> {
		formatter	=> '_format_integer',
	    },
	    description	=> {},
	},
	formatter	=> '_format_string',
    },

    angle_units => {
	align_left	=> 0,
	default		=> 'degrees',
	define	=> {
	    bearing	=> {
		align_left	=> 1,
		formatter	=> '_format_bearing',
	    },
	    decimal	=> {
		alias		=> 'degrees',
	    },
	    degrees	=> {
		factor		=> 90/atan2( 1, 0 ),
	    },
	    radians	=> {},
	    phase	=> {
		align_left	=> 1,
		formatter	=> '_format_phase',
	    },
	    right_ascension	=> {
		formatter	=> '_format_right_ascension',
	    },
	},
	formatter	=> '_format_number',
    },

    dimensionless	=> {
	default		=> 'unity',
	define		=> {
	    percent	=> {
		factor	=> 100,
	    },
	    unity	=> {},
	},
	formatter	=> '_format_number',
    },

    duration => {
	default		=> 'composite',
	define => {
	    composite	=> {
		formatter	=> '_format_duration',
	    },
	    seconds	=> {},
	    minutes	=> {
		factor	=> 1/60,
	    },
	    hours	=> {
		factor	=> 1/3600,
	    },
	    days	=> {
		factor	=> 1/86400,
	    },
	},
	formatter	=> '_format_number',
    },

    event_pseudo_units	=> {
	default	=> 'localized',
	define	=> {
	    localized	=> {},
	    integer	=> {
		formatter	=> '_format_integer',
	    },
	    string	=> {},
	},
	formatter	=> '_format_event',
    },

    integer_pseudo_units	=> {
	align_left	=> 0,
	default	=> 'integer',
	define	=> {
	    integer	=> {},
	},
	formatter	=> '_format_integer',
    },

    length => {
	align_left	=> 0,
	default		=> 'kilometers',
	define	=> {
	    kilometers	=> {},
	    km		=> {},
	    meters	=> {
		factor		=> 1000,
	    },
	    m		=> {
		alias		=> 'meters',
	    },
	    miles	=> {
		factor		=> 0.62137119,
	    },
	    mi		=> {
		alias		=> 'miles',
	    },
	    feet	=> {
		factor		=> 3280.8399,
	    },
	    ft		=> {
		alias		=> 'feet',
	    },
	},
	formatter	=> '_format_number',
    },

    number	=> {	# Just for consistency's sake
	align_left	=> 0,
	default		=> 'number',
	define		=> {
	    number	=> {},
	},
	formatter	=> '_format_number',
    },

    scientific	=> {	# Just for consistency's sake
	align_left	=> 0,
	default		=> 'scientific',
	define		=> {
	    scientific	=> {},
	},
	formatter	=> '_format_number_scientific',
    },

    string	=> {	# for tle, to prevent munging data. ONLY
			# 'string' is to be defined.
	default	=> 'string',
	define	=> {
	    string	=> {},
	},
	formatter	=> '_format_string',
    },

    string_pseudo_units	=> {
	default	=> 'string',
	define	=> {
	    lower_case	=> {
		formatter	=> '_format_lower_case',
	    },
	    string	=> {},
	    title_case	=> {
		formatter	=> '_format_title_case',
	    },
	    upper_case	=> {
		formatter	=> '_format_upper_case',
	    },
	},
	formatter	=> '_format_string',
    },

    time_units => {
	default		=> 'local',
	define	=> {
	    days_since_epoch => {
		factor	=> 1/86400,
		formatter => '_format_number',
		method	=> '_subtract_epoch',
	    },
	    gmt		=> {
		gmt	=> 1,
	    },
	    julian	=> {
		formatter	=> '_format_number',
		method		=> '_julian_day',
	    },
	    local	=> {},
	    universal	=> {
		alias	=> 'gmt',
	    },
	    z		=> {
		alias	=> 'gmt',
	    },
	    zulu	=> {
		alias	=> 'gmt',
	    },
	},
	formatter	=> '_format_time',
    },

);

sub new {
    my ( $class, $name, $info ) = @_;
    'HASH' eq ref $info
	or _confess( 'The info argument must be a HASH reference' );

    # Validate the dimension information
    $info->{dimension}
	or _confess(
	"'$name' does not specify a {dimension} hash" );
    defined( my $dim = $info->{dimension}{dimension} )
	or _confess(
	"'$name' does not specify the dimension" );
    $dimensions{$dim}
	or _confess( "'$name' specifies invalid dimension '$dim'" );
    if ( defined( my $dflt = $info->{dimension}{default} ) ) {
	defined $dimensions{$dim}{define}{$dflt}
	    or _confess( "'$name' specifies invalid default units '$dflt'" );
    }

    # If the dimension is 'time_units' we need to validate that the
    # format key is defined and valid
    if ( 'time_units' eq $info->{dimension}{dimension} ) {
	if ( 'ARRAY' eq ref $info->{dimension}{format} ) {
	    foreach my $entry ( @{ $info->{dimension}{format} } ) {
		$class->_valid_time_format_name( $entry )
		    or _confess(
		    "In '$name', '$entry' is not a valid format" );
	    }
	    $info->{default}{format} = sub {
		my ( $self ) = @_;
		return $self->_get_date_format_data( $name, format => $info );
	    };
	    $info->{default}{width} = sub {
		my ( $self ) = @_;
		return $self->_get_date_format_data( $name, width => $info );
	    };
	} else {
	    _confess(
		"'$name' must specify a {format} key in {dimension}" );
	}
	$info->{default}{round_time} = sub {
	    my ( $self ) = @_;
	    return $self->{round_time};
	};
    }

    # Validate the fetch information
    'CODE' eq ref $info->{fetch}
	or _confess(
	"In '$name', {fetch} is not a code reference" );

    return bless {
	name	=> $name,
	code	=> sub {
	    my ( $self, %arg ) = _arguments( @_ );

	    $self->_apply_defaults( $name => \%arg, $info->{default} );

	    my $value = ( $self->{title} || defined $arg{literal} ) ?
		undef :
		$self->_fetch( $info, $name, \%arg );

	    my @rslt;
	    foreach my $parm ( $info->{chain} ?
		$info->{chain}->( $self, $name, $value, \%arg ) :
		\%arg ) {

		push @rslt, defined $arg{literal} ?
		    $self->_format_string( $arg{literal}, \%arg ) :
		    $self->_apply_dimension(
			$name => $value, $parm, $info->{dimension} );

	    }

	    return join ' ', @rslt;
	},
    }, ref $class || $class;

}

# TODO import the relevant parts of Astro::App::Satpass2::FormatValue
# into this class, so we don't have to hand out dimension definitions.

sub __get_dimension_info {
    my ( undef, $dimension ) = @_;
    return $dimensions{$dimension};
}

# TODO both this and Astro::App::Satpass2::FormatValue need this.
sub _arguments {
    my @arg = @_;

    my $obj = shift @arg;
    my $hash = 'HASH' eq ref $arg[-1] ? pop @arg : {};

    my ( @clean, @append );
    foreach my $item ( @arg ) {
	if ( has_method( $item, 'dereference' ) ) {
	    push @append, $item->dereference();
	} else {
	    push @clean, $item;
	}
    }

    @clean % 2 and splice @clean, 0, 0, 'title';

    return ( $obj, %{ $hash }, @clean, @append );
}

sub _confess {
    my ( @arg ) = @_;
    require Carp;
    Carp::confess( @arg );
}

# TODO this is sort of a moral encapsulation violation. Nobody else
# accesses this, but the names are relevant to
# Astro::App::Satpass2::FormatValue, not this code.
{

    my %fmt;

    BEGIN {
	%fmt = map { $_ => 1 } qw{ date_format time_format };
    }

    sub _valid_time_format_name {
	my ( undef, $name ) = @_;
	return $fmt{$name};
    }
}

foreach my $method ( qw{ code name } ) {
    no strict qw{ refs };
    *$method = sub {
	my ( $self ) = @_;
	return $self->{$method};
    };
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::FormatValue::Formatter - Implement a formatter

=head1 SYNOPSIS

 No user-servicable parts inside.

=head1 DESCRIPTION

This Perl class should be considered private to the
F<Astro-App-Satpass2> package, and this documentation is for the benefit
of the author. The author reserves the right to modify or retract this
class without notice.

This Perl class encapsulates the construction of individual formatter
routines for the use of the
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
object. It is called to construct that class' built-in formatters, and
by that class'
L<add_formatter_method()|Astro::App::Satpass2::FormatValue/add_formatter_method>
method to add user-defined formatter methods. It is not instantiated by
the user.

=head1 METHODS

This class supports the following methods:

=head2 new

This static method instantiates the object. Besides the invocant, it
takes two arguments: the name of the formatter and a hash that describes
the formatter.

=head2 code

This method returns the code that implements the formatter.

=head2 name

This method returns the name of the formatter.

=head1 SEE ALSO

L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
