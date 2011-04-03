package Astro::App::Satpass2::Format::Template;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Format };

use Carp;

use Astro::App::Satpass2::Format::Template::Provider;
use Astro::App::Satpass2::FormatValue;
use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::Utils qw{
    deg2rad embodies julianday PI rad2deg TWOPI
};
use Clone qw{ };
use POSIX qw{ floor };
use Template;
use Template::Provider;
use Text::Abbrev;
use Text::Wrap qw{ wrap };

our $VERSION = '0.000_12';

my %template_definitions = (

    # Local coordinates

    az_rng	=> <<'EOD',
[% data.azimuth( arg, bearing = 2 ) %]
    [%= data.range( arg ) -%]
EOD

    azel	=> <<'EOD',
[% data.elevation( arg ) %]
    [%= data.azimuth( arg, bearing = 2 ) -%]
EOD

    azel_rng	=> <<'EOD',
[% data.elevation( arg ) %]
    [%= data.azimuth( arg, bearing = 2 ) %]
    [%= data.range( arg ) -%]
EOD

    equatorial	=> <<'EOD',
[% data.right_ascension( arg ) %]
    [%= data.declination( arg ) -%]
EOD

    equatorial_rng	=> <<'EOD',
[% data.right_ascension( arg ) %]
    [%= data.declination( arg ) %]
    [%= data.range( arg ) -%]
EOD

    # Main templates

    alias	=> <<'EOD',
[% DEFAULT data = sp.alias( arg ) -%]
[% FOREACH key IN data.keys.sort %]
    [%- key %] => [% data.$key %]
[% END -%]
EOD

    almanac	=> <<'EOD',
[% DEFAULT data = sp.almanac( arg ) -%]
[% FOREACH item IN data %]
    [%- item.date %] [% item.time %]
        [%= item.almanac( units = 'description' ) %]
[% END -%]
EOD

    flare => <<'EOD',
[% DEFAULT data = sp.flare( arg ) -%]
[% IF title %]
    [%- title.time( '' ) %]
        [%= title.name( '', width = 12 ) %]
        [%= title.local_coord( '' ) %]
        [%= title.magnitude( '' ) %]
        [%= title.angle( 'Degrees' ) %]

    [%- title.time( '' ) %]
        [%= title.name( '', width = 12 ) %]
        [%= title.local_coord( '' ) %]
        [%= title.magnitude( '' ) %]
        [%= title.angle( 'From' ) %]
        [%= title.azimuth( 'Center', bearing = 2 ) %]
        [%= title.range( 'Center', width = 6 ) %]

    [%- title.time %]
        [%= title.name( width = 12 ) %]
        [%= title.local_coord %]
        [%= title.magnitude %]
        [%= title.angle( 'Sun' ) %]
        [%= title.azimuth( bearing = 2 ) %]
        [%= title.range( width = 6 ) %]
[% END -%]
[% prior_date = '' -%]
[% FOR item IN data %]
    [%- center = item.center %]
    [%- current_date = item.date %]
    [%- IF prior_date != current_date %]
        [%- prior_date = current_date %]
        [%- current_date %]

    [%- END %]
    [%- item.time %]
        [%= item.name( units = 'title_case', width = 12 ) %]
        [%= item.local_coord %]
        [%= item.magnitude %]
        [%= IF 'day' == item.type( width = '' ) %]
            [%- item.appulse.angle %]
        [%- ELSE %]
            [%- title.angle( title = 'night' ) %]
        [%- END %]
        [%= center.azimuth( bearing = 2 ) %]
        [%= center.range( width = 6 ) %]
[% END -%]
EOD

    list => <<'EOD',
[% DEFAULT data = sp.list( arg ) -%]
[% IF title %]
    [%- title.oid( align_left = 0 ) %]
        [%= title.name %]
        [%= title.epoch %]
        [%= title.period( align_left = 1 ) %]
[% END -%]
[% FOR item IN data %]
    [%- IF item.body.get( 'inertial' ) %]
        [%- item.oid %] [% item.name %] [% item.epoch %]
            [%= item.period( align_left = 1 ) %]
    [%- ELSE %]
        [%- item.oid %] [% item.name %] [% item.latitude %]
            [%= item.longitude %] [% item.altitude %]
    [%- END %]
[% END -%]
EOD

    location	=> <<'EOD',
[% DEFAULT data = sp.location( arg ) -%]
Location: [% data.name( width = '' ) %]
          Latitude [% data.latitude( places = 4,
                width = '' ) %], longitude
            [%= data.longitude( places = 4, width = '' )
                %], height
            [%= data.altitude( units = 'meters', places = 0,
                width = '' ) %] m
EOD

    pass	=> <<'EOD',
[% DEFAULT data = sp.pass( arg ) -%]
[% IF title %]
    [%- title.time( align_left = 0 ) %]
        [%= title.local_coord %]
        [%= title.latitude %]
        [%= title.longitude %]
        [%= title.altitude %]
        [%= title.illumination %]
        [%= title.event( width = '' ) %]
[% END -%]
[% FOR pass IN data %]
    [%- events = pass.events %]
    [%- evt = events() %]

    [%- evt.date %]    [% evt.oid %] - [% evt.name( width = '' ) %]

    [%- WHILE evt %]
        [%- evt.time %]
            [%= evt.local_coord %]
            [%= evt.latitude %]
            [%= evt.longitude %]
            [%= evt.altitude %]
            [%= evt.illumination %]
            [%= evt.event( width = '' ) %]
        [%- IF 'apls' == evt.event( units = 'string', width = '' ) %]
            [%- apls = evt.appulse %]

            [%- title.time( '' ) %]
                [%= apls.local_coord %]
                [%= apls.angle %] degrees from [% apls.name( width = '' ) %]
        [%- END %]
        [%- evt = events() %]

    [%- END %]
[%- END -%]
EOD

    phase => <<'EOD',
[% DEFAULT data = sp.phase( arg ) -%]
[% IF title %]
    [%- title.date( align_left = 0 ) %]
        [%= title.time( align_left = 0 ) %]
        [%= title.name( width = 8, align_left = 0 ) %]
        [%= title.phase( places = 0, width = 4 ) %]
        [%= title.phase( width = 16, units = 'phase',
            align_left = 1 ) %]
        [%= title.fraction_lit( title = 'Lit', places = 0, width = 4,
            units = 'percent', align_left = 0 ) %]
[% END -%]
[% FOR item IN data %]
    [%- item.date %] [% item.time %]
        [%= item.name( width = 8, align_left = 0 ) %]
        [%= item.phase( places = 0, width = 4 ) %]
        [%= item.phase( width = 16, units = 'phase',
            align_left = 1 ) %]
        [%= item.fraction_lit( places = 0, width = 4,
            units = 'percent' ) %]%
[% END -%]
EOD

    position => <<'EOD',
[% DEFAULT data = sp.position( arg ) -%]
[%- data.date %] [% data.time %]
[% IF title %]
    [%- title.name( align_left = 0, width = 16 ) %]
        [%= title.local_coord %]
        [%= title.epoch( align_left = 0 ) %]
        [%= title.illumination %]
[% END -%]
[% FOR item IN data.bodies() %]
    [%- item.name( width = 16, missing = 'oid', align_left = 0 ) %]
        [%= item.local_coord %]
        [%= item.epoch( align_left = 0 ) %]
        [%= item.illumination %]

    [%- FOR refl IN item.reflections() %]
        [%- title.name( '', width = 16 ) %]
            [%= title.local_coord( '' ) %] MMA
        [%- IF refl.status( width = '' ) %]
            [%= refl.mma( width = '' ) %] [% refl.status( width = '' ) %]
        [%- ELSE %]
            [%= refl.mma( width = '' ) %] mirror angle [%
                refl.angle( width = '' ) %] magnitude [%
                refl.magnitude( width = '' ) %]
        [%- END %]

    [%- END -%]
[% END -%]
EOD

    tle	=> <<'EOD',
[% DEFAULT data = sp.tle( arg ) -%]
[% FOR item IN data %]
    [%- item.tle -%]
[% END -%]
EOD

    tle_celestia => <<'EOD',
[% DEFAULT data = sp.tle( arg ) -%]
[% FOR item IN data %]
# Keplerian elements for [% item.name( width = '' ) %]
# Generated by [% item.provider %]
# Epoch: [% item.epoch( units = 'zulu', width = '' ) %] UT

Modify "[% item.name( width = '' ) %]" "Sol/Earth" {
    EllipticalOrbit {
        Epoch  [% item.epoch( units = 'julian', places = '', width = '' ) %]
        Period  [% item.period( units = 'days', places = '', width = '' ) %]
        SemiMajorAxis  [% item.semimajor( places = '', width = '' ) %]
        Eccentricity  [% item.eccentricity( places = '', width = '' ) %]
        Inclination  [% item.inclination( places = '', width = '' ) %]
        AscendingNode  [% item.ascending_node( units = 'degrees',
            places = '', width = '' ) %]
        ArgOfPericenter  [% item.argument_of_perigee( places = '',
            width = '' ) %]
        MeanAnomaly  [% item.mean_anomaly( places = '', width = '' ) %]
    }
    UniformRotation {
        Inclination  [% item.inclination( places = '', width = '' ) %]
        MeridianAngle  90
        AscendingNode  [% item.ascending_node( units = 'degrees',
            places = '', width = '' ) %]
    }
}
[% END -%]
EOD

    tle_verbose => <<'EOD',
[% DEFAULT data = sp.tle( arg ) -%]
[% FOR item IN data -%]
NORAD ID: [% item.oid( width = '' ) %]
    Name: [% item.name( width = '' ) %]
    International launch designator: [% item.international( width = '' ) %]
    Epoch of data: [% item.epoch( units = 'zulu', width = '' ) %] GMT
    Effective date of data: [% item.effective_date( units = 'zulu',
        width = '', missing = '<none>' ) %] GMT
    Classification status: [% item.classification %]
    Mean motion: [% item.mean_motion( places = 8, width = '' )
        %] degrees/minute
    First derivative of motion: [% item.first_derivative( width = '',
        places = 8 ) %] degrees/minute squared
    Second derivative of motion: [% item.second_derivative( width = '',
        places = 5 ) %] degrees/minute cubed
    B Star drag term: [% item.b_star_drag( places = 5, width = '' ) %]
    Ephemeris type: [% item.ephemeris_type %]
    Inclination of orbit: [% item.inclination( places = 4, width = '' )
        %] degrees
    Right ascension of ascending node: [% item.ascending_node(
        places = 0, width = '' ) %]
    Eccentricity: [% item.eccentricity( places = 7, width = '' ) %]
    Argument of perigee: [% item.argument_of_perigee( places = 4,
        width = '' ) %] degrees from ascending node
    Mean anomaly: [% item.mean_anomaly( places = 4, width = '' ) %] degrees
    Element set number: [% item.element_number( width = '' ) %]
    Revolutions at epoch: [% item.revolutions_at_epoch( width = '' ) %]
    Period (derived): [% item.period( width = '' ) %]
    Semimajor axis (derived): [% item.semimajor( places = 1,
        width = '' ) %] kilometers
    Perigee altitude (derived): [% item.perigee( places = 1, width = '' )
        %] kilometers
    Apogee altitude (derived): [% item.apogee( places = 1, width = '' )
        %] kilometers
[% END -%]
EOD

);


sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new( @args );

    $self->{template} =
	Astro::App::Satpass2::Format::Template::Provider->new()
	or confess "Programming error - failed to instantiate provider";

    $self->{tt} = Template->new( {
	    LOAD_TEMPLATES => [
		$self->{template},
		Template::Provider->new(),
	    ],
	}
    ) or confess "Programming error - Failed to instantate tt: $Template::ERROR";

    while ( my ( $name, $def ) = each %template_definitions ) {
	$self->template( $name => $def );
    }

    $self->{default} = {};

    return $self;
}

sub alias {
    my ( $self, $hash ) = @_;
    return $self->_tt( alias => $hash );
}

sub almanac {
    my ( $self, $array ) = @_;
    return $self->_tt( almanac => $self->_wrap( $array ) );
}

sub config {
    my ( $self, %args ) = @_;
    my @data = $self->SUPER::config( %args );

    # TODO support for the {default} key.

    foreach my $name ( sort
	$self->{template}->__satpass2_defined_templates() ) {
	# The regex is ad-hocery to prevent the unsupported celestia
	# stuff from being included unless necessary.
	my $template = $self->{template}->__satpass2_template( $name );
	next if ( $args{changes} || $name =~ m/ celestia /smx ) &&
	    defined $template &&
	    $template eq $template_definitions{$name};
	push @data, [ template => $name, $template ];
    }

    return wantarray ? @data : \@data;
}

sub __default {
    my ( $self, @arg ) = @_;
    @arg or return $self->{default};
    my $action = shift @arg;
    @arg or return $self->{default}{$action};
    my $attrib = shift @arg;
    defined $attrib
	or return delete $self->{default}{$action};
    @arg or return $self->{default}{$action}{$attrib};
    my $value = shift @arg;
    defined $value
	or return delete $self->{default}{$action}{$attrib};
    $self->{default}{$action}{$attrib} = $value;
    return $value;
}

{

    sub export {
	my ( $self, $tplt, $file ) = @_;
	if ( '*' eq $tplt ) {
	    foreach my $name ( sort
		$self->{template}->__satpass2_defined_templates() ) {
		$self->_export( $name, File::Spec->catfile( $file,
			"$name.tt" ) );
	    }
	} else {
	    $self->_export( $tplt, $file );
	}
	return $self;
    }

    my %command = (
	tle_verbose	=> q{sp.tle( arg )},
	tle_celestia	=> q{sp.tle( arg )},
    );

    sub _export {
	my ( $self, $name, $file ) = @_;
	defined( my $template = $self->{template}->__satpass2_template(
		$name ) )
	    or $self->warner()->wail( "No such template as '$name'" );
	my $fh = $self->_export_file( $file );
	print { $fh } $template;
	return;
    }

    sub _export_file {
	my ( $self, $file ) = @_;
	if ( defined $file && $file ne '-' ) {
	    open my $fh, '>', $file
		or $self->warner()->wail( "Failed to open $file: $!" );
	    return $fh;
	} else {
	    return *STDOUT;
	}
    }
}

sub flare {
    my ( $self, $array ) = @_;

    return $self->_tt( flare => $self->_wrap( $array ) );
}

sub gmt {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->time_formatter()->gmt( @args );
	return $self->SUPER::gmt( @args );
    } else {
	return $self->SUPER::gmt();
    }
}

sub list {
    my ( $self, $array ) = @_;

    return $self->_tt( list =>
	$self->_wrap( [ map { { body => $_ } } @{ $array } ] ) );
}

sub local_coord {
    my ( $self, @args ) = @_;
    if ( @args ) {
	my $val = $args[0];
	defined $val or $val = $self->DEFAULT_LOCAL_COORD;
	# Chicken-and-egg problem: we have to get an object from
	# SUPER::new before we can add the template provider, but
	# SUPER::new sets the local coordinates. So if there is no
	# provider we check the hash it is initialized from.
	$self->{template} ?
	    $self->{template}->__satpass2_template( $val ) :
	    $template_definitions{$val}
	    or $self->warner()->wail(
		"Unknown local coordinate specification '$val'" );
	return $self->SUPER::local_coord( @args );
    } else {
	return $self->SUPER::local_coord();
    }
}

sub location {
    my ( $self, $station ) = @_;

    return $self->_tt( location =>
	$self->_wrap( { body => $station } ) );
}

sub pass {
    my ( $self, $array ) = @_;

    return $self->_tt( pass => $self->_wrap( $array ) );
}

sub phase {
    my ( $self, $array ) = @_;

    return $self->_tt( phase => $self->_wrap( [
		map { { body => $_, time => $_->universal() } }
		@{ $array } ] ) );
}

sub position {
    my ( $self, $hash ) = @_;

    return $self->_tt( position => $self->_wrap( $hash ) );
}

sub report {
    my ( $self, $data ) = @_;

    $data = { %{ $data } };	# Shallow clone
    $data->{title} = $self->_wrap( undef );
    $data->{default} ||= $self->__default();

    my $output;

    eval {

	$self->{tt}->process( $data->{template}, $data, \$output )
	    or die $self->{tt}->error();

	1;
    } or $self->warner()->wail( $@ );

    return $output;
}

sub template {
    my ( $self, $name, @value ) = @_;
    if ( @value ) {
	$self->{template}->__satpass2_template( $name, $value[0] );
	return $self;
    } else {
        return scalar $self->{template}->__satpass2_template( $name );
    }
}

sub tle {
    my ( $self, $array ) = @_;

    return $self->_tt( tle =>
	$self->_wrap( [ map { { body => $_ } } @{ $array } ] ) );
}

# TODO when we get the code right, _tle_celestia loses its leading
# underscore and gets documented.
sub _tle_celestia {	## no critic (ProhibitUnusedPrivateSubroutines)
    my ( $self, $array ) = @_;

    return $self->_tt( tle_celestia =>
	$self->_wrap( [ map { { body => $_ } } @{ $array } ] ) );
}

sub tle_verbose {
    my ( $self, $array ) = @_;

    return $self->_tt( tle_verbose =>
	$self->_wrap( [ map { { body => $_ } } @{ $array } ] ) );
}

sub tz {
    my ( $self, @args ) = @_;
    if ( @args ) {
	$self->time_formatter()->tz( @args );
	return $self->SUPER::tz( @args );
    } else {
	return $self->SUPER::tz();
    }
}

#	_is_report()
#
#	Returns true if the report() method is above us on the call
#	stack, otherwise returns false.

use constant REPORT_CALLER => __PACKAGE__ . '::report';
sub _is_report {
    my $level = 0;
    while ( my @info = caller( $level ) ) {
	REPORT_CALLER eq $info[3]
	    and return $level;
	$level++;
    }
    return;
}

sub _tt {
    my ( $self, $action, $data, $default ) = @_;

    $data or $self->warner()->wail( 'Argument is required' );

    _is_report() and return $data;

    $default ||= $self->__default();

    my $output;
    $self->{tt}->process( $action, {
	    data	=> $data,
	    title	=> ( $self->header() ?
		$self->_wrap( undef, $default ) : undef ),
	}, \$output )
	or $self->warner()->wail( $self->{tt}->error() )
    ;

    # TODO would love to use \h here, but that needs 5.10.
    $output =~ s/ [ \t]+ (?= \n ) //sxmg;
    return $output;
}

sub _wrap {
    my ( $self, $data, $default ) = @_;

    my $title = ! $data;
    $data ||= {};
    $default ||= $self->__default();

    if ( ! defined $data || 'HASH' eq ref $data ) {
	$data = Astro::App::Satpass2::FormatValue->new(
	    data	=> $data,
	    default	=> $default,
	    date_format => $self->date_format(),
	    desired_equinox_dynamical =>
			    $self->desired_equinox_dynamical(),
	    provider	=> $self->provider(),
	    time_format => $self->time_format(),
	    time_formatter => $self->time_formatter(),
	    local_coordinates => sub {
		my ( $data, @arg ) = @_;
		my $output;
		$self->{tt}->process( $self->local_coord(), {
			data	=> $data,
			arg	=> bless( \@arg,
			    'Astro::App::Satpass2::FormatValue::Argument' ),
			title	=> ( $self->header() ?
			    $self->_wrap( undef, $default ) : undef ),
		    }, \$output );
		return $output;
	    },
	    title	=> $title,
	    warner	=> $self->warner(),
	);
    } elsif ( 'ARRAY' eq ref $data ) {
	$data = [ map { $self->_wrap( $_ ) } @{ $data } ];
    }

    return $data;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Format::Template - Format Astro::App::Satpass2 output as text.

=head1 SYNOPSIS

 use strict;
 use warnings;
 
 use Astro::App::Satpass2::Format::Template;
 use Astro::Coord::ECI;
 use Astro::Coord::ECI::Moon;
 use Astro::Coord::ECI::Sun;
 use Astro::Coord::ECI::Utils qw{ deg2rad };
 
 my $time = time();
 my $moon = Astro::Coord::ECI::Moon->universal($time);
 my $sun = Astro::Coord::ECI::Sun->universal($time);
 my $station = Astro::Coord::ECI->new(
     name => 'White House',
 )->geodetic(
     deg2rad(38.8987),  # latitude
     deg2rad(-77.0377), # longitude
     17 / 1000);	# height above sea level, Km
 my $fmt = Astro::App::Satpass2::Format::Template->new();
 
 print $fmt->location( $station );
 print $fmt->position( {
	 bodies => [ $sun, $moon ],
	 station => $station,
	 time => $time,
     } );

=head1 NOTICE

This is alpha code. It has been tested on my box, but has limited
exposure to the wild. Also, the public interface may not be completely
stable, and may change if needed to support
L<Astro::App::Satpass2|Astro::App::Satpass2>. I will try to document any
incompatible changes.

=head1 DETAILS

This class is intended to perform output formatting for
L<Astro::App::Satpass2|Astro::App::Satpass2>, producing output similar
to that produced by the F<satpass> script distributed with
L<Astro::Coord::ECI|Astro::Coord::ECI>. It is a subclass of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, and
conforms to that interface.

The L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
interface specifies a set of methods corresponding (more or less) to the
interactive methods of L<Astro::App::Satpass2|Astro::App::Satpass2>.
This class implements those methods in terms of a canned set of
L<Template-Toolkit|Template> templates, with the data from the
L<Astro::App::Satpass2|Astro::App::Satpass2> methods wrapped in
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
objects to provide formatting at the field level. It is also possible to
use the L<report()|/report> method to execute a
L<Template-Toolkit|Template> file.

The names and contents of the templates used by each formatter are
described with each formatter. The templates may be retrieved or
modified using the L<template()|/template> method, or may be exported to
a working L<Template-Toolkit|Template> file using the
L<export()|/export> method.

=head1 METHODS

This class supports the following public methods. Methods inherited from
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format> are
documented here if this class adds significant functionality.

=head2 Instantiator

=head3 new

 $fmt = Astro::App::Satpass2::Format::Template->new();

This static method instantiates a new formatter.

=head2 Accessors and Mutators

=head3 local_coord

 print 'Local coord: ', $fmt->local_coord(), "\n";
 $fmt->local_coord( 'azel_rng' );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<local_coord()|Astro::App::Satpass2::Format/local_coord> method, and
performs the same function.

Out of the box, legal values for this are consistent with the
superclass' documentation; that is, C<'az_rng'>, C<'azel'>,
C<'azel_rng'>, C<'equatorial'>, and C<'equatorial_rng'>. These are
actually implemented as templates, as follows:

    az_rng        => <<'EOD',
    [% data.azimuth( arg, bearing = 2 ) %]
        [%= data.range( arg ) -%]
    EOD
 
    azel        => <<'EOD',
    [% data.elevation( arg ) %]
        [%= data.azimuth( arg, bearing = 2 ) -%]
    EOD
 
    azel_rng        => <<'EOD',
    [% data.elevation( arg ) %]
        [%= data.azimuth( arg, bearing = 2 ) %]
        [%= data.range( arg ) -%]
    EOD
 
    equatorial        => <<'EOD',
    [% data.right_ascension( arg ) %]
        [%= data.declination( arg ) -%]
    EOD
 
    equatorial_rng        => <<'EOD',
    [% data.right_ascension( arg ) %]
        [%= data.declination( arg ) %]
        [%= data.range( arg ) -%]
    EOD

These definitions can be changed, or new local coordinates added, using
the L<template()|/template> method.

=head2 Formatters

All the following formatters interact with L<Template-Toolkit|Template>
in precisely the same way. They pass it a canned template, and the
following variables:

=over

=item data

This is all the data produced by the relevant
L<Astro::App::Satpass2|Astro::App::Satpass2> method. Usually it is an
array reference, but occasionally it is a hash. The documentation of the
individual method says what is expected.

=item title

If defined at all, this is an
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
configured to produce field titles rather than data. If the
L<heading|/heading> attribute of this object is false, though, C<title>
will be undefined (and therefore also false). The moral is that any
template that makes use of this should check it first.

=back

The canned templates (except for those used to define C<local_coord>)
can all be used in the L<report()|/report> method, either as is or in a
file. See the L<report()|/report> method for that.

=head3 alias

 print $fmt->alias( \%alias_hash );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<alias()|Astro::App::Satpass2::Format/alias> method, and performs
the same function. It uses template C<alias>, which is defined as

 [% DEFAULT data = sp.alias( arg ) -%]
 [% FOREACH key IN data.keys.sort %]
     [%- key %] => [% data.$key %]
 [% END -%]

=head3 almanac

 print $fmt->almanac( [ \%almanac_hash ... ] );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<almanac()|Astro::App::Satpass2::Format/almanac> method, and performs
the same function. It uses template C<almanac>, which defaults to

 [% DEFAULT data = sp.almanac( arg ) -%]
 [% FOREACH item IN data %]
     [%- item.date %] [% item.time %]
         [%= item.almanac( units = 'description' ) %]
 [% END -%]

=head3 flare

 print $fmt->flare( [ \%flare_hash ... ] );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<flare()|Astro::App::Satpass2::Format/flare> method, and performs the
same function. It uses template C<flare>, which defaults to

 [% DEFAULT data = sp.flare( arg ) -%]
 [% IF title %]
     [%- title.time( '' ) %]
         [%= title.name( '', width = 12 ) %]
         [%= title.local_coord( '' ) %]
         [%= title.magnitude( '' ) %]
         [%= title.angle( 'Degrees' ) %]
 
     [%- title.time( '' ) %]
         [%= title.name( '', width = 12 ) %]
         [%= title.local_coord( '' ) %]
         [%= title.magnitude( '' ) %]
         [%= title.angle( 'From' ) %]
         [%= title.azimuth( 'Center', bearing = 2 ) %]
         [%= title.range( 'Center', width = 6 ) %]
 
     [%- title.time %]
         [%= title.name( width = 12 ) %]
         [%= title.local_coord %]
         [%= title.magnitude %]
         [%= title.angle( 'Sun' ) %]
         [%= title.azimuth( bearing = 2 ) %]
         [%= title.range( width = 6 ) %]
 [% END -%]
 [% prior_date = '' -%]
 [% FOR item IN data %]
     [%- center = item.center %]
     [%- current_date = item.date %]
     [%- IF prior_date != current_date %]
         [%- prior_date = current_date %]
         [%- current_date %]
 
     [%- END %]
     [%- item.time %]
         [%= item.name( units = 'title_case', width = 12 ) %]
         [%= item.local_coord %]
         [%= item.magnitude %]
         [%= IF 'day' == item.type( width = '' ) %]
             [%- item.appulse.angle %]
         [%- ELSE %]
             [%- title.angle( title = 'night' ) %]
         [%- END %]
         [%= center.azimuth( bearing = 2 ) %]
         [%= center.range( width = 6 ) %]
 [% END -%]

=head3 list

 print $fmt->list( [ $body ... ] );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<list()|Astro::App::Satpass2::Format/list> method, and performs the
same function. It uses template C<list>, which defaults to

 [% DEFAULT data = sp.list( arg ) -%]
 [% IF title %]
     [%- title.oid( align_left = 0 ) %]
         [%= title.name %]
         [%= title.epoch %]
         [%= title.period( align_left = 1 ) %]
 [% END -%]
 [% FOR item IN data %]
     [%- IF item.body.get( 'inertial' ) %]
         [%- item.oid %] [% item.name %] [% item.epoch %]
             [%= item.period( align_left = 1 ) %]
     [%- ELSE %]
         [%- item.oid %] [% item.name %] [% item.latitude %]
             [%= item.longitude %] [% item.altitude %]
     [%- END %]
 [% END -%]

=head3 location

 print $fmt->location( $eci );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<location()|Astro::App::Satpass2::Format/location> method, and performs
the same function. It uses template C<location>, which defaults to

 [% DEFAULT data = sp.location( arg ) -%]
 Location: [% data.name( width = '' ) %]
           Latitude [% data.latitude( places = 4,
                 width = '' ) %], longitude
             [%= data.longitude( places = 4, width = '' )
                 %], height
             [%= data.altitude( units = 'meters', places = 0,
                 width = '' ) %] m

=head3 pass

 print $fmt->pass( [ \%pass_hash ... ] );	# Pass data

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<pass()|Astro::App::Satpass2::Format/pass> method, and performs the
same function.

It uses template C<pass>, which defaults to

 [% DEFAULT data = sp.pass( arg ) -%]
 [% IF title %]
     [%- title.time( align_left = 0 ) %]
         [%= title.local_coord %]
         [%= title.latitude %]
         [%= title.longitude %]
         [%= title.altitude %]
         [%= title.illumination %]
         [%= title.event( width = '' ) %]
 [% END -%]
 [% FOR pass IN data %]
     [%- events = pass.events %]
     [%- evt = events() %]
 
     [%- evt.date %]    [% evt.oid %] - [% evt.name( width = '' ) %]
 
     [%- WHILE evt %]
         [%- evt.time %]
             [%= evt.local_coord %]
             [%= evt.latitude %]
             [%= evt.longitude %]
             [%= evt.altitude %]
             [%= evt.illumination %]
             [%= evt.event( width = '' ) %]
         [%- IF 'apls' == evt.event( units = 'string', width = '' ) %]
             [%- apls = evt.appulse %]
 
             [%- title.time( '' ) %]
                 [%= apls.local_coord %]
                 [%= apls.angle %] degrees from [% apls.name( width = '' ) %]
         [%- END %]
         [%- evt = events() %]
 
     [%- END %]
 [%- END -%]

=head3 phase

 print $fmt->phase( $body );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<phase()|Astro::App::Satpass2::Format/phase> method, and performs the
same function. It uses template C<phase>, which defaults to

 [% DEFAULT data = sp.phase( arg ) -%]
 [% IF title %]
     [%- title.date( align_left = 0 ) %]
         [%= title.time( align_left = 0 ) %]
         [%= title.name( width = 8, align_left = 0 ) %]
         [%= title.phase( places = 0, width = 4 ) %]
         [%= title.phase( width = 16, units = 'phase',
             align_left = 1 ) %]
         [%= title.fraction_lit( title = 'Lit', places = 0, width = 4,
             units = 'percent', align_left = 0 ) %]
 [% END -%]
 [% FOR item IN data %]
     [%- item.date %] [% item.time %]
         [%= item.name( width = 8, align_left = 0 ) %]
         [%= item.phase( places = 0, width = 4 ) %]
         [%= item.phase( width = 16, units = 'phase',
             align_left = 1 ) %]
         [%= item.fraction_lit( places = 0, width = 4,
             units = 'percent' ) %]%
 [% END -%]

=head3 position

 print $fmt->position( $position_hash );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<position()|Astro::App::Satpass2::Format/position> method, and performs
the same function. It uses template C<position>, which defaults to

 [% DEFAULT data = sp.position( arg ) -%]
 [%- data.date %] [% data.time %]
 [% IF title %]
     [%- title.name( align_left = 0, width = 16 ) %]
         [%= title.local_coord %]
         [%= title.epoch( align_left = 0 ) %]
         [%= title.illumination %]
 [% END -%]
 [% FOR item IN data.bodies() %]
     [%- item.name( width = 16, missing = 'oid', align_left = 0 ) %]
         [%= item.local_coord %]
         [%= item.epoch( align_left = 0 ) %]
         [%= item.illumination %]
 
     [%- FOR refl IN item.reflections() %]
         [%- title.name( '', width = 16 ) %]
             [%= title.local_coord( '' ) %] MMA
         [%- IF refl.status( width = '' ) %]
             [%= refl.mma( width = '' ) %] [% refl.status( width = '' ) %]
         [%- ELSE %]
             [%= refl.mma( width = '' ) %] mirror angle [%
                 refl.angle( width = '' ) %] magnitude [%
                 refl.magnitude( width = '' ) %]
         [%- END %]
 
     [%- END -%]
 [% END -%]

=head3 tle

 print $fmt->tle( $body );

This method overrides the L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<tle()|Astro::App::Satpass2::Format/tle> method, and performs the same
function. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, or something
equivalent. It uses template C<tle>, which defaults to

 [% DEFAULT data = sp.tle( arg ) -%]
 [% FOR item IN data %]
     [%- item.tle -%]
 [% END -%]

Note the absence of the trailing newline, which is assumed to be part of
the tle data itself.

=begin comment

# TODO when the code works, _tle_celestia loses its leading underscore.
# =head3 _tle_celestia

 print $fmt->tle_celestia( $body );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<tle_celestia()|Astro::App::Satpass2::Format/tle_celestia> method, and
performs the same function. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, or something
equivalent.

This method is unsupported because I have not yet gotten results that
put the International Space Station where it actually is.

This method uses template C<tle_celestia>, which defaults to

 [% DEFAULT data = sp.tle( arg ) -%]
 [% FOR item IN data %]
 # Keplerian elements for [% item.name( width = '' ) %]
 # Generated by [% item.provider %]
 # Epoch: [% item.epoch( units = 'zulu', width = '' ) %] UT
 
 Modify "[% item.name( width = '' ) %]" "Sol/Earth" {
     EllipticalOrbit {
         Epoch  [% item.epoch( units = 'julian', places = '', width = '' ) %]
         Period  [% item.period( units = 'days', places = '', width = '' ) %]
         SemiMajorAxis  [% item.semimajor( places = '', width = '' ) %]
         Eccentricity  [% item.eccentricity( places = '', width = '' ) %]
         Inclination  [% item.inclination( places = '', width = '' ) %]
         AscendingNode  [% item.ascending_node( units = 'degrees',
             places = '', width = '' ) %]
         ArgOfPericenter  [% item.argument_of_perigee( places = '',
             width = '' ) %]
         MeanAnomaly  [% item.mean_anomaly( places = '', width = '' ) %]
     }
     UniformRotation {
         Inclination  [% item.inclination( places = '', width = '' ) %]
         MeridianAngle  90
         AscendingNode  [% item.ascending_node( units = 'degrees',
             places = '', width = '' ) %]
     }
 }
 [% END -%]

=end comment

=head3 tle_verbose

 print $fmt->tle_verbose( $body );

This method overrides the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
L<tle_verbose()|Astro::App::Satpass2::Format/tle_verbose> method, and
performs the same function. Its argument is presumed to be an
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> object, or something
equivalent. It uses template C<tle_verbose>, which defaults to

 [% DEFAULT data = sp.tle( arg ) -%]
 [% FOR item IN data -%]
 NORAD ID: [% item.oid( width = '' ) %]
     Name: [% item.name( width = '' ) %]
     International launch designator: [% item.international( width = '' ) %]
     Epoch of data: [% item.epoch( units = 'zulu', width = '' ) %] GMT
     Effective date of data: [% item.effective_date( units = 'zulu',
         width = '', missing = '<none>' ) %] GMT
     Classification status: [% item.classification %]
     Mean motion: [% item.mean_motion( places = 8, width = '' )
         %] degrees/minute
     First derivative of motion: [% item.first_derivative( width = '',
         places = 8 ) %] degrees/minute squared
     Second derivative of motion: [% item.second_derivative( width = '',
         places = 5 ) %] degrees/minute cubed
     B Star drag term: [% item.b_star_drag( places = 5, width = '' ) %]
     Ephemeris type: [% item.ephemeris_type %]
     Inclination of orbit: [% item.inclination( places = 4, width = '' )
         %] degrees
     Right ascension of ascending node: [% item.ascending_node(
         places = 0, width = '' ) %]
     Eccentricity: [% item.eccentricity( places = 7, width = '' ) %]
     Argument of perigee: [% item.argument_of_perigee( places = 4,
         width = '' ) %] degrees from ascending node
     Mean anomaly: [% item.mean_anomaly( places = 4, width = '' ) %] degrees
     Element set number: [% item.element_number( width = '' ) %]
     Revolutions at epoch: [% item.revolutions_at_epoch( width = '' ) %]
     Period (derived): [% item.period( width = '' ) %]
     Semimajor axis (derived): [% item.semimajor( places = 1,
         width = '' ) %] kilometers
     Perigee altitude (derived): [% item.perigee( places = 1, width = '' )
         %] kilometers
     Apogee altitude (derived): [% item.apogee( places = 1, width = '' )
         %] kilometers
 [% END -%]

=head2 Other Methods

The following other methods are provided.

=head2 decode

 $fmt->decode( format_effector => 'azimuth' );

This method overrides the L<Astro::App::Satpass2::Format
decode()|Astro::App::Satpass2::Format/decode> method. In addition to
the functionality provided by the parent, the following methods return
something different when invoked via this method:

=over

=item format_effector

If called as an accessor, the name of the formatter accessed is
prepended to the returned array. If this leaves the returned array with
just one entry, the string C<'undef'> is appended. The return is still
an array in list context, and an array reference in scalar context.

If called as a mutator, you still get back the object reference.

=back

If a subclass overrides this method, the override should either perform
the decoding itself, or delegate to C<SUPER::decode>.

=head3 export

 $fmt->export( 'almanac', 'almanac.tt' );

This method writes the named canned template (in this case 'almanac') to
the given L<Template-Toolkit|Template> file (in this case 'almanac.tt').
If the file name is undefined or F<->, the canned template is written to
standard out.

The exported template should be usable as-is by the L<report()|/report>
method.

=head3 report

 $fmt->report( 'almanac.tt', \%arg );

The first argument to this method is a L<Template-Toolkit|Template>
file, which is to be executed. This template will be passed the C<%arg>
hash as its variable hash. In addition to what was passed in, a
C<{title}> key will be added, containing an empty
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
object configured to generate titles, not data.

The canned templates can also be run as reports, and in fact will be
taken in preference to files of the same name. If you do this, the
C<%arg> hash will need to have an
L<Astro::App::Satpass2|Astro::App::Satpass2> object in key C<{sp}>. If
you want titles, you will also need to provide an
C<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
object in key C<{title}>, instantiated with C<< title => 1 >>.

=head3 template

 print "Template 'almanac' is :\n", $fmt->template( 'almanac' );
 $fmt->template( almanac => <<'EOD' );
 [% DEFAULT data = sp.almanac( arg ) -%]
 [% FOREACH item IN data %]
     [%- item.date %] [% item.time %]
         [%= item.almanac( units = 'description' ) %]
 [% END -%]
 EOD

This method is not inherited from
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>.

If called with a single argument (the name of a template) this method is
an accessor that returns the named template. If the named template does
not exist, this method croaks.

If called with two arguments (the name of a template and the template
itself), this method is a mutator that sets the named template. If the
template is C<undef>, the named template is deleted. The object itself
is returned, to allow call chaining.

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
