package Astro::App::Satpass2::Format::Template;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Format };

use Astro::App::Satpass2::Format::Template::Provider;
use Astro::App::Satpass2::FormatValue;
use Astro::App::Satpass2::Utils qw{ instance };
use Astro::App::Satpass2::Wrap::Array;
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

our $VERSION = '0.007_03';

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

    almanac	=> <<'EOD',
[% DEFAULT data = sp.almanac( arg ) %]
[%- FOREACH item IN data %]
    [%- item.date %] [% item.time %]
        [%= item.almanac( units = 'description' ) %]
[% END -%]
EOD

    flare	=> <<'EOD',
[% DEFAULT data = sp.flare( arg ) %]
[%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
[%- WHILE title.more_title_lines %]
    [%- title.time %]
        [%= title.name( width = 12 ) %]
        [%= title.local_coord %]
        [%= title.magnitude %]
        [%= title.angle( 'Degrees From Sun' ) %]
        [%= title.azimuth( 'Center Azimuth', bearing = 2 ) %]
        [%= title.range( 'Center Range', width = 6 ) %]

[%- END %]
[%- prior_date = '' -%]
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
            [%- item.appulse.angle( literal = 'night' ) %]
        [%- END %]
        [%= center.azimuth( bearing = 2 ) %]
        [%= center.range( width = 6 ) %]
[% END -%]
EOD

    list => <<'EOD',
[% DEFAULT data = sp.list( arg ) %]
[%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
[%- WHILE title.more_title_lines %]
    [%- title.oid( align_left = 0 ) %]
        [%= title.name %]
        [%= title.epoch %]
        [%= title.period( align_left = 1 ) %]

[%- END %]
[%- FOR item IN data %]
    [%- IF item.inertial %]
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
[% DEFAULT data = sp.pass( arg ) %]
[%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
[%- WHILE title.more_title_lines %]
    [%- title.time( align_left = 0 ) %]
        [%= title.local_coord %]
        [%= title.latitude %]
        [%= title.longitude %]
        [%= title.altitude %]
        [%= title.illumination %]
        [%= title.event( width = '' ) %]

[%- END %]
[%- FOR pass IN data %]
    [%- events = pass.events %]
    [%- evt = events.first %]

    [%- evt.date %]    [% evt.oid %] - [% evt.name( width = '' ) %]

    [%- FOREACH evt IN events %]
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

    [%- END %]
[%- END -%]
EOD

    pass_events	=> <<'EOD',
[% DEFAULT data = sp.pass( arg ) %]
[%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
[%- WHILE title.more_title_lines %]
    [%- title.date %] [% title.time %]
        [%= title.oid %] [% title.event %]
        [%= title.illumination %] [% title.local_coord %]

[%- END %]
[%- FOREACH evt IN data.events %]
    [%- evt.date %] [% evt.time %]
        [%= evt.oid %] [% evt.event %]
        [%= evt.illumination %] [% evt.local_coord %]
[% END -%]
EOD

    phase	=> <<'EOD',
[% DEFAULT data = sp.phase( arg ) -%]
[%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
[%- WHILE title.more_title_lines %]
    [%- title.date( align_left = 0 ) %]
        [%= title.time( align_left = 0 ) %]
        [%= title.name( width = 8, align_left = 0 ) %]
        [%= title.phase( places = 0, width = 4 ) %]
        [%= title.phase( width = 16, units = 'phase',
            align_left = 1 ) %]
        [%= title.fraction_lit( title = 'Lit', places = 0, width = 4,
            units = 'percent', align_left = 0 ) %]

[%- END %]
[%- FOR item IN data %]
    [%- item.date %] [% item.time %]
        [%= item.name( width = 8, align_left = 0 ) %]
        [%= item.phase( places = 0, width = 4 ) %]
        [%= item.phase( width = 16, units = 'phase',
            align_left = 1 ) %]
        [%= item.fraction_lit( places = 0, width = 4,
            units = 'percent' ) %]%
[% END -%]
EOD

    position	=> <<'EOD',
[% DEFAULT data = sp.position( arg ) %]
[%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
[%- data.date %] [% data.time %]
[%- WHILE title.more_title_lines %]
    [%- title.name( align_left = 0, width = 16 ) %]
        [%= title.local_coord %]
        [%= title.epoch( align_left = 0 ) %]
        [%= title.illumination %]

[%- END %]
[%- FOR item IN data.bodies() %]
    [%- item.name( width = 16, missing = 'oid', align_left = 0 ) %]
        [%= item.local_coord %]
        [%= item.epoch( align_left = 0 ) %]
        [%= item.illumination %]

    [%- FOR refl IN item.reflections() %]
        [%- item.name( literal = '', width = 16 ) %]
            [%= item.local_coord( literal = '' ) %] MMA
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

    tle		=> <<'EOD',
[% DEFAULT data = sp.tle( arg ) -%]
[% FOR item IN data %]
    [%- item.tle -%]
[% END -%]
EOD

    tle_verbose	=> <<'EOD',
[% DEFAULT data = sp.tle( arg ) -%]
[% CALL title.fixed_width( 0 ) -%]
[% FOR item IN data -%]
[% CALL item.fixed_width( 0 ) -%]
[% title.oid %]: [% item.oid %]
    [% title.name %]: [% item.name %]
    [% title.international %]: [% item.international %]
    [% title.epoch %]: [% item.epoch( units = 'zulu' ) %] GMT
    [% title.effective_date %]: [%
        item.effective_date( units = 'zulu',
        missing = '<none>' ) %] GMT
    [% title.classification %]: [% item.classification %]
    [% title.mean_motion %]: [% item.mean_motion( places = 8 )
        %] degrees/minute
    [% title.first_derivative %]: [%
        item.first_derivative( places = 8 ) %] degrees/minute squared
    [% title.second_derivative %]: [%
        item.second_derivative( places = 5 ) %] degrees/minute cubed
    [% title.b_star_drag %]: [% item.b_star_drag( places = 5 ) %]
    [% title.ephemeris_type %]: [% item.ephemeris_type %]
    [% title.inclination %]: [% item.inclination( places = 4 ) %] degrees
    [% title.ascending_node %]: [% item.ascending_node(
        places = 0 ) %] in right ascension
    [% title.eccentricity %]: [% item.eccentricity( places = 7 ) %]
    [% title.argument_of_perigee %]: [%
        item.argument_of_perigee( places = 4 )
        %] degrees from ascending node
    [% title.mean_anomaly %]: [%
        item.mean_anomaly( places = 4 ) %] degrees
    [% title.element_number %]: [% item.element_number %]
    [% title.revolutions_at_epoch %]: [% item.revolutions_at_epoch %]
    [% title.period %]: [% item.period %]
    [% title.semimajor %]: [% item.semimajor( places = 1 ) %] kilometers
    [% title.perigee %]: [% item.perigee( places = 1 ) %] kilometers
    [% title.apogee %]: [% item.apogee( places = 1 ) %] kilometers
[% END -%]
EOD

);


sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new( @args );

    $self->{template} =
	Astro::App::Satpass2::Format::Template::Provider->new()
	or $self->warner()->weep( 'Failed to instantiate provider' );

    $self->{tt} = Template->new( {
	    LOAD_TEMPLATES => [
		$self->{template},
		Template::Provider->new(),
	    ],
	}
    ) or $self->warner()->weep(
	"Failed to instantate tt: $Template::ERROR" );

    while ( my ( $name, $def ) = each %template_definitions ) {
	$self->template( $name => $def );
    }

    $self->{default} = {};

    return $self;
}

sub config {
    my ( $self, %args ) = @_;
    my @data = $self->SUPER::config( %args );

    # TODO support for the {default} key.

    foreach my $name ( sort
	$self->{template}->__satpass2_defined_templates() ) {
	my $template = $self->{template}->__satpass2_template( $name );
	$args{changes}
	    and defined $template
	    and $template eq $template_definitions{$name}
	    and next;
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

sub format : method {	## no critic (ProhibitBuiltInHomonyms)
    my ( $self, %data ) = @_;

    exists $data{data}
	and $data{data} = $self->_wrap( $data{data} );

    _is_format() and return $data{data};

    my $template = delete $data{template}
	or $self->warner()->wail( 'template argument is required' );

    $data{default} ||= $self->__default();

    $data{instantiate} = sub {
	my @args = @_;
	my $class = Astro::App::Satpass2::Utils::load_package( @args );
	return $class->new();
    };

    $data{provider} ||= $self->provider();

    if ( $data{time} ) {
	ref $data{time}
	    or $data{time} = $self->_wrap( { time => $data{time} } );
    } else {
	$data{time} = $self->_wrap( { time => time } );
    }

    $data{title} = $self->_wrap( undef, $data{default} );
    $data{TITLE_GRAVITY_BOTTOM} =
	Astro::App::Satpass2::FormatValue->TITLE_GRAVITY_BOTTOM;
    $data{TITLE_GRAVITY_TOP} =
	Astro::App::Satpass2::FormatValue->TITLE_GRAVITY_TOP;

    if ( 'ARRAY' eq ref $data{arg} ) {
	my @arg = @{ $data{arg} };
	$data{arg} = Astro::App::Satpass2::Wrap::Array->new( \@arg );
    }

    my $output;

    local $Template::Stash::LIST_OPS->{bodies} = sub {
	my ( $list ) = @_;
	return [ map { $_->body() } @{ $list } ];
    };

    local $Template::Stash::LIST_OPS->{events} = sub {
	my @args = @_;
	return $self->_all_events( @args );
    };

    local $Template::Stash::LIST_OPS->{fixed_width} = sub {
	my ( $list, $value ) = @_;
	foreach my $item ( @{ $list } ) {
	    my $code = $item->can( 'fixed_width' )
		or next;
	    $code->( $item, $value );
	}
	return;
    };

    $self->{tt}->process( $template, \%data, \$output )
	or $self->warner()->wail( $self->{tt}->error() );

    # TODO would love to use \h here, but that needs 5.10.
    $output =~ s/ [ \t]+ (?= \n ) //sxmg;
    $data{title}->title_gravity() eq $data{TITLE_GRAVITY_BOTTOM}
	and $output =~ s/ \A \n //smx;

    return $output;
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

sub template {
    my ( $self, $name, @value ) = @_;
    defined $name
	or $self->warner()->wail( 'Template name not specified' );

    if ( @value ) {
	$self->{template}->__satpass2_template( $name, $value[0] );
	return $self;
    } else {
        return scalar $self->{template}->__satpass2_template( $name );
    }
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

sub _all_events {
    my ( $self, $data ) = @_;
    'ARRAY' eq ref $data or return;

    my @events;
    foreach my $pass ( @{ $data } ) {
	push @events, $pass->__raw_events();
    }
    @events or return;
    @events = sort { $a->{time} <=> $b->{time} } @events;

    return [ map { $self->_wrap( $_ ) } @events ];
}

#	_is_format()
#
#	Returns true if the format() method is above us on the call
#	stack, otherwise returns false.

use constant REPORT_CALLER => __PACKAGE__ . '::format';
sub _is_format {
    my $level = 2;	# Start with caller's caller.
    while ( my @info = caller( $level ) ) {
	REPORT_CALLER eq $info[3]
	    and return $level;
	$level++;
    }
    return;
}

sub _wrap {
    my ( $self, $data, $default ) = @_;

    my $title = ! $data;
    $data ||= {};
    $default ||= $self->__default();

    if ( instance( $data, 'Astro::App::Satpass2::FormatValue' ) ) {
	# Do nothing
    } elsif ( ! defined $data || 'HASH' eq ref $data ) {
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
			arg	=>
			    Astro::App::Satpass2::Wrap::Array->new( \@arg ),
			title	=> $self->_wrap( undef, $default ),
		    }, \$output );
		return $output;
	    },
	    title	=> $title,
	    warner	=> $self->warner(),
	);
    } elsif ( 'ARRAY' eq ref $data ) {
	$data = [ map { $self->_wrap( $_ ) } @{ $data } ];
    } elsif ( embodies( $data, 'Astro::Coord::ECI' ) ) {
	$data = $self->_wrap( { body => $data } );
    }

    return $data;
}

__PACKAGE__->create_attribute_methods();

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
objects to provide formatting at the field level.

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

As stated in the
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>
documentation, there is actually only one formatter method:

=head3 format

  print $fmtr->format( template => 'location', data => $sta );

This formatter implements the C<format()> method using
L<Template-Toolkit|Template>.  The C<template> argument is required, and
selects one of the canned templates provided.  The C<data> argument is
required unless your templates are capable of calling
L<Astro::App::Satpass2|Astro::App::Satpass2> methods on their own
account, and must (if provided) be whatever is expected by the template.
See L<Templates|/Templates> below for the details.

This method can also execute an arbitrary template if you pass an
L<Astro::App::Satpass2|Astro::App::Satpass2> object in the C<sp>
argument. These templates can call methods on the C<sp> object to
generate their data. If a method which calls the C<format()> method on
its own behalf (like C<almanac()>) is called on the C<sp> object, the
recursive call is detected, and the data are passed back to the calling
template. If arguments for L<Astro::App::Satpass2|Astro::App::Satpass2>
methods are passed in, it is strongly recommended that they be passed in
the C<arg> argument.

Except for the C<template> argument, all named arguments to C<format()>
are provided to the template. In addition, the following arguments will
be provided:

=over

=item instantiate

You can pass one or more class names as arguments. The argument is a
class name which is loaded by passed to the
L<Astro::App::Satpass2::Utils|Astro::App::Satpass2::Utils>
L<load_package()|Astro::App::Satpass2::Utils/load_package>. If the load
succeeds, an object is instantiated by calling C<new()> on the loaded
class name, and that object is returned. If no class can be loaded an
exception is thrown.

=item provider

This is simply the value returned by L<provider()|/provider>.

=item time

This is the current time wrapped in an
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
object.

=item title

This is an
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
configured to produce field titles rather than data.

=item TITLE_GRAVITY_BOTTOM

This manifest constant is defined in
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>.
See the
L<title_gravity()|Astro::App::Satpass2::FormatValue/title_gravity>
documentation for the details.

If the C<title> object has its C<title_gravity()> set to this value
after template processing, and the output of the template has a leading
newline, that newline is removed. See the
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
L<title_gravity()|Astro::App::Satpass2::FormatValue/title_gravity>
documentation for why this hack was imposed on the output.

=item TITLE_GRAVITY_TOP

This manifest constant is defined in
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>.
See the
L<title_gravity()|Astro::App::Satpass2::FormatValue/title_gravity>
documentation for the details.

=back

In addition to any variables passed in, the following array methods are
defined for C<Template-Toolkit> before it is invoked:

=over

=item bodies

If called on an array of objects, returns a reference to the results of
calling body() on each of the objects. This is good for (e.g.)
recovering a bunch of L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE>
objects from their containing
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
objects.

=item events

If called on an array of passes, returns all events in all passes, in
chronological order.

=item fixed_width

If called on an array of
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
objects, calls
L<fixed_width()|Astro::App::Satpass2::FormatValue/fixed_width> on them.
You may specify an argument to C<fixed_width()>.

Nothing is returned.

=back

=head2 Templates

The required values of the C<template> argument are supported by
same-named L<Template-Toolkit|Template> templates, as follows. The
C<data> provided should be as described in the documentation for the
L<Astro::App::Satpass2|Astro::App::Satpass2>
L<format()|Astro::App::Satpass2/format> method.  if the C<data> value is
not provided, each of the default templates will call an appropriate
L<Astro::App::Satpass2|Astro::App::Satpass2> method on the C<sp> value,
passing it the C<arg> value as arguments.

=head3 almanac

This template defaults to

 [% DEFAULT data = sp.almanac( arg ) %]
 [%- FOREACH item IN data %]
     [%- item.date %] [% item.time %]
         [%= item.almanac( units = 'description' ) %]
 [% END -%]

=head3 flare

This template defaults to

 [% DEFAULT data = sp.flare( arg ) %]
 [%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
 [%- WHILE title.more_title_lines %]
     [%- title.time %]
         [%= title.name( width = 12 ) %]
         [%= title.local_coord %]
         [%= title.magnitude %]
         [%= title.angle( 'Degrees From Sun' ) %]
         [%= title.azimuth( 'Center Azimuth', bearing = 2 ) %]
         [%= title.range( 'Center Range', width = 6 ) %]
 
 [%- END %]
 [%- prior_date = '' -%]
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
             [%- item.appulse.angle( literal = 'night' ) %]
         [%- END %]
         [%= center.azimuth( bearing = 2 ) %]
         [%= center.range( width = 6 ) %]
 [% END -%]

=head3 list

This template defaults to

 [% DEFAULT data = sp.list( arg ) %]
 [%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
 [%- WHILE title.more_title_lines %]
     [%- title.oid( align_left = 0 ) %]
         [%= title.name %]
         [%= title.epoch %]
         [%= title.period( align_left = 1 ) %]
 
 [%- END %]
 [%- FOR item IN data %]
     [%- IF item.inertial %]
         [%- item.oid %] [% item.name %] [% item.epoch %]
             [%= item.period( align_left = 1 ) %]
     [%- ELSE %]
         [%- item.oid %] [% item.name %] [% item.latitude %]
             [%= item.longitude %] [% item.altitude %]
     [%- END %]
 [% END -%]

=head3 location

This template defaults to

 [% DEFAULT data = sp.location( arg ) -%]
 Location: [% data.name( width = '' ) %]
           Latitude [% data.latitude( places = 4,
                 width = '' ) %], longitude
             [%= data.longitude( places = 4, width = '' )
                 %], height
             [%= data.altitude( units = 'meters', places = 0,
                 width = '' ) %] m

=head3 pass

This template defaults to

 [% DEFAULT data = sp.pass( arg ) %]
 [%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
 [%- WHILE title.more_title_lines %]
     [%- title.time( align_left = 0 ) %]
         [%= title.local_coord %]
         [%= title.latitude %]
         [%= title.longitude %]
         [%= title.altitude %]
         [%= title.illumination %]
         [%= title.event( width = '' ) %]
 
 [%- END %]
 [%- FOR pass IN data %]
     [%- events = pass.events %]
     [%- evt = events.first %]
 
     [%- evt.date %]    [% evt.oid %] - [% evt.name( width = '' ) %]
 
     [%- FOREACH evt IN events %]
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
 
     [%- END %]
 [%- END -%]

=head3 pass_events

This template defaults to

 [% DEFAULT data = sp.pass( arg ) %]
 [%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
 [%- WHILE title.more_title_lines %]
     [%- title.date %] [% title.time %]
         [%= title.oid %] [% title.event %]
         [%= title.illumination %] [% title.local_coord %]
 
 [%- END %]
 [%- FOREACH evt IN data.events %]
     [%- evt.date %] [% evt.time %]
         [%= evt.oid %] [% evt.event %]
         [%= evt.illumination %] [% evt.local_coord %]
 [% END -%]

The difference between this template and the L<pass|/pass> template is
that this template orders the events chronologically, without respect to
their source, whereas the L<pass|/pass> template orders passes
chronologically by satellite.

=head3 phase

This template defaults to

 [% DEFAULT data = sp.phase( arg ) -%]
 [%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
 [%- WHILE title.more_title_lines %]
     [%- title.date( align_left = 0 ) %]
         [%= title.time( align_left = 0 ) %]
         [%= title.name( width = 8, align_left = 0 ) %]
         [%= title.phase( places = 0, width = 4 ) %]
         [%= title.phase( width = 16, units = 'phase',
             align_left = 1 ) %]
         [%= title.fraction_lit( title = 'Lit', places = 0, width = 4,
             units = 'percent', align_left = 0 ) %]
 
 [%- END %]
 [%- FOR item IN data %]
     [%- item.date %] [% item.time %]
         [%= item.name( width = 8, align_left = 0 ) %]
         [%= item.phase( places = 0, width = 4 ) %]
         [%= item.phase( width = 16, units = 'phase',
             align_left = 1 ) %]
         [%= item.fraction_lit( places = 0, width = 4,
             units = 'percent' ) %]%
 [% END -%]

=head3 position

This template defaults to

 [% DEFAULT data = sp.position( arg ) %]
 [%- CALL title.title_gravity( TITLE_GRAVITY_BOTTOM ) %]
 [%- data.date %] [% data.time %]
 [%- WHILE title.more_title_lines %]
     [%- title.name( align_left = 0, width = 16 ) %]
         [%= title.local_coord %]
         [%= title.epoch( align_left = 0 ) %]
         [%= title.illumination %]
 
 [%- END %]
 [%- FOR item IN data.bodies() %]
     [%- item.name( width = 16, missing = 'oid', align_left = 0 ) %]
         [%= item.local_coord %]
         [%= item.epoch( align_left = 0 ) %]
         [%= item.illumination %]
 
     [%- FOR refl IN item.reflections() %]
         [%- item.name( literal = '', width = 16 ) %]
             [%= item.local_coord( literal = '' ) %] MMA
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

This template defaults to

 [% DEFAULT data = sp.tle( arg ) -%]
 [% FOR item IN data %]
     [%- item.tle -%]
 [% END -%]

Note the absence of the trailing newline, which is assumed to be part of
the tle data itself.

=head3 tle_verbose

This template defaults to

 [% DEFAULT data = sp.tle( arg ) -%]
 [% CALL title.fixed_width( 0 ) -%]
 [% FOR item IN data -%]
 [% CALL item.fixed_width( 0 ) -%]
 [% title.oid %]: [% item.oid %]
     [% title.name %]: [% item.name %]
     [% title.international %]: [% item.international %]
     [% title.epoch %]: [% item.epoch( units = 'zulu' ) %] GMT
     [% title.effective_date %]: [%
         item.effective_date( units = 'zulu',
         missing = '<none>' ) %] GMT
     [% title.classification %]: [% item.classification %]
     [% title.mean_motion %]: [% item.mean_motion( places = 8 )
         %] degrees/minute
     [% title.first_derivative %]: [%
         item.first_derivative( places = 8 ) %] degrees/minute squared
     [% title.second_derivative %]: [%
         item.second_derivative( places = 5 ) %] degrees/minute cubed
     [% title.b_star_drag %]: [% item.b_star_drag( places = 5 ) %]
     [% title.ephemeris_type %]: [% item.ephemeris_type %]
     [% title.inclination %]: [% item.inclination( places = 4 ) %] degrees
     [% title.ascending_node %]: [% item.ascending_node(
         places = 0 ) %] in right ascension
     [% title.eccentricity %]: [% item.eccentricity( places = 7 ) %]
     [% title.argument_of_perigee %]: [%
         item.argument_of_perigee( places = 4 )
         %] degrees from ascending node
     [% title.mean_anomaly %]: [%
         item.mean_anomaly( places = 4 ) %] degrees
     [% title.element_number %]: [% item.element_number %]
     [% title.revolutions_at_epoch %]: [% item.revolutions_at_epoch %]
     [% title.period %]: [% item.period %]
     [% title.semimajor %]: [% item.semimajor( places = 1 ) %] kilometers
     [% title.perigee %]: [% item.perigee( places = 1 ) %] kilometers
     [% title.apogee %]: [% item.apogee( places = 1 ) %] kilometers
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

=head3 report

 $fmt->report( template => $template, ... );

This method represents the interface to L<Template-Toolkit|Template>,
and all the L</Formatter> methods come through here eventually.

The arguments to this method are name/value pairs. The C<template>
argument is required, and is either the name of a template file, or a
reference to a string containing the template. All other arguments are
passed to C<Template-Toolkit> as variables. If argument C<arg> is
specified and its value is an array reference, the value is enclosed in
an
L<Astro::App::Satpass2::Wrap::Array|Astro::App::Satpass2::Wrap::Array>
object, since by convention this is the argument passed back to
L<Astro::App::Satpass2|Astro::App::Satpass2> methods.

In addition to any variables passed in, the following array methods are
defined for C<Template-Toolkit> before it is invoked:

=over

=item events

If called on an array of passes, returns all events in all passes, in
chronological order.

=item fixed_width

If called on an array of
L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>
objects, calls
L<fixed_width()|Astro::App::Satpass2::FormatValue/fixed_width> on them.
You may specify an argument to C<fixed_width()>.

Nothing is returned.

=back

The canned templates can also be run as reports, and in fact will be
taken in preference to files of the same name. If you do this, you will
need to pass the relevant L<Astro::App::Satpass2|Astro::App::Satpass2>
object as the C<sp> argument, since by convention the canned templates
all look to that variable to compute their data if they do not already
have a C<data> variable.

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

Copyright (C) 2010-2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
