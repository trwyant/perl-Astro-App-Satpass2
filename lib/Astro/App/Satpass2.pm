package Astro::App::Satpass2;

use 5.006002;

use strict;
use warnings;

use Carp;

use Astro::App::Satpass2::ParseTime;
use Astro::App::Satpass2::Utils qw{ instance load_package quoter };

use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Astro::Coord::ECI::Star;
use Astro::Coord::ECI::Sun;
use Astro::Coord::ECI::TLE qw{:constants};
use Astro::Coord::ECI::TLE::Iridium;
use Astro::Coord::ECI::TLE::Set;
use Astro::Coord::ECI::Utils qw{:all};

use Clone ();
use Cwd ();
use File::Glob qw{ :glob };
use File::HomeDir;
use File::Temp;
use Getopt::Long;
use IO::File;
use IO::Handle;
use IPC::System::Simple qw{ capturex };
use POSIX qw{ floor };
use Scalar::Util qw{ blessed openhandle };
use Text::Abbrev;
use Text::ParseWords ();	# Used only for {level1} stuff.

use constant ASTRO_SPACETRACK_VERSION => 0.050;

my ( $got_time_hires, $got_astro_spacetrack );

BEGIN {

    $got_time_hires = eval {
	require Time::HiRes;
	1;
    };

    $got_astro_spacetrack = eval {
	require Astro::SpaceTrack;
	Astro::SpaceTrack->VERSION( ASTRO_SPACETRACK_VERSION );
	1;
    };

    eval {
	require Time::y2038;
	Time::y2038->import();
	1;
    } or do {
	require Time::Local;
	Time::Local->import();
    };
}

our $VERSION = '0.000_12';

my $interrupted = 'Interrupted by user.';

my %twilight_def = (
    civil => deg2rad (-6),
    nautical => deg2rad (-12),
    astronomical => deg2rad (-18),
);
my %twilight_abbr = abbrev (keys %twilight_def);

#	Individual commands are defined by subroutines of the same name,
#	and having the Verb attribute. You can specify additional
#	attributes if you need to. Following are descriptions of the
#	attributes used by  this script.
#
#	Configure(configurations)
#
#	The 'Configure' attribute specifies options to be passed to
#	Getopt::Long::Configure before the options are parsed. For
#	example, if a command wants to keep unrecognized options on the
#	command you would specify:
#	    sub foo : Configure(pass_through) Verb
#
#	Verb(options)
#
#	The 'Verb' attribute identifies the subroutine as representing a
#	cvsx command. If it has options, they should be specified inside
#	parentheses as a whitespace-separated list of option
#	specifications appropriate for Getopt::Long. For example:
#	    sub foo : Verb(bar baz=s)
#	specifies that 'foo' is a command, taking options -bar, and
#	-baz; the latter takes a string value.

{
    my (%attr, %want);
    BEGIN {
	%want = map {$_ => 1} qw{Configure Verb};
    }

    sub FETCH_CODE_ATTRIBUTES {
	return $attr{$_[0]};
    }

    sub MODIFY_CODE_ATTRIBUTES {
	my ($pkg, $code, @args) = @_;
	my @rslt;
	foreach (@args) {
	    m{ ( [^(]* ) (?: [(] \s* (.*?) \s* [)] )? \z }smx or do {
		push @rslt, $_;
		next;
	    };
	    if ($want{$1}) {
		$attr{$code}{$1} = defined $2 ?
		    [ split qr{ \s+ }smx, $2 ] :
		    [];
	    } else {
		push @rslt, $_;
	    }
	}
	return @rslt;
    }

    sub _get_attr {
	my ($code, $name) = @_;
	defined $name or return $attr{$code};
	return $attr{$code}{$name};
    }
}

my %mutator = (
    appulse => \&_set_angle,
    autoheight => \&_set_unmodified,
    backdate => \&_set_unmodified,
    background => \&_set_unmodified,
    continuation_prompt => \&_set_unmodified,
    country => \&_set_unmodified,
    date_format => \&_set_formatter_attribute,
    desired_equinox_dynamical => \&_set_formatter_attribute,
    debug => \&_set_unmodified,
    echo => \&_set_unmodified,
    ellipsoid => \&_set_ellipsoid,
    error_out => \&_set_unmodified,
    exact_event => \&_set_unmodified,
    execute_filter => \&_set_code_ref,	# Undocumented and unsupported
    explicit_macro_delete => \&_set_unmodified,
    extinction => \&_set_unmodified,
    filter => \&_set_unmodified,
    flare_mag_day => \&_set_unmodified,
    flare_mag_night => \&_set_unmodified,
    formatter => \&_set_formatter,
    geometric => \&_set_unmodified,
    gmt => \&_set_formatter_attribute,
    height => \&_set_distance_meters,
    horizon => \&_set_angle,
    latitude => \&_set_angle,
    lit => \&_set_unmodified,
    local_coord => \&_set_formatter_attribute,
    location => \&_set_unmodified,
    longitude => \&_set_angle,
    model => \&_set_model,
    perltime => \&_set_time_parser_attribute,
    prompt => \&_set_unmodified,
    simbad_url => \&_set_unmodified,
    singleton => \&_set_unmodified,
    spacetrack => \&_set_spacetrack,
    stdout => \&_set_stdout,
    time_format => \&_set_formatter_attribute,
    time_parser => \&_set_time_parser,
##    timing => \&_set_unmodified,
    twilight => \&_set_twilight,  # 'civil', 'nautical', 'astronomical'
				# (or a unique abbreviation thereof),
				# or degrees above (positive) or below
				# (negative) the geometric horizon.
    tz => \&_set_tz,
    verbose => \&_set_unmodified, # 0 = events only
				# 1 = whenever above horizon
				# 2 = anytime
    visible => \&_set_unmodified, # 1 = only if sun down & sat illuminated
    warning => \&_set_warner_attribute,	# True to warn/die; false to carp/croak.
    warn_on_empty => \&_set_unmodified,
    				# True to have list commands warn on
				# an empty list.
    webcmd => \&_set_webcmd,	# Command to spawn for web pages
);

my %accessor = (
    date_format => \&_get_formatter_attribute,
    desired_equinox_dynamical => \&_get_formatter_attribute,
    gmt => \&_get_formatter_attribute,
    local_coord => \&_get_formatter_attribute,
    perltime => \&_get_time_parser_attribute,
    time_format => \&_get_formatter_attribute,
    tz => \&_get_time_parser_attribute,
    warning => \&_get_warner_attribute,
);

foreach ( keys %mutator, qw{ initfile } ) {
    $accessor{$_} ||= sub { return $_[0]->{$_[1]} };
}

my %shower = (
    date_format => \&_show_formatter_attribute,
    formatter => \&_show_copyable,
    desired_equinox_dynamical => \&_show_formatter_attribute,
    gmt => \&_show_formatter_attribute,
    local_coord => \&_show_formatter_attribute,
    time_parser => \&_show_copyable,
    time_format => \&_show_formatter_attribute,
);
foreach ( keys %accessor ) { $shower{$_} ||= \&_show_unmodified }

#	Attributes which must be set programmatically (i.e. not
#	interactively or in the initialization file).

my %nointeractive = map {$_ => 1} qw{
    execute_filter
    spacetrack
    stdout
};

#	Initial object contents
#
#	CAVEAT: only scalars here, since we do a shallow clone to create
#	the object from this.

my %static = (
    appulse => 0,
    autoheight => 1,
    background => 1,
    backdate => 0,
    continuation_prompt => '> ',
##  country => 'us',				# Deprecated
    date_format => '%a %d-%b-%Y',
    debug => 0,
    echo => 0,
    ellipsoid => Astro::Coord::ECI->get ('ellipsoid'),
    error_out => 0,
    exact_event => 1,
    execute_filter => sub { return 1 },	# Undocumented and unsupported
##  explicit_macro_delete => 1,			# Deprecated
    extinction => 1,
    filter => 0,
    flare_mag_day => -6,
    flare_mag_night => 0,
    formatter => 'Astro::App::Satpass2::Format::Classic',	# Formatter class.
    geometric => 1,
    height => undef,		# meters
#   initfile => undef,		# Set by init()
    horizon => 20,		# degrees
    latitude => undef,		# degrees
    lit => 1,
    longitude => undef,		# degrees
    model => 'model',
#   pending => undef,		# Continued input line if it exists.
    perltime => 0,
    prompt => 'satpass2> ',
    simbad_url => 'simbad.u-strasbg.fr',
    singleton => 0,
#   spacetrack => undef,	# Astro::SpaceTrack object set in new().
#   stdout => undef,		# Set to stdout in new().
    time_parser => 'Astro::App::Satpass2::ParseTime',	# Time parser class.
    twilight => 'civil',
    tz => $ENV{TZ},
    verbose => 0,
    visible => 1,
    warning => 0,
    warn_on_empty => 1,
    webcmd => ''
);

sub new {
    my ( $class, %args ) = @_;
    ref $class and $class = ref $class;
    my $self = {};
    $self->{bodies} = [];
    $self->{macro} = {};
    $self->{sky} = [
	Astro::Coord::ECI::Sun->new (),
	Astro::Coord::ECI::Moon->new (),
    ];
    bless $self, $class;
    $self->_frame_push(initial => []);
    $self->set(stdout => select());

    foreach my $name ( keys %static ) {
	exists $args{$name} or $args{$name} = $static{$name};
    }

    not exists $args{spacetrack}
	and $got_astro_spacetrack
	and $args{spacetrack} = $self->_get_spacetrack_default();

    my $warner = $self->{_warner} = Astro::App::Satpass2::Warner->new(
	warning => delete $args{warning}
    );

    foreach my $name ( qw{ formatter time_parser } ) {
	$self->set( $name => delete $args{$name} );
	$self->tell( $name, warner => $warner );
    }

    $self->set( %args );

    return $self;
}

sub alias : Verb( dump! ) {
    my ( $self, @args ) = @_;
    ( my $opt, @args ) = $self->_getopt( @args );
    if ( @args ) {
	Astro::Coord::ECI::TLE->alias( @args );
	return;
    } else {
	return $self->_format_data(
	    alias => { Astro::Coord::ECI::TLE->alias() }, $opt );
    }
}

sub almanac : Verb( choose=s@ dump! horizon|rise|set! transit! 
    twilight! quarter! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    _apply_boolean_default(
	$opt, 0, qw{ horizon transit twilight quarter } );

    $self->_parse_time_reset();
    my $almanac_start = $self->_parse_time(
	shift @args, $self->_get_today_midnight());
    my $almanac_end = $self->_parse_time (shift @args || '+1');

    $almanac_start >= $almanac_end
	and $self->_wail("End time must be after start time");

#	Build an object representing our ground location.

    my $sta = $self->_get_station();

##  my $id = looks_like_number($self->{twilight}) ?
##	"twilight ($self->{twilight} degrees)" :
##	"$self->{twilight} twilight (@{[rad2deg $self->{_twilight}]} degrees)";

    my @almanac;

#	Iterate through the background bodies, accumulating data or
#	complaining about the lack of an almanac() method as
#	appropriate.

    my @sky = @{ $opt->{choose} ?
	    scalar _choose($opt->{choose}, $self->{sky}) :
	    $self->{sky} }
	or $self->_wail( 'No bodies selected' );

    foreach my $body ( @sky ) {
	$body->can ('almanac') or do {
	    $self->_whinge(
		ref $body, ' does not support the almanac method');
	    next;
	};
	$body->set (
	    twilight => $self->{_twilight},
	);
	push @almanac, $body->almanac_hash(
	    $sta, $almanac_start, $almanac_end);
    }

#	Sort the almanac data by date, and display the results.

    $self->{frame}[-1]{level1}
	and return $self->location() . $self->_format_data(
	    almanac => [
		sort { $a->{time} <=> $b->{time} }
		grep { $opt->{$_->{almanac}{event}} }
		@almanac
	    ], $opt );
    return $self->_format_data(
	almanac => [
	    sort { $a->{time} <=> $b->{time} }
	    grep { $opt->{$_->{almanac}{event}} }
	    @almanac
	], $opt );

}

sub begin : Verb() {
    my ($self, @args) = @_;
    $self->_frame_push(
	begin => @args ? \@args : $self->{frame}[-1]{args});
    return;
}

sub cd : Verb() {
    my ($self, $dir) = @_;
    if (defined($dir)) {
	chdir $dir or $self->_wail("Can not cd to $dir: $!");
    } else {
	chdir or $self->_wail("Can not cd to home: $!");
    }
    return;
}

sub choose : Verb( epoch=s ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    if ($opt->{epoch}) {
	my $epoch = $self->_parse_time($opt->{epoch});
	$self->{bodies} = [
	map {
	    $_->select($epoch);
	}
	$self->_aggregate( $self->{bodies} )
	];
    }
    @args and $self->{bodies} = _choose(\@args, $self->{bodies});
    return;
}

sub clear : Verb() {
    my $self = shift;
    @{$self->{bodies}} = ();
    return;
}


sub dispatch {
    my ($self, $verb, @args) = @_;

    defined $verb or return;
    my $code;
    if ($self->{macro}{$verb}) {
	$code = $self->can( '_macro' );
	splice @args, 0, 0, $verb;
    } else {
	$verb =~ s/ \A core [.] //smx;
	$code = $self->can($verb)
	    and _get_attr($code, 'Verb')
	    or $self->_wail("Unknown interactive method '$verb'");
    }
##    $self->{_interactive} = \$verb;	# Any local variable will do.
##    weaken ($self->{_interactive});	# Goes away when $verb does.
    return $code->($self, @args);
}

sub drop : Verb() {
    my ($self, @args) = @_;
    $self->{bodies} = _choose({invert => 1}, \@args, $self->{bodies});
    return;
}

sub dump : method Verb() {	## no critic (ProhibitBuiltInHomonyms)
    my ( $self, $arg ) = @_;
    if ( 'twilight' eq $arg ) {
	return <<"EOD";
twilight => @{[ $self->{twilight} ]}
_twilight => @{[ $self->{_twilight} ]}
EOD
    } else {
	my $tp = delete $self->{time_parser};
	$self->{time_parser} = ref $tp;
	my $dump = $self->_get_dumper()->( $self );
	$self->{time_parser} = $tp;
	return $dump;
    }
}

sub echo : Verb( n! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    my $output = join( ' ', @args );
    $opt->{n} or $output .= "\n";
    return $output;
}

sub end : Verb() {
    my $self = shift;
    $self->{frame}[-1]{type} eq 'begin'
	or $self->_wail("End without begin");
    $self->_frame_pop();
    return;
}

# Tokenize and execute one or more commands. Optionally (and
# unsupportedly) you can pass a code reference as the first argument.
# This code reference will be used to fetch commands when the arguments
# are exhausted. IF you pass your own code reference, we return after
# the first command, since the code reference is presumed to manage the
# input stream itself.
sub execute {
    my ($self, @args) = @_;
    my $accum;
    my $in;
    my $extern;
    if ( ref $args[0] eq 'CODE' ) {
	$extern = shift @args;
	$in = sub {
	    my ( $prompt ) = @_;
	    @args and return shift @args;
	    return $extern->( $prompt );
	};
    } else {
	$in = sub { return shift @args };
    }
    @args = map { split qr{ (?<= \n ) }smx, $_ } @args;
    while ( defined ( local $_ = $in->( $self->get( 'prompt' ) ) ) ) {
	$self->{echo} and $self->_whinge($self->get( 'prompt' ), $_);
	m/ \A \s* [#] /smx and next;
	my $stdout = $self->{frame}[-1]{stdout};
	my ($args, $redirect) = $self->_tokenize(
	    { in => $in }, $_, $self->{frame}[-1]{args});
	# NOTICE
	#
	# The execute_filter attribute is undocumented and unsupported.
	# It exists only so I can scavenge the user's initialization
	# file for the (possible) Space Track username and password, to
	# be used in testing, without being subject to any other
	# undesired side effects, such as running a prediction and
	# exiting. If I change my mind on how or whether to do this,
	# execute_filter will be altered or retracted without warning,
	# much less a deprecation cycle. If you have a legitimate need
	# for this functionality, contact me.
	#
	# YOU HAVE BEEN WARNED.
	$self->{execute_filter}->( $self, $args ) or next;
	@{ $args } or next;
	if ($redirect->{'>'}) {
	    my ($mode, $name) = map {$redirect->{'>'}{$_}} qw{mode name};
	    my $fh = IO::File->new($name, $mode)
		or $self->_wail("Unable to open $name: $!");
	    $stdout = $fh;
	}

	# {localout} is the output to be used for this command. It goes
	# in the frame stack because our command may start a new frame,
	# and _frame_push() needs to have a place to get the correct
	# output handle.

	my $frame_depth = $#{$self->{frame}};
	$self->{frame}[-1]{localout} = $stdout;
##	ref $stdout and weaken ($self->{frame}[-1]{localout});

	my $output = $self->dispatch( @$args );

	$#{$self->{frame}} >= $frame_depth
	    and delete $self->{frame}[ $frame_depth ]{localout};

	if ( defined $output ) {
##	    $output =~ m/ \n \z /smx or $output .= "\n";
	    my $ref = ref $stdout;
	    if ( !defined $stdout ) {
		$accum .= $output;
	    } elsif ( $ref eq 'SCALAR' ) {
		$$stdout .= $output;
	    } elsif ( $ref eq 'CODE' ) {
		$stdout->( $output );
	    } elsif ( $ref eq 'ARRAY' ) {
		push @$stdout, split qr{ (?<=\n) }smx, $output;
	    } else {
		$stdout->print( $output );
	    }
	}

	$extern and last;
    }
    return $accum;
}

#	$satpass2->_execute(...);
#
#	This subroutine calls $satpass2->execute() once for each
#	argument. The call is wrapped in an eval{}; if an exception
#	occurs the user is notified via warn.

sub _execute {
    my ($self, @args) = @_;
    my $in = ref $args[0] eq 'CODE' ? shift @args : sub { return shift
	@args };
    while ( @args ) {
	local $SIG{INT} = sub {die "\n$interrupted\n"};
	eval {
	    $self->execute( $in, shift @args );
	    1;
	} or warn $@;	# Not _whinge, since presumably we already did.
    }
    return;
}

sub exit : method Verb() {	## no critic (ProhibitBuiltInHomonyms)
    my $self = shift;

    $self->_frame_pop(1);	# Leave only the inital frame.

    eval {	## no critic (RequireCheckingReturnValueOfEval)
	no warnings qw{exiting};
	last SATPASS2_EXECUTE;
    };
    $self->_whinge("$@Exiting Perl");
    exit;

}

sub export : Verb() {
    my ($self, $name, @args) = @_;
    if ($mutator{$name}) {
	@args and $self->set ($name, shift @args);
	$self->{exported}{$name} = 1;
    } else {
	@args or $self->_wail("You must specify a value");
	$self->{exported}{$name} = shift @args;
    }
    return;
}

sub flare : Verb( algorithm=s am! choose=s@ day! dump! pm!
    questionable|spare! quiet! )
{
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    $self->_parse_time_reset();
    my $pass_start = $self->_parse_time (
	shift @args, $self->_get_today_noon());
    my $pass_end = $self->_parse_time (shift @args || '+7');
    $pass_start >= $pass_end
	and $self->_wail("End time must be after start time");
    my $sta = $self->_get_station();

    my $horizon = deg2rad ($self->{horizon});
    my $twilight = $self->{_twilight};
    my @flare_mag = ($self->{flare_mag_night}, $self->{flare_mag_day});

    _apply_boolean_default(
	$opt, $self->{frame}[-1]{level1}, qw{ am day pm } );

#	Decide which model to use.

    my $model = $self->{model};

#	Select only the bodies capable of flaring.

    my @active;
    foreach my $tle ( $self->_aggregate( $opt->{choose} ?
	    scalar _choose( $opt->{choose}, $self->{bodies} ) : $self->{bodies}
	) )
    {
	$tle->can_flare ($opt->{questionable}) or next;
	$tle->set (
	    algorithm => $opt->{algorithm} || 'fixed',
	    backdate => $self->{backdate},
	    horizon => $horizon,
	    twilight => $twilight,
	    model => $model,
	    am => $opt->{am},
	    day => $opt->{day},
	    pm => $opt->{pm},
	    extinction => $self->{extinction},
	);
	push @active, $tle;
    }
    @active or $self->_wail("No bodies capable of flaring");

    my @flares;
    foreach my $tle (@active) {
	eval {
	    push @flares, $tle->flare ($sta, $pass_start, $pass_end);
	    1;
	} or do {
	    $@ =~ m/ \Q$interrupted\E /smxo and $self->_wail($@);
	    $opt->{quiet} or $self->_whinge($@);
	};
    }

    return $self->_format_data(
	flare => [
	    sort { $a->{time} <=> $b->{time} }
	    grep { $_->{magnitude} <= $flare_mag['day' eq $_->{type}] }
	    @flares
	], $opt );

}

{

    sub geocode : Verb( debug! ) {
	my ($self, @args) = @_;
	return _geocode_us($self, $self->_getopt(@args));
    }

    sub _geocode_us {
	my ($self, $opt, $loc) = @_;
	$self->_load_module ('SOAP::Lite');
	my ($output, $set_loc);

	if (defined $loc) {
	    $set_loc = 1;
	} else {
	    $loc = $self->get('location');
	}

#	Manufacture a SOAP::Lite object appropriate to the version of
#	SOAP::Lite we have installed.

	my $soap = _soapdish ('http://rpc.geocoder.us/Geo/Coder/US',
	    'http://geocoder.us/service/soap', '#');
	$opt->{debug} and SOAP::Trace->import ('all');

#	Query rpc.geocoder.us, and strain out various errors we might
#	get back.

	my $rslt = eval {$soap->geocode ($loc)->result};
	my $err = $@;
	$opt->{debug} and SOAP::Trace->import ('-all');
	$rslt or $self->_wail("Failed to access geocode.us: $err");

	$opt->{debug} and $self->_whinge($self->_get_dumper()->($rslt));

	@$rslt or $self->_wail("Failed to parse address '$loc'");
	$rslt->[0]{lat} or $self->_wail("Failed to find address '$loc'");

#	If we got exactly one result back, set our latitude and
#	longitude, and query for height if desired. Otherwise display
#	all matching addresses, or a message if none are found.

	if (@$rslt == 1) {
	    $set_loc
		and $self->{location} = _geocode_us_fmt($rslt->[0]);
	    @$self{qw{latitude longitude}} = @{$rslt->[0]}{qw{lat long}};
	    $output .= "\n";
	    $output .= $self->show(
		($set_loc ? 'location' : ()), qw{latitude longitude});
	    $self->get('autoheight')
		and $output .= $self->_height_us($opt);
	} elsif (@$rslt) {
	    foreach my $hash (@$rslt) {
		$output .= _geocode_us_fmt($hash);
	    }
	} else {
	    $output .= "Address not found.\n";
	}
	return $output;
    }

    my $fmt_ = sub {
	my $h = shift;
	join (' ', map {(defined $h->{$_} && $h->{$_} ne '') ?
		$h->{$_} : ()} @_);
    };
    my $fmt_addr = sub {$fmt_->($_[0],
	    qw{number prefix street type suffix})
    };
    my $fmt_city = sub {$fmt_->($_[0],
	    qw{city state zip});
    };
    my $fmt_intr = sub {
	join (' ',
	    $fmt_->($_[0], qw{prefix1 street1 type1 suffix1}),
	    'and',
	    $fmt_->($_[0], qw{prefix2 street2 type2 suffix2}))
    };
    my %fmtr = (
	GeocoderResult => [$fmt_city],
	GeocoderAddressResult => [$fmt_addr, $fmt_city],
	GeocoderIntersectionResult => [$fmt_intr, $fmt_city],
    );

    sub _geocode_us_fmt {
	my ($geo, $join) = @_;
	defined $join or $join = ' ';
	my $cls = ref $geo;
	my $lst = $fmtr{$cls}
	    or confess "Programming error - unexpected class $cls from ",
	"geo.coder.us";
	return join ($join, map {$_->($geo)} @$lst);
    }

}

sub geodetic : Verb() {
    my ( $self, $name, $lat, $lon, $alt ) = @_;
    @_ == 5 or $self->_wail( "Want exactly four arguments" );
    my $body = Astro::Coord::ECI::TLE->new(
	name => $name,
	id => '',
	model => 'null',
    )->geodetic(
	deg2rad( _parse_angle( $lat ) ),
	deg2rad( _parse_angle( $lon ) ),
	$self->_parse_distance( $alt ),
    );
    push @{ $self->{bodies} }, $body;
    return;
}

sub get {
    my ($self, $name) = @_;
    $self->_attribute_exists( $name );
    $self->_deprecation_notice( attribute => $name );
    return $accessor{$name}->($self, $name);
}

sub height : Verb( debug! ) {
    my ($self, @args) = @_;
    return _height_us($self, $self->_getopt(@args));
}

sub _height_us {
    my ($self, $opt, @args) = @_;
    $self->_load_module ('Geo::WebService::Elevation::USGS');
    my $eq = Geo::WebService::Elevation::USGS->new(
	places => 2,	# Service returns unreasonable precision
	source => undef,	# 'best' data set
	units => 'METERS',	# default for service is 'FEET'
    );
    @args or push @args, $self->get('latitude'), $self->get('longitude');
    my $output;
    my ($rslt) = $eq->elevation(@args);
    $eq->is_valid($rslt)
	or $self->_wail("No valid result found");
    $self->set(height => $rslt->{Elevation});
    $output .= $self->show('height');
    return $output;
}

{
    my %help_module = (
	'' => 'Astro::App::Satpass2',
	eci => 'Astro::Coord::ECI',
	iridium => 'Astro::Coord::ECI::TLE::Iridium',
	moon => 'Astro::Coord::ECI::Moon',
	set => 'Astro::Coord::ECI::TLE::Set',
	sun => 'Astro::Coord::ECI::Sun',
	spacetrack => 'Astro::SpaceTrack',
	star => 'Astro::Coord::ECI::Star',
	tle => 'Astro::Coord::ECI::TLE',
	utils => 'Astro::Coord::ECI::Utils',
    );
    sub help : Verb() {
	my ($self, $arg) = @_;
	if ( my $cmd = $self->get( 'webcmd' ) ) {
	    $self->system( $cmd,
		"http://search.cpan.org/~wyant/Astro-App-Satpass2-$VERSION/");
	} else {
	    $arg = $arg ? lc $arg : '';
	    my @ha;
	    if (my $fn = $help_module{$arg}) {
		$self->_load_module($fn);
		$fn =~ s{ :: }{/}smxg;
		$fn .= '.pm';
		@ha = ('-input' => $INC{$fn});

	    }

	    my $os_specific = "_help_$^O";
	    if (__PACKAGE__->can ($os_specific)) {
		return __PACKAGE__->$os_specific ();
	    } elsif (eval {require Pod::Usage}) {
		my $stdout = $self->{frame}[-1]{localout};
		if (openhandle $stdout && !-t $stdout) {
		    push @ha, -output => $stdout;
		}
		Pod::Usage::pod2usage (
		    -verbose => 2, -exitval => 'NOEXIT', @ha);
	    } else {
		return <<'EOD'
No help available; Pod::Usage can not be loaded.
EOD
	    }
	}
	return;
    }
}

sub _help_MacOS {
    return <<'EOD';

Normally, we would display the documentation for the satpass2
script here. But unfortunately this depends on the ability to
spawn the perldoc command, and we do not have this ability under
Mac OS 9 and earlier. You can find the same thing online at
http://search.cpan.org/dist/Astro-App-Satpass2/

EOD
}

sub init {
    my ( $self, @args ) = @_;

    my $opt = 'HASH' eq ref $args[0] ? shift @args : {};
    my $init_file = shift @args;

    $self->{initfile} = undef;

    if (defined $init_file && $init_file ne '') {

	-f $init_file
	    or $self->_wail("Initialization file $init_file not found");

	$self->{initfile} = $init_file;
	return $self->source( { level1 => $opt->{level1} }, $init_file );

    } else {

	foreach (
	    sub { return $ENV{SATPASS2INI} },
	    sub { $self->initfile( { quiet => 1 } ) },
	    sub { return ( $ENV{SATPASSINI}, 1 ) },
	    \&_init_file_01
	) {

	    my ( $fn, $level1 ) = $_->($self);
	    defined $fn and $fn ne '' or next;
	    chomp $fn;
	    -f $fn or next;
	    $self->{initfile} = $fn;
	    return $self->source( { level1 => $level1 }, $fn);

	}
    }

    return;
}


sub initfile : Verb( create-directory! quiet! ) {

    my ( $self, @args ) = @_;
    (my $opt, @args) = $self->_getopt(@args);

    my $init_dir = File::HomeDir->my_dist_config(
	'Astro-App-Satpass2', { create => $opt->{'create-directory'} } );

    defined $init_dir
	or do {
	$opt->{quiet} and return;
	$self->_wail(
	    'Init file directory not found' );
    };

    # The "\n" is for display purposes, and gets chomp-ed before
    # use.
    return File::Spec->catfile( $init_dir, "satpass2rc\n" );
}

#	$file_name = _init_file_01()
#
#	This subroutine returns the first alternate init file name,
#	which is the standard name for the Astro-satpass 'satpass'
#	script. If called in list context it returns not only the name,
#	but a 1 to tell the caller this is a 'level1' file.

sub _init_file_01 {
    my $inifn = $^O eq 'MSWin32' || $^O eq 'VMS' || $^O eq 'MacOS' ?
	'satpass.ini' : '.satpass';
    my $inifile = $^O eq 'VMS' ? "SYS\$LOGIN:$inifn" :
	$^O eq 'MacOS' ? $inifn :
	$ENV{HOME} ? "$ENV{HOME}/$inifn" :
	$ENV{LOGDIR} ? "$ENV{LOGDIR}/$inifn" :
	$ENV{USERPROFILE} ? "$ENV{USERPROFILE}" : undef;
    return wantarray ? ( $inifile, 1 ) : $inifile;
}

sub list : Verb( choose=s@ ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);

    my $bodies = $self->{bodies};
    $opt->{choose} and $bodies = _choose($opt->{choose}, $bodies);

    if (@$bodies) {
	return $self->_format_data(
	    list => $bodies, $opt );
    } else {
	$self->{warn_on_empty}
	    and $self->_whinge("The observing list is empty");
    }
    return;
}

sub load : Verb( verbose! ) {
    my ( $self, @names ) = @_;
    ( my $opt, @names ) = $self->_getopt( @names );
    @names or $self->_wail( 'No file names specified' );
    @names = map {
	bsd_glob( $_, GLOB_NOSORT | GLOB_BRACE | GLOB_QUOTE )
    } @names;
    @names or $self->_wail( 'No files found' );
    foreach my $fn ( @names ) {
	$opt->{verbose} and warn "Loading $fn\n";
	my $fh = IO::File->new( $fn, '<' )
	    or $self->_wail("Unable to open $fn: $!");
	push @{$self->{bodies}}, Astro::Coord::ECI::TLE->parse(<$fh>);
	close $fh;
    }
    return;
}

sub localize : Verb( all|except! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    foreach my $name ( @args ) {
	$self->_attribute_exists( $name );
    }
    if ( $opt->{all} ) {
	my %except = map { $_ => 1 } @args;
	@args = grep { ! $except{$_} } sort keys %mutator;
    }
    foreach my $name ( @args ) {
	$self->_localize( $name );
    }
    return;
}

sub _localize {
    my ( $self, $key ) = @_;

    my $val = exists $self->{$key} ?
	$self->{$key} :
	$self->get( $key );
    my $clone = ( blessed( $val ) && $val->can( 'clone' ) ) ?
	$val->clone() :
	ref $val ? Clone::clone( $val ) : $val;

    $self->{frame}[-1]{local}{$key} = $val;
    if ( exists $self->{$key} ) {
	$self->{$key} = $clone;
    } else {
	$self->set( $key => $clone );
    }

    return;
}

sub location : Verb( dump! ) {
    my ( $self, @args ) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    return $self->_format_data(
	location => $self->_get_station(), $opt );
}

{

    my %mac_cmd;
    {
	my @cmdnam = qw{brief define delete list};
	my %abbr = abbrev(@cmdnam);
	foreach (keys %abbr) {
	    $mac_cmd{'-' . $_} = $abbr{$_};
	}
	foreach (@cmdnam) {
	    $mac_cmd{$_} = $_;
	}
    }

    sub macro : Verb() {
	my ($self, @args) = @_;
	my $cmd;
	if (!@args) {
	    $cmd = 'brief';
	} elsif ($mac_cmd{$args[0]}) {
	    $cmd = $mac_cmd{shift @args};
	} elsif (@args > 1) {
	    $cmd = 'define';
	} else {
	    $cmd = 'list';
	}
	my $output;
	if ($cmd eq 'brief') {
	    foreach my $name (sort @args ? @args : keys %{$self->{macro}}) {
		$self->{macro}{$name} and $output .= $name . "\n";
	    }
	} elsif ($cmd eq 'list') {
	    foreach my $name (sort @args ? @args : keys %{$self->{macro}}) {
		$self->{macro}{$name}
		    and $output .= "macro define $name " .
			join (" \\\n    ", map {
			quoter ($_)} @{ $self->{macro}{$name}{def} }) . "\n";
	    }
	} elsif ($cmd eq 'delete') {
	    foreach my $name (@args ? @args : keys %{$self->{macro}}) {
		delete $self->{macro}{$name};
	    }
	} else {
	    (@args || $cmd eq 'define')
		or $self->_wail(
		"You must provide a definition for the macro");
	    my $name = $cmd eq 'define' ? shift @args : $cmd;
	    $name !~ m/ \W /smx
		and $name !~ m/ \A _ /smx
		or $self->_wail("Invalid macro name '$name'");
	    $self->{macro}{$name} = {
		def => [ _unescape( @args ) ],
		level1 => $self->{frame}[-1]{level1},
	    };
	}
	return $output;
    }

}

sub pass : Verb( choose=s@ appulse! chronological! dump! 
    horizon|rise|set! illumination! quiet! 
    transit|maximum|culmination! )
{
    my ($self, @args) = @_;

    (my $opt, @args) = $self->_getopt(@args);
    _apply_boolean_default(
	$opt, 0, qw{ horizon illumination transit appulse } );
    $self->_parse_time_reset();
    my $pass_start = $self->_parse_time (
	shift @args, $self->_get_today_noon());
    my $pass_end = $self->_parse_time (shift @args || '+7');
    $pass_start >= $pass_end
	and $self->_wail("End time must be after start time");

    my $sta = $self->_get_station();
    my @bodies = @{$opt->{choose} ? scalar _choose($opt->{choose},
	    $self->{bodies}) : $self->{bodies}}
	or $self->_wail("No bodies selected");
    my $pass_step = shift || 60;

#	Decide which model to use.

    my $model = $self->{model};

#	Pick up horizon and appulse distance.

    my $horizon = deg2rad ($self->{horizon});
    my $appulse = deg2rad ($self->{appulse});

#	Foreach body to be modelled

    my @accumulate;	# For chronological output.
    foreach my $tle ( $self->_aggregate( \@bodies ) ) {

	{
	    my $mdl = $tle->get('inertial') ? $model :
		$tle->get('model');
	    $tle->set (
		appulse => $appulse,
		backdate => $self->{backdate},
		debug => $self->{debug},
		geometric => $self->{geometric},
		horizon => $horizon,
		interval => $opt->{verbose} ? $pass_step : 0,
		limb => $self->{lit},
		model => $mdl,
		twilight => $self->{_twilight},
		visible => $self->{visible},
	    );
	}

	eval {
	    push @accumulate, $self->_pass_select_event( $opt, $tle->pass (
		$sta, $pass_start, $pass_end, $self->{sky} ) );
	    1;
	} or do {
	    $@ =~ m/ \Q$interrupted\E /smxo and $self->_wail($@);
	    $opt->{quiet} or $self->_whinge($@);
	};
    }

    $opt->{chronological}
	and @accumulate = sort { $a->{time} <=> $b->{time} }
	    @accumulate;

    if ( $self->{frame}[-1]{level1} ) {
	return $self->location() .
	$self->_format_data(
	    pass => \@accumulate, $opt );
    }

    return $self->_format_data(
	pass => \@accumulate, $opt );
}

{
    my @selector;
    $selector[ PASS_EVENT_SHADOWED ]	= 'illumination';
    $selector[ PASS_EVENT_LIT ]		= 'illumination';
    $selector[ PASS_EVENT_DAY ]		= 'illumination';
    $selector[ PASS_EVENT_RISE ]	= 'horizon';
    $selector[ PASS_EVENT_MAX ]		= 'transit';
    $selector[ PASS_EVENT_SET ]		= 'horizon';
    $selector[ PASS_EVENT_APPULSE ]	= 'appulse';

    # Remove from the pass data any events that are not wanted. The
    # arguments are $self, the $opt hash reference that (among other
    # things) specifies the desired events, and the passes, each pass
    # being an argument. The modified passes are returned.
    sub _pass_select_event {
	my ( $self, $opt, @passes ) = @_;
	foreach my $pass ( @passes ) {
	    @{ $pass->{events} } = grep {
		$opt->{ $selector[ $_->{event} ] } } @{ $pass->{events} };
	}
	return @passes
    }
}

sub phase : Verb() {
    my ( $self, @args ) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    $self->_parse_time_reset();
    my $time = $self->_parse_time (shift @args, time );

    my @sky = @{ $opt->{choose} ?
	    scalar _choose($opt->{choose}, $self->{sky}) :
	    $self->{sky} }
	or $self->_wail( 'No bodies selected' );
    return $self->_format_data(
	phase => [
	    map { $_->universal( $time ) }
	    grep { $_->can( 'phase' ) }
	    @sky
	], $opt );
}

sub position : Verb( choose=s@ questionable|spare! quiet! ) {
    my ($self, @args) = @_;

    my ( $opt, $time ) = $self->_getopt(@args);

    if ( defined $time ) {
	$self->_parse_time_reset();
	$time = $self->_parse_time($time);
    } else {
	$time = time;
    }
    my $twilight = $self->{_twilight};


#	Define the observing station.

    my $sta = $self->_get_station();
    $sta->universal($time);


    my @list = ( $self->_aggregate( $self->{bodies} ), @{$self->{sky}});
    $opt->{choose}
	and @list = _choose($opt->{choose}, \@list);

    foreach my $body (@list) {
	$body->represents( 'Astro::Coord::ECI::TLE' ) or next;
	$body->get('inertial')
	    and $body->set( model => $self->{model} );
    }

    my @good;
    foreach my $body (@list) {
	eval {
	    $body->universal ($time);
	    push @good, $body;
	    1;
	} or do {
	    $@ =~ m/ \Q$interrupted\E /smxo and $self->_wail($@);
	    $opt->{quiet} or $self->_whinge($@);
	};
    }

    return $self->_format_data(
	position => {
	    bodies		=> \@good,
	    questionable	=> $opt->{questionable},
	    station		=> $self->_get_station()->universal(
		$time ),
	    time		=> $time,
	    twilight		=> $self->{_twilight},
	}, $opt );
}

sub quarters : Verb( choose=s@ dump! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    $self->_parse_time_reset();
    my $start = $self->_parse_time ($args[0], $self->_get_today_midnight());
    my $end = $self->_parse_time ($args[1] || '+30');

    my @sky = @{ $opt->{choose} ?
	    scalar _choose($opt->{choose}, $self->{sky}) :
	    $self->{sky} }
	or $self->_wail( 'No bodies selected' );

    my @almanac;

#	Iterate over any background objects, accumulating all
#	quarter-phases of each until we get one after the
#	end time. We silently ignore bodies that do not support
#	the next_quarter() method.

    foreach my $body ( @sky ) {
	next unless $body->can ('next_quarter_hash');
	$body->universal ($start);

	while (1) {
	    my $hash = $body->next_quarter_hash();
	    $hash->{time} > $end and last;
	    push @almanac, $hash;
	}
    }

#	Sort and display the quarter-phase information.

    return $self->_format_data(
	almanac => [
	    sort { $a->{time} <=> $b->{time} }
	    @almanac
	], $opt );

}

sub run {
    (my $self, local @ARGV) = @_;

    # We can be called statically. If we are, instantiate.
    ref $self or $self = $self->new(warning => 1);

    # If the undocumented first option is a code reference, use it to
    # get input.
    my $in;
    ref $ARGV[0] eq 'CODE' and $in = shift @ARGV;

    # Parse the command options. -level1 is undocumented.
    my %opt;
    GetOptions( \%opt, qw{ filter! initialization_file|initfile=s gmt!
	help level1! version },
    )
	or $self->_wail( "See the help method for valid options" );

    # If -version, do it and return.
    if ( $opt{version} ) {
	print $self->version();
	return;
    }

    # If -help, do it and return.
    if ( $opt{help} ) {
	$self->help();
	return;
    }

    # Get an input routine if we do not already have one.
    $in ||= $self->_get_readline();

    # Figure out whether we want to display the front matter.
    exists $opt{filter}
	and $self->set(filter => delete ($opt{filter}));

    # Display the front matter if desired.
    (!$self->get('filter') && $self->_get_interactive())
	and print $self->version();

    # Execute the initialization file.
    eval {
	$self->init(
	    { level1 => delete $opt{level1} },
	    delete $opt{initialization_file},
	);
	1;
    } or warn $@;	# Not _whinge, since presumably we already did.

    # The remaining options set the corresponding attributes.
    %opt and $self->set(%opt);

    # Execution loop. What exit() really does is a last on this.
SATPASS2_EXECUTE:
    {
	$self->_execute( @ARGV );
	while ( defined ( my $buffer = $in->( $self->get( 'prompt' ) ) ) ) {
	    $self->_execute( $in, $buffer );
	}
    }
    $self->_execute( q{echo ''} );	# The lazy way to be sure we
					# have a newline before exit.
    return;
}

sub save : Verb( changes! overwrite! ) {
    my ($self, @args) = @_;
    my ($opt, $fn) = $self->_getopt(@args);
    defined $fn or $fn = $self->initfile( { 'create-directory' => 1 } );
    chomp $fn;	# because initfile() adds a newline for printing
    if ($fn ne '-' && -e $fn) {
	-f $fn or $self->_wail(
	    "Can not overwrite $fn: not an ordinary file");
	$opt->{overwrite} or do {
	    my $rslt = $self->_get_readline()->(
		"File $fn exists. Overwrite [y/N]? ");
	    'y' eq lc substr($rslt, 0, 1)
		or return;
	};
    }
    my @show_opt;
    my $title = 'settings';
    if ($opt->{changes}) {
	push @show_opt, '-changes';
	$title = 'setting changes';
    }

    my $output = <<"EOD" .

# Astro::App::Satpass2 $title

EOD
	$self->show( @show_opt, qw{ -nodeprecated -noreadonly } ) .
	<<"EOD" . $self->macro('list');

# Astro::App::Satpass2 macros

EOD

    push @show_opt, '-decode';
    foreach my $attribute ( qw{ formatter spacetrack time_parser } ) {
	my $obj = $self->get( $attribute ) or next;
	my $class = ref $obj;
	$output .= <<"EOD" .

# $class $title

EOD
	( $self->_tell_interactive( $attribute, 'config', @show_opt
	    ) || "# none\n" );
    }

    if ($fn ne '-') {
	my $fh = IO::File->new($fn, '>')
	    or $self->_wail("Unable to open $fn: $!");
	print {$fh} $output;
	$output = "$fn\n";
    }
    return $output;
}

sub set : Verb() {	## no critic (ProhibitAmbiguousNames)
    my ($self, @args) = @_;
    $self->{time_parser} and $self->_parse_time_reset();
    while (@args) {
	my ( $name, $value ) = splice @args, 0, 2;
	$self->_attribute_exists( $name );
##	if ($self->{_interactive}) {
	if ( _is_interactive() ) {
	    $nointeractive{$name}
		and $self->_wail(
		    "Attribute '$name' may not be set interactively");
	    defined $value and $value eq 'undef'
		and $value = undef;
	}
	if ( $mutator{$name} ) {
	    $self->_deprecation_notice( attribute => $name );
	    $mutator{$name}->($self, $name, $value);
	} else {
	    $self->_wail("Read-only attribute '$name'");
	}
    }
    return;
}

sub _set_angle {
    return ($_[0]{$_[1]} = _parse_angle ($_[2]));
}

sub _set_code_ref {
    'CODE' eq ref $_[2]
	or $_[0]->_wail( "Attribute $_[1] must be a code reference" );
    return( $_[0]{$_[1]} = $_[2] );
}

# Set an attribute whose value is an Astro::App::Satpass2::Copier object
# %arg is a hash of argument name/value pairs:
#    {name} is the required name of the attribute to set;
#    {value} is the required value of the attribute to set;
#    {class} is the optional class that the object must be;
#    {message} is an optional message to emit if the object can not be
#	instantiated;

sub _set_copyable {
    my ( $self, %arg ) = @_;
    my $old = $self->{$arg{name}};
    my $obj;
    if ( ref $arg{value} ) {
	blessed( $arg{value} )
	    or $self->_wail( "$arg{name} may not be unblessed reference" );
	$obj = $arg{value};
    } else {
	if ( defined $arg{default} ) {
	    defined $arg{value}
		and '' ne $arg{value}
		or $arg{value} = $arg{default};
	}
	my @args;
	my $base = 0;
	while ( $arg{value} =~ m/ (?: \A | [^\\] ) (?: \\ \\ )* , /smxg ) {
	    push @args, substr $arg{value}, $base, $+[0] - $base - 1;
	    $base = $+[0];
	    $args[-1] =~ s/ \\ ( . ) /./smxg;
	}
	push @args, substr $arg{value}, $base;
	my $pkg = shift @args;
	my @prefix = @{ $arg{prefix} || [] };
	my $cls = load_package( $pkg, @{ $arg{prefix} || [] } )
	    or $self->_wail( "Unable to load $pkg" );
	$obj = $cls->new( map { split qr{ = }smx, $_, 2 } @args )
	    or $self->_wail( $arg{message} ||
	    "Can not instantiate object from '$arg{value}'" );
    }
    defined $arg{class}
	and not $obj->isa( $arg{class} )
	and $self->_wail( "$arg{name} must be of class $arg{class}" );
    blessed( $old ) and $old->can( 'copy' ) and $old->copy( $obj );
    $self->{$arg{name}} = $obj;
    return $arg{value};
}

sub _set_distance_meters {
    return ( $_[0]{$_[1]} = defined $_[2] ?
	( $_[0]->_parse_distance( $_[2], '0m' ) * 1000 ) : $_[2] );
}

sub _set_ellipsoid {
    my ($self, $name, $val) = @_;
    Astro::Coord::ECI->set (ellipsoid => $val);
    return ($self->{$name} = $val);
}

sub _set_formatter {
    my ( $self, $name, $val ) = @_;
    return $self->_set_copyable(
	name	=> $name,
	value	=> $val,
	message	=> 'Unknown formatter',
	default	=> 'Astro::App::Satpass2::Format::Classic',
	prefix	=> [ 'Astro::App::Satpass2::Format' ]
    );
}

sub _set_formatter_attribute {
    my ( $self, $name, $val ) = @_;
    $self->tell( formatter => $name, $val );
    return $val;
}

#sub _set_lowercase {
#    return ($_[0]{$_[1]} = lc $_[2]);
#}

sub _set_model {
    my ( $self, $name, $val ) = @_;
    Astro::Coord::ECI::TLE->is_valid_model( $val )
	or $self->_wail(
	"'$val' is not a valid Astro::Coord::ECI::TLE model" );
    return ( $self->{$name} = $val );
}

sub _set_spacetrack {
    my ($self, $name, $val) = @_;
    if (defined $val) {
	instance($val, 'Astro::SpaceTrack')
	    or $self->_wail("$name must be an Astro::SpaceTrack instance");
	my $version = $val->VERSION();
	$version =~ s/ _ //smxg;
	$version >= ASTRO_SPACETRACK_VERSION
	    or $self->_wail("$name must be Astro::SpaceTrack version ",
	    ASTRO_SPACETRACK_VERSION, ' or greater' );
    }
    return ($self->{$name} = $val);
}

sub _set_stdout {
    my ($self, $name, $val) = @_;
    $self->{frame}
	and $self->{frame}[-1]{$name} = $val;
    return ($self->{$name} = $val);
}

sub _set_time_parser {
    my ( $self, $name, $val ) = @_;
    return $self->_set_copyable(
	name	=> $name,
	value	=> $val,
	class	=> 'Astro::App::Satpass2::ParseTime',
	message	=> 'Unknown time parser',
	default	=> 'Astro::App::Satpass2::ParseTime',
	prefix	=> [ 'Astro::App::Satpass2::ParseTime' ],
    );
}

sub _set_time_parser_attribute {
    my ( $self, $name, $val ) = @_;
    defined $val and $val eq 'undef' and $val = undef;
    $self->{time_parser}->$name( $val );
    return $val;
}

_frame_pop_force_set ( 'twilight' );	# Force use of the set() method
					# in _frame_pop(), because we
					# need to set {_twilight} as
					# well.
sub _set_twilight {
    my ($self, $name, $val) = @_;
    if (my $key = $twilight_abbr{lc $val}) {
	$self->{$name} = $key;
	$self->{_twilight} = $twilight_def{$key};
    } else {
	my $angle = _parse_angle ($val);
	looks_like_number( $angle )
	    or $self->_wail("Twilight must be number or known keyword" );
	$self->{$name} = $val;
	$self->{_twilight} = deg2rad ($angle);
    }
    return $val;
}

sub _set_tz {
    my ( $self, $name, $val ) = @_;
    $self->_set_formatter_attribute( $name, $val );
    $self->_set_time_parser_attribute( $name, $val );
    return $val;
}

sub _set_unmodified {
    return ($_[0]{$_[1]} = $_[2]);
}

sub _set_warner_attribute {
    my ( $self, $name, $val ) = @_;
    defined $val and $val eq 'undef' and $val = undef;
    $self->{_warner}->$name( $val );
    return $val;
}

sub _set_webcmd {
    my ($self, $name, $val) = @_;
    $self->{spacetrack}
	and $self->{spacetrack}->set(webcmd => $val);
    return ($self->{$name} = $val);
}

sub show : Verb( changes! deprecated! readonly! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    foreach my $name ( qw{ deprecated readonly } ) {
	exists $opt->{$name} or $opt->{$name} = 1;
    }
    my $output;
    @args or @args = sort grep {
	!$nointeractive{$_} &&
	( $opt->{deprecated} ||
	    !$self->_deprecation_in_progress( attribute => $_ ) &&
       	( $opt->{readonly} || exists  $mutator{$_} ) )
    } keys %accessor;
    foreach my $name (@args) {
	exists $shower{$name}
	    or $self->_wail("No such attribute as '$name'");

=begin comment

	my $val = $shower{$name}->( $self, $name );
	if ($opt->{changes}) {
	    no warnings qw{uninitialized};
	    $static{$name} eq $val and next;
	}
	exists $mutator{$name} or $output .= '# ';
	$output .= "set $name " . quoter( $val ) . "\n";

=end comment

=cut

	my @val = $shower{$name}->( $self, $name );
	if ( $opt->{changes} ) {
	    no warnings qw{ uninitialized };
	    $static{$name} eq $val[-1] and next;
	}
	exists $mutator{$name} or unshift @val, '#';
	$output .= join ' ', map { quoter( $_ ) } @val;
	$output .= "\n";
    }
    return $output;
}

sub _show_copyable {
    my ( $self, $name ) = @_;
    my $obj = $self->get( $name );
    my $val = ref $obj || $obj;
    return ( 'set', $name, $val );
}

sub _show_formatter_attribute {
    my ( $self, $name ) = @_;
    my $val = $self->{formatter}->decode( $name );
    return ( qw{ tell formatter }, $name, $val );
}

sub _show_unmodified {
    my ($self, $name) = @_;
    my $val = $self->get( $name );
    return ( 'set', $name, $val );
}


# For proper motion, we need to convert arc seconds per year to degrees
# per second. Perl::Critic does not like 'use constant' because they do
# not interpolate, but they really do: "@{[SPY2DPS]}".

use constant SPY2DPS => 3600 * 365.24219 * SECSPERDAY;

{

    my %handler = (
	list	=> sub {
	    my ( $self, @args ) = @_;
	    my $output;
	    foreach my $body (
		map {$_->[1]}
		sort {$a->[0] cmp $b->[0]}
		map {[lc $_->get('name'), $_]}
		@{$self->{sky}}) {
		if ($body->isa ('Astro::Coord::ECI::Star')) {
		    my ($ra, $dec, $rng, $pmra, $pmdec, $vr) = $body->position ();
		    $rng /= PARSEC;
		    $pmra = rad2deg ($pmra / 24 * 360 * cos ($ra)) * SPY2DPS;
		    $pmdec = rad2deg ($pmdec) * SPY2DPS;
		    $output .= sprintf (
			"sky add %s %s %7.3f %.2f %.4f %.5f %s\n",
			quoter ($body->get ('name')), _rad2hms ($ra),
			rad2deg ($dec), $rng, $pmra, $pmdec, $vr);
		} else {
		    $output .= "sky add " . quoter (
			$body->get ('name')) . "\n";
		}
	    }
	    unless (@{$self->{sky}}) {
		$self->{warn_on_empty}
		    and $self->_whinge("The sky is empty");
	    }
	    return $output;
	},
	add	=> sub {
	    my ( $self, @args ) = @_;
	    my $name = shift @args
		or $self->_wail("You did not specify what to add");
	    my $lcn = lc $name;
	    my $special = $lcn eq 'sun' || $lcn eq 'moon';
	    my $class = 'Astro::Coord::ECI::' .
		($special ? ucfirst ($lcn) : 'Star');
	    foreach my $body (@{$self->{sky}}) {
		return if $body->isa ($class) &&
			($special || $lcn eq lc $body->get ('name'));
	    }
	    my $body = $class->new (debug => $self->{debug});
	    unless ($special) {
		$body->set (name => $name);
		@args >= 2 
		    or $self->_wail(
		    "You must give at least right ascension and declination");
		my $ra = deg2rad (_parse_angle (shift @args));
		my $dec = deg2rad (_parse_angle (shift @args));
		my $rng = @args ?
		    $self->_parse_distance (shift @args, '1pc') :
		    10000 * PARSEC;
		my $pmra = @args ? do {
		    my $angle = shift @args;
		    $angle =~ s/ s \z //smxi
			or $angle *= 24 / 360 / cos ($ra);
		    deg2rad ($angle / SPY2DPS);
		} : 0;
		my $pmdec = @args ? deg2rad (shift (@args) / SPY2DPS) : 0;
		my $pmrec = @args ? shift @args : 0;
		$body->position ($ra, $dec, $rng, $pmra, $pmdec, $pmrec);
	    }
	    push @{$self->{sky}}, $body;
	    return;
	},
	clear	=> sub {
	    my ( $self, @args ) = @_;
	    @{ $self->{sky} } = ();
	    return;
	},
	drop	=> sub {
	    my ( $self, @args ) = @_;
	    @args or $self->_wail(
		"You must specify at least one name to drop");
	    my $match = qr< @{[ join '|', map {quotemeta $_} @args ]} >smxi;
	    @{$self->{sky}} = grep {
		$_->get ('name') !~ m/ $match /smx } @{$self->{sky}};
	    return;
	},
	lookup	=> sub {
	    my ( $self, @args ) = @_;
	    my $output;
	    my $name = shift @args;
	    my $lcn = lc $name;
	    foreach my $body (@{$self->{sky}}) {
		next unless $body->isa ('Astro::Coord::ECI::Star') &&
			$lcn eq lc $body->get ('name');
		$self->_wail( "Duplicate sky entry '$name'" );
	    }
	    my ($ra, $dec, $rng, $pmra, $pmdec, $pmrec) =
		$self->_simbad4 ($name);
	    $rng = sprintf '%.2f', $rng;
	    $output .= "sky add " . quoter ($name) .
		" $ra $dec $rng $pmra $pmdec $pmrec\n";
	    $ra = deg2rad (_parse_angle ($ra));
	    my $body = Astro::Coord::ECI::Star->new (name => $name);
	    $body->position ($ra, deg2rad (_parse_angle ($dec)),
		$rng * PARSEC, deg2rad ($pmra * 24 / 360 / cos ($ra) / SPY2DPS),
		deg2rad ($pmdec / SPY2DPS), $pmrec);
	    push @{$self->{sky}}, $body;
	    return $output;
	},

    );

    sub sky : Verb() {
	my ($self, @args) = @_;
	my $verb = lc ( shift @args || 'list' );

	if ( my $code = $handler{$verb} ) {
	    return $code->( $self, @args );
	} else {
	    $self->_wail("'sky' subcommand '$verb' not known");
	}
	return;	# We can't get here, but Perl::Critic does not know this.
    }

}

sub source : Verb( optional! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    my $output;
    my $fn = shift @args or $self->_wail("File name required");
    if ( my $fh = IO::File->new( $fn, '<' ) ) {

	my $fetcher = $opt->{level1} ? sub {
	    my $buffer = <$fh>;
	    defined $buffer
		or return $buffer;
	    $buffer =~ m/ \A \s* \z /sxm
		and return $buffer;
	    $buffer =~ m/ \A \s* [#] /sxm
		and return $buffer;

	    # TODO the following applies only to macros; for others we
	    # merely want ' to become ", since the level1 '
	    # interpolates. But we _don't_ want to add quotes to
	    # arguments, since they are presumably already quoted
	    # correctly.
	    my $append = '';
	    $buffer =~ s/ ( \s* \\? \n ) //sxm
		and $append = $1;
	    my @input = Text::ParseWords::quotewords( qr{ \s+ }smx, 0,
		$buffer );
	    foreach ( @input ) {
		m/ ['"\\\s] /sxm or next;
		s/ (?: \A | (?<= [^\\] ) ) (?: \\\\ )* ' /"/sxmg;
		substr $_, 0, 0, q<'>;
		$_ .= q<'>;
	    }
	    return join( ' ', @input ) . $append;
	} : sub {
	    return <$fh>;
	};

	my $frames = $self->_frame_push( source => [@args] );
	# Note that level1 is unsupported, and works only when the
	# options are passed as a hash. It will go away when support for
	# the original satpass script is dropped.
	$self->{frame}[-1]{level1} = $opt->{level1};
	my $err;
	my $ok = eval { while ( defined( my $input =  $fetcher->() ) ) {
		if ( defined ( my $buffer = $self->execute( $fetcher,
				$input ) ) ) {
		    $output .= $buffer;
		}
	    }
	    1;
	} or $err = $@;
	close $fh;
	$self->_frame_pop( $frames );
	$ok or $self->_whinge( $err );
    } else {
	$opt->{optional}
	    or $self->_wail("Failed to open $fn: $!");
    }
    $opt->{level1} and $self->_rewrite_level1_macros();
    return $output;
}

sub st : Verb() {	## no critic (RequireArgUnpacking)
    my ( $self, $func, @args ) = @_;
    $self->_deprecation_notice( method => 'st' );
    if ( 'localize' eq $func ) {
	my $st = $self->_get_spacetrack();
	foreach my $key (@args) {
	    exists $self->{frame}[-1]{spacetrack}{$key}
		or $self->{frame}[-1]{spacetrack}{$key} =
		$st->get ($key)->content
	}
    } else {
	splice @_, 1, 0, 'spacetrack';
	goto &tell;
    }
    return;
}

# TODO I must have thought -reload would be good for something, but it
# appears I never implemented it.

{
    my @status_code_map = qw{+ S -};

    sub status : Verb( name! reload! ) {
	my ($self, @args) = @_;
	(my $opt, @args) = $self->_getopt(@args);
	@args or @args = qw{show};

	my $verb = lc (shift (@args) || 'show');
	$verb = 'show' if $verb eq 'iridium';	# Cover deprecated option.

	my $output;
	if ($verb eq 'add' || $verb eq 'drop') {
	    Astro::Coord::ECI::TLE->status ($verb, @args);
	    foreach my $tle (@{$self->{bodies}}) {
		$tle->get ('id') == $args[0] and $tle->rebless ();
	    }
	} elsif ($verb eq 'clear') {
	    Astro::Coord::ECI::TLE->status ($verb, @args);
	    foreach my $tle (@{$self->{bodies}}) {
		$tle->rebless ();
	    }
	} elsif ($verb eq 'show' || $verb eq 'list') {
	    my @data = Astro::Coord::ECI::TLE->status ('show');
	    @data = sort {$a->[3] cmp $b->[3]} @data if $opt->{name};
	    @args and @data = map {$_->[2]} @{_choose(\@args,
		    [map {[$_->[0], $_->[3], $_]} @data])};
	    foreach my $tle (@data) {
		$output .= join (' ', map {quoter($_)} 'status', 'add',
		    $tle->[0], $tle->[1], $status_code_map[$tle->[2]],
		    $tle->[3], $tle->[4]) . "\n";
	    }
	} else {
	    Astro::Coord::ECI::TLE->status ($verb, @args);
	}

	return $output;

    }
}

sub system : method Verb() {	## no critic (ProhibitBuiltInHomonyms)
    my ($self, $verb, @args) = @_;
    @args = map {
	bsd_glob( $_, GLOB_NOCHECK | GLOB_BRACE | GLOB_QUOTE )
    } @args;
    my $stdout = $self->{frame}[-1]{localout};
    my @exported = keys %{ $self->{exported} };
    local @ENV{@exported} = map { $mutator{$_} ? $self->get( $_ ) :
	$self->{exported}{$_} } @exported;
    if ( 'CODE' eq ref $verb ) {	# For testing, and undocumented
	return $verb->( @args );
    } elsif ( defined $stdout && -t $stdout ) {
	CORE::system {$verb} $verb, @args;
	return;
    } else {
	return capturex( $verb, @args );
    }
}


sub tell : method Verb() {	## no critic (ProhibitBuiltInHomonyms)
##    $_[0]->{_interactive} and goto &_tell_interactive;
    _is_interactive() and goto &_tell_interactive;
    goto &_tell_nointeractive;
}

sub _tell_interactive {
    my ( $self, $attribute, $method, @args ) = @_;
    my $code = $self->can( "__tell__${attribute}__$method" ) ||
	$self->can( "__tell__$attribute" ) ||
	$self->_wail( "Can not tell $attribute" );
    goto &$code;
}

sub _tell_nointeractive {
    my ( $self, $attribute, $method, @args ) = @_;
    $self->can( "__tell__$attribute" )
	or $self->_wail( "Can not tell $attribute" );
    return $self->_tell_get_object( $attribute )->$method( @args );
}

sub _tell_get_object {
    my ( $self, $attribute ) = @_;
    my $object = $self->get( $attribute )
	or $self->_wail( "No $attribute object available" );
    return $object;
}

sub _tell_config_options {
    ( my $self, local @ARGV ) = @_;
    my %opt;
    GetOptions( \%opt, qw{ changes! decode! } )
	or $self->_wail( "Bad option" );
    return ( \%opt, @ARGV );
}

sub _tell_output {
    my @args = @_;
    return join( ' ', map { quoter( $_ ) } 'tell', @args ) . "\n";
}

sub __tell__formatter {
    my ( $self, $attribute, $method, @args ) = @_;
    my $object = $self->_tell_get_object( $attribute );

    my $rslt = $object->decode( $method, @args );

    instance( $rslt, ref $object ) and return;
    ref $rslt and return $rslt;
    return join( ' ', map { quoter( $_ ) } 'tell', $attribute,
	$method, @args, $rslt ) . "\n";

}

sub __tell__formatter__config {
    my ( $self, $attribute, $method, @args ) = @_;
    my $object = $self->_tell_get_object( $attribute );

    ( my $opt, @args ) = $self->_tell_config_options( @args );

    exists $opt->{decode} or $opt->{decode} = 1;
    my @rslt = $object->config( %{ $opt } );
    my $output;
    foreach my $item ( @rslt ) {
	$output .= _tell_output( $attribute, @{ $item } );
    }
    return $output;
}

sub __tell__formatter__desired_equinox_dynamical {
    my ( $self, $attribute, $method, @args ) = @_;
    my $object = $self->_tell_get_object( $attribute );

    if ( $args[0] ) {
	$self->_parse_time_reset();
	$args[0] = $self->_parse_time( $args[0], 0 );
    }

    my $rslt = $object->decode( $method, @args );
    instance( $rslt, ref $object )
	and return;

    return _tell_output( $attribute, $method, $rslt );
}

sub __tell__formatter__format_effector {
    my ( $self, $attribute, $method, @args ) = @_;
    my $object = $self->_tell_get_object( $attribute );

    my $rslt = $object->decode( $method, @args );
    instance( $rslt, ref $object )
	and return;

    return _tell_output( $attribute, $method, @{ $rslt } );

}

sub __tell__spacetrack {
    my ( $self, $attribute, $method, @args ) = @_;
    my $object = $self->_tell_get_object( $attribute );

    $method !~ m/ \A _ /smx and $object->can( $method )
	or $self->_wail("No such $attribute method as '$method'");

    my %opt;

    local @ARGV = @args;
    my $err;
    local $SIG{__WARN__} = sub { $err = $_[0] };
    my $go = Getopt::Long::Parser->new( config => [ qw{ default
	    pass_through } ] );
    $go->getoptions( \%opt, qw{ all! descending! effective! last5! rcs!
	sort=s tle! end_epoch=s start_epoch=s verbose! } )
	or $self->_wail( $err );

    $self->_parse_time_reset();
    $opt{start_epoch}
	and $opt{start_epoch} = $self->_parse_time( $opt{start_epoch} );
    $opt{end_epoch}
	and $opt{end_epoch} = $self->_parse_time( $opt{end_epoch} );

    my ($rslt, @rest) = $method eq 'set' ?
	$object->$method( @ARGV ) :
	$object->$method( \%opt, @ARGV );
    $rslt->is_success()
	or $self->_wail( $rslt->status_line() );

    my $content_type = $object->content_type || '';
    my $output;
    if ($content_type eq 'orbit') {
	push @{$self->{bodies}},
	    Astro::Coord::ECI::TLE->parse ($rslt->content);
	$opt{verbose} and $output .= $rslt->content;
    } elsif ($content_type eq 'iridium-status') {
	$self->_iridium_status( @rest );
	$opt{verbose} and $output .= $rslt->content;
    } elsif ($content_type || $opt{verbose}) {
	$output .= $rslt->content;
    }
    defined $output
	and $output =~ s/ (?<! \n ) \z /\n/smx;
    return $output;
}

{

    my $virgin;

    sub __tell__spacetrack__show {
	my ( $self, $attribute, $method, @args ) = @_;
	my $object = $self->_tell_get_object( $attribute );

	( my $opt, @args ) = $self->_tell_config_options( @args );

	@args or @args = $object->attribute_names();

	if ( $opt->{changes} ) {
	    $virgin ||= $self->_get_spacetrack_default();
	}

	my $output;
	foreach my $name ( @args ) {
	    my $value = $object->getv( $name );
	    no warnings qw{ uninitialized };
	    $opt->{changes}
		and $value eq $virgin->getv( $name )
		and next;
	    $output .= _tell_output( $attribute, 'set', $name,
		$value );
	}

	return $output;
    }

}

*__tell__spacetrack__config = \&__tell__spacetrack__show;

sub __tell__spacetrack__getv {
    my ( $self, $attribute, $method, @args ) = @_;
    my $object = $self->_tell_get_object( $attribute );
    return _tell_output( $attribute, 'set', $args[0], $object->getv(
	    $args[0] ) );
}

*__tell__spacetrack__get = \&__tell__spacetrack__getv;

*__tell__time_parser = \&__tell_formatter;

*__tell__time_parser__config = \&__tell__formatter__config;


sub time : method Verb() {	## no critic (ProhibitBuiltInHomonyms)
    my ($self, @args) = @_;
    $got_time_hires or $self->_wail( 'Time::HiRes not available' );
    my $start = Time::HiRes::time();
    my $output = $self->dispatch(@args);
    defined $output and $output .= "\n";
    $output .= sprintf "%.3f seconds\n", Time::HiRes::time() - $start;
    return $output;
}


# TODO the Celestia functionality. Currently, it gives a file that is
# syntactically valid, but does not give the correct position. What is
# really needed is for Celestia to implement the right model, but it
# would also be nice to KNOW we're generating the correct Keplerian
# ellipse. Until we do, this functionality is UNSUPPORTED and
# undocumented. When we do, the formatter method loses its leading
# underscore.

sub tle : Verb( celestia! verbose! ) {
    my ($self, @args) = @_;
    (my $opt, @args) = $self->_getopt(@args);
    my $bodies = @args ? _choose([@args], $self->{bodies}) : $self->{bodies};
    my $method = $opt->{celestia} ? '_tle_celestia' :
	$opt->{verbose} ? 'tle_verbose' : 'tle';
    return $self->_format_data(
	$method => $bodies, $opt );
}


sub unexport : Verb() {
    my ( $self, @args ) = @_;
    foreach my $name ( @args ) {
	delete $self->{exported}{$name};
    }
    return;
}


sub validate : Verb( quiet! ) {
    my ($self, @args) = @_;

    (my $opt, @args) = $self->_getopt(@args);

    $self->_parse_time_reset();
    my $pass_start = $self->_parse_time (
	shift @args, $self->_get_today_noon());
    my $pass_end = $self->_parse_time (shift @args || '+7');
    $pass_start >= $pass_end
	and $self->_wail("End time must be after start time");

    @{ $self->{bodies} }
	or $self->_wail("No bodies selected");

#	Validate each body.

    my @valid;
    foreach my $tle ( $self->_aggregate( $self->{bodies} ) ) {
	$tle->validate( $opt, $pass_start, $pass_end )
	    and push @valid, $tle->members();
    }

    $self->{bodies} = \@valid;

    return;
}


sub version : Verb() {
    return <<"EOD";

@{[__PACKAGE__]} $VERSION - Satellite pass predictor
based on Astro::Coord::ECI @{[Astro::Coord::ECI->VERSION]}
Copyright (C) 2009-2011 by Thomas R. Wyant, III

EOD
}

########################################################################

#	$self->_aggregate( $list_ref );

#	This is just a wrapper for
#	Astro::Coord::ECI::TLE::Set->aggregate.

sub _aggregate {
    my ( $self, $bodies ) = @_;
    local $Astro::Coord::ECI::TLE::Set::Singleton = $self->{singleton};	## no critic (ProhibitPackageVars)
    return Astro::Coord::ECI::TLE::Set->aggregate ( @{ $bodies } );
}

#	_apply_boolean_default( \%opt, $invert, @keys );
#
#	This subroutine defaults a set of boolean options. The keys in
#	the set are specified in @keys, and the defined values are
#	inverted before the defaults are applied if $invert is true.
#	Nothing is returned.

sub _apply_boolean_default {
    my ( $opt, $invert, @keys ) = @_;
    my $found = 0;
    foreach my $key ( @keys ) {
	if ( exists $opt->{$key} ) {
	    $invert
		and $opt->{$key} = ( !  $opt->{$key} );
	    $found |= ( $opt->{$key} ? 2 : 1 );
	}
    }
    my $default = $found < 2;
    foreach my $key ( @keys ) {
	exists $opt->{$key}
	    or $opt->{$key} = $default;
    }
    return;
}

#	$self->_attribute_exists( $name );
#
#	This method returns true if an accessor for the given attribute
#	exists, and croaks otherwise.

sub _attribute_exists {
    my ( $self, $name ) = @_;
    exists $accessor{$name}
	or $self->_wail("No such attribute as '$name'");
    return $accessor{$name};
}

#	$chosen = _choose($opt, $choice, $list)

#	This subroutine chooses objects from a list. The arguments are:
#
#	$opt is an optional hash reference to options for the choice.
#	The only valid option is
#	    invert => 1 to invert the choice, retaining all objects that
#	    do _NOT_ match.
#
#	$choice is a reference to an array of choices These are strings,
#	which will be split on commas to yield the actual choice
#	criteria. Items which represent numbers greater than 999 will be
#	considered OID numbers, and match any object with the same OID.
#	All other items will be turned into regular expressions, and
#	matched against the name of the object.
#
#	$list is a reference to an array of objects to be selected from.
#	These objects must implement get() to get their attributes, and
#	must have attributes 'id' and 'name'.

sub _choose {
    my @args = @_;
    my $opt = ref $args[0] eq 'HASH' ? shift @args : {};
    my ($choice, $list) = @args;
    my @rslt;
    my @regex;
    my %oid;
    foreach (@$choice) {
	foreach (split ',', $_) {
	    if (m/ \D /smx) {
		push @regex, qr/ @{[ quotemeta $_ ]} /smxi;
	    } elsif ($_ < 1000) {
		push @regex, qr/ $_ /smx;
	    } else {
		$oid{$_} = 1;
	    }
	}
    }
    foreach my $tle (@$list) {
	my $id = ref $tle eq 'ARRAY' ? $tle->[0] : $tle->get('id');
	my $match = $opt->{invert};
	if ($oid{$id}) {
	    $match = !$match;
	} else {
	    my $name = ref $tle eq 'ARRAY' ? $tle->[1] : $tle->get('name');
	    foreach my $re (@regex) {
		$name =~ m/ $re /smx or next;
		$match = !$match;
		last;
	    }
	}
	$match and push @rslt, $tle;
    }
    return wantarray ? @rslt : \@rslt;
}



#	$self->_deprecation_notice( $type, $name );
#
#	This method centralizes deprecation. Type is 'attribute' or
#	'method'. Deprecation is driven of the %deprecate hash. Values
#	are:
#	    false - no warning
#	    1 - warn on first use
#	    2 - warn on each use
#	    3 - die on each use.
#
#	$self->_deprecation_in_progress( $type, $name )
#
#	This method returns true if the deprecation is in progress. In
#	practice this means the %deprecate value is defined.

{

    my %deprecate = (
	attribute => {
	    country	=> 0,
	    date_format	=> 0,
	    desired_equinox_dynamical	=> 0,
	    explicit_macro_delete	=> 0,
	    gmt		=> 0,
	    local_coord	=> 0,
	    perltime	=> 0,
	    time_format	=> 0,
	    tz		=> 0,
	},
	method => {
	    st	=> 0,
	},
    );

    sub _deprecation_notice {
	my ( $self, $type, $name ) = @_;
	$deprecate{$type} or return;
	$deprecate{$type}{$name} or return;
	$deprecate{$type}{$name} >= 3
	    and $self->_wail( "The $name $type is deprecated" );
	warnings::enabled( 'deprecated' )
	    and $self->_whinge( "The $name $type is deprecated" );
	$deprecate{$type}{$name} == 1
	    and $deprecate{$type}{$name} = 0;
	return;
    }

    sub _deprecation_in_progress {
	my ( $self, $type, $name ) = @_;
	$deprecate{$type} or return;
	return defined $deprecate{$type}{$name};
    }

}

sub _format_data {
    my ( $self, $action, $data, $opt ) = @_;
    return $self->_get_formatter_object( $opt )->$action( $data );
}

#	$frames = $satpass2->_frame_push($type, \@args);
#
#	This method pushes a context frame on the stack. The $type
#	describes the frame, and goes in the frame's {type} entry, but
#	is currently unused. The \@args entry goes in the {args} key,
#	and is the basis of argument expansion. The return is the number
#	of frames that were on the stack _BEFORE_ the now-current frame
#	was added to the stack. This gets passed to _frame_pop() to
#	restore the context stack to its status before the current frame
#	was added.

sub _frame_push {
    my $self = shift;
    my $type = shift;
    my $args = shift || [];
    my $frames = scalar @{$self->{frame} ||= []};
    my $stdout;
    @{$self->{frame}}
	and $stdout = exists $self->{frame}[-1]{localout} ?
	    $self->{frame}[-1]{localout} :
	    $self->{frame}[-1]{stdout};
####    defined $stdout or $stdout = select();
    my ( undef, $filename, $line ) = caller;
    push @{$self->{frame}}, {
	type => $type,
	args => $args,
	local => {},
	localout => undef,	# Output for statement.
	macro => {},
	pushed_by => "$filename line $line",
	spacetrack => {},
	stdout => $stdout,
    };
    return $frames;
}

#	$satpass2->_frame_pop($frames);
#	$satpass2->_frame_pop($type => $frames);
#	$satpass2->_frame_pop();
#
#	This method pops context frames off the stack until there are
#	$frames frames left. The optional $type argument is currently
#	unused, but was intended for type checking should that become
#	necessary. The zero-argument call pops one frame off the stack.
#	An exception is thrown if there are no frames left to pop. After
#	all required frames are popped, an exception is thrown if the
#	pop was done with a continued input line pending.

{

    my %force_set;	# If true, the named attribute is set with the
			# set() method even if a hash key of the same
			# name exists. This is set with
			# _frame_pop_force_set(), typically where the
			# mutator is defined.

    sub _frame_pop {
	my ($self, @args) = @_;
##	my $type = @args > 1 ? shift @args : undef;
	@args > 1 and shift @args;	# Currently unused
	my $frames = @args ? shift @args : @{$self->{frame}} - 1;
	while (@{$self->{frame}} > $frames) {
	    my $frame = pop @{$self->{frame}}
		or confess "Programming error - no frame to pop.";
	    my $local = $frame->{local} || {};
	    while (my ( $name, $value) = each %{ $local } ) {
		if ( exists $self->{$name} && !$force_set{$name} ) {
		    $self->{$name} = $value;
		} else {
		    $self->set( $name, $value );
		}
	    }
	    foreach my $key (qw{macro}) {
		my $info = $frame->{$key} || {};
		while (my ($name, $value) = each %$info) {
		    $self->{$key}{$name} = $value;
		}
	    }
	    ($frame->{spacetrack} && %{$frame->{spacetrack}})
		and $self->_get_spacetrack()->set(%{$frame->{spacetrack}});
	}
	if (delete $self->{pending}) {
	    $self->_wail("Input ended on continued line");
	}
	return;
    }

    # Force use of the set() method even if there is an attribute of the
    # same name.
    sub _frame_pop_force_set {
	foreach my $name ( @_ ) {
	    $force_set{$name} = 1;
	}
	return;
    }
}

#	$dumper = $self->_get_dumper();
#
#	This method returns a reference to code that can be used to dump
#	data. The first time it is called it goes through a list of
#	possible classes, and uses the first one it can load, dying if
#	it can not load any of them. After the first successful call, it
#	simply returns the cached dumper.

{
    my $dumper;
    my %kode = (
	'Data::Dumper' => sub {
	    local $Data::Dumper::Terse = 1;
	    Data::Dumper::Dumper(@_);
	},
    );
    sub _get_dumper {
	my ($self) = @_;
	my %dmpr;
	my @mod;
	return $dumper ||= do {
	    foreach (qw{YAML::Dump YAML::Syck::Dump YAML::Tiny::Dump
		Data::Dumper::Dumper}) {
		my ($module, $routine) = m/ (.*) :: (.*) /smx;
		push @mod, $module;
		$dmpr{$module} = $routine;
	    }
	    my $mod = $self->_load_module(@mod);
	    $kode{$mod} || $mod->can($dmpr{$mod});
	};
    }
}

#	$fmt = $satpass2->_get_dumper_object();
#
#	Gets a dumper object. This object must conform to the
#	Astro::App::Satpass2::Format interface.

{

    my $dumper;

    sub _get_dumper_object {
	return ( $dumper ||= do {
		require Astro::App::Satpass2::Format::Dump;
		Astro::App::Satpass2::Format::Dump->new();
	    }
	);
    }

}

#	$fmt = $satpass2->_get_formatter_object( $opt );
#
#	Gets the Astro::App::Satpass2::Format object. If $opt->{dump} is true,
#	returns a dumper object; otherwise returns the currently-set
#	formatter object.


sub _get_formatter_object {
    my ( $self, $opt ) = @_;
    $opt ||= {};
    return ( $opt && $opt->{dump} ) ? $self->_get_dumper_object() :
	$self->get( 'formatter' );
}

sub _get_formatter_attribute {
    my ( $self, $name ) = @_;
    return $self->get( 'formatter' )->$name();
}

#	$boolean = $satpass2->_get_interactive();
#
#	This method returns true if the script is running interactively,
#	and false otherwise. Currently, it returns the results of -t
#	STDIN.

sub _get_interactive {
    return -t STDIN;
}

#	$code = $satpass2->_get_readline();
#
#	Returns code to read input. The code takes an argument which
#	will be used as a prompt if one is needed. What is actually
#	returned is:
#
#	If $satpass2->_get_interactive() is false, the returned code
#	just reads standard in. Otherwise,
#
#	if Term::ReadLine can be loaded, a Term::ReadLine object is
#	instantiated if need be, and the returned code calls
#	Term::ReadLine->readline($_[0]) and returns whatever that gives
#	you. Otherwise,
#
#	Otherwise the returned code writes its argument to STDERR and
#	reads STDIN.
#
#	Note that the return from this subroutine may or may not be
#	chomped.

{
    my $rl;

    sub _get_readline {
	my ($self) = @_;
	# The Perl::Critic recommendation is IO::Interactive, but that
	# fiddles with STDOUT. We want STDIN, because we want to behave
	# differently if STDIN is a pipe, but not if STDOUT is a pipe.
	# We're still missing the *ARGV logic, but that's OK too, since
	# we use the contents of @ARGV as commands, not as file names.
	return do {
	    my $buffer = '';
	    if ($self->_get_interactive()) {
		eval {
		    require Term::ReadLine;
		    $rl ||= Term::ReadLine->new("satpass2");
		    sub {
			defined $buffer or return $buffer;
			return ( $buffer = $rl->readline($_[0]) );
		    }
		} || sub {
		    defined $buffer or return $buffer;
		    print STDERR $_[0];
		    return (
			$buffer = <STDIN>	## no critic (ProhibitExplicitStdin)
		    );
		};
	    } else {
		sub {
		    defined $buffer or return $buffer;
		    return (
			$buffer = <STDIN>	## no critic (ProhibitExplicitStdin)
		    );
		};
	    }
	};
    }
}

sub _get_time_parser_attribute {
    my ( $self, $name ) = @_;
    return $self->{time_parser}->$name();
}

#	$st = $satpass2->_get_spacetrack()

#	Gets the Astro::SpaceTrack object, instantiating it if
#	necesary.

sub _get_spacetrack {
    my $self = shift;
    $self->{spacetrack} and return $self->{spacetrack};
    $self->_load_module ('Astro::SpaceTrack');
    return ($self->{spacetrack} ||= $self->_get_spacetrack_default());
}

#	$st = $satpass2->_get_spacetrack_default();
#
#	Returns a new Astro::SpaceTrack object, initialized with this
#	object's webcmd, and with its filter attribute set to 1 and its
#	iridium_status_format set to 'kelso'.

sub _get_spacetrack_default {
    my $self = shift;
    return Astro::SpaceTrack->new (
	webcmd => $self->{webcmd},
	filter => 1,
	iridium_status_format => 'kelso',
    );
}

#	$satpass2->_get_station();

#	This subroutine manufactures and returns a station object
#	appropriate to the current parameter settings. It throws an
#	exception if the height, latitude, and longitude are not
#	defined.

sub _get_station {
    my $self = shift;
    (defined $self->{height} && defined $self->{latitude} &&
	defined $self->{longitude})
	or $self->_wail("You must set height, latitude, and longitude");
    return Astro::Coord::ECI->new (
	    refraction => 1,
	    name => $self->{location} || '',
	    id => 'station',
	    )
	->geodetic (
	    deg2rad ($self->{latitude}), deg2rad ($self->{longitude}),
	    $self->{height} / 1000);
}

sub _get_today_midnight {
    my $self = shift;
    my $gmt = $self->get( 'formatter' )->gmt();
    my @time = $gmt ? gmtime() : localtime();
    $time[0] = $time[1] = $time[2] = 0;
    return $gmt ? timegm(@time) : timelocal(@time);
}

sub _get_today_noon {
    my $self = shift;
    my $gmt = $self->get( 'formatter' )->gmt();
    my @time = $gmt ? gmtime() : localtime();
    $time[0] = $time[1] = 0;
    $time[2] = 12;
    return $gmt ? timegm(@time) : timelocal(@time);
}

sub _get_warner_attribute {
    my ( $self, $name ) = @_;
    return $self->{_warner}->$name();
}

#	@args = $self->_getopt(@args);
#
#	This subroutine determines the name of its caller, and parses
#	out of the argument list any options specified in the caller's
#	Verb() attribute. Before the parse, Getopt::Long is configured
#	according to the caller's Configure() attribute if present, or
#	the default configuration if not. The return is a list whose
#	first element is a reference to the hash containing the parsed
#	options, and whose subsequent elements are the remaining
#	arguments, if any.
#
{

    my @default_config = qw{default pass_through};
####    my @default_config = qw{default};

    sub _getopt {
	local @ARGV = @_;
	my $self = shift @ARGV;
	return @ARGV
	    if 'HASH' eq ref $ARGV[0];
	my @data = caller(1);
	my $code = \&{$data[3]};
	my $lgl = _get_attr($code, 'Verb') || [];
	my %opt;
	my $err;
	local $SIG{__WARN__} = sub {$err = $_[0]};
	my $config = 
	    _get_attr($code, 'Configure') || \@default_config;
	my $go = Getopt::Long::Parser->new(config => $config);
	$go->getoptions(\%opt, @$lgl) or $self->_wail($err);

	return \%opt, @ARGV;
    }
}

#	$satpass2->_iridium_status(\@status)

#	Updates the status of all Iridium satellites from the given
#	array, which is compatible with the second item returned by
#	Astro::SpaceTrack->iridium_status(). If no argument is passed,
#	the status is retrieved using Astro::SpaceTrack->iridium_status()

sub _iridium_status {
    my ($self, $status) = @_;
    unless ($status) {
	my $st = $self->_get_spacetrack();
	(my $rslt, $status) = $st->iridium_status;
	$rslt->is_success or $self->_wail($rslt->status_line);
    }

    if (ref $status eq 'ARRAY') {
	Astro::Coord::ECI::TLE->status (clear => 'iridium');
	foreach (@$status) {
	    Astro::Coord::ECI::TLE->status (add => $_->[0], iridium =>
		$_->[4], $_->[1], $_->[5]);
	}
    } else {
	confess <<'EOD';
Programming error - Portable status not passed, and unavailable from
	Astro::SpaceTrack->iridium_status.
EOD
    }

    foreach my $tle (@{$self->{bodies}}) {
	$tle->rebless ();
    }

    return;

}

#	_is_interactive()
#
#	Returns true if the dispatch() method is above us on the call
#	stack, otherwise returns false.

use constant INTERACTIVE_CALLER => __PACKAGE__ . '::dispatch';
sub _is_interactive {
    my $level = 0;
    while ( my @info = caller( $level ) ) {
	INTERACTIVE_CALLER eq $info[3]
	    and return $level;
	$level++;
    }
    return;
}

#	$self->_load_module ($module_name)

#	Loads the module if it has not yet been loaded. Dies if it
#	can not be loaded.

{	# Begin local symbol block

    my %version;
    BEGIN {
	%version = (
	    'Astro::SpaceTrack' => ASTRO_SPACETRACK_VERSION,
	);
    }

    sub _load_module {
	my ($self, @module) = @_;
	ref $module[0] eq 'ARRAY' and @module = @{$module[0]};
	@module or confess "Programming error - No module specified";
	my @probs;
	foreach my $module (@module) {
	    load_module ($module) or do {
		push @probs, "$module needed";
		next;
	    };
	    my $modver;
	    ($version{$module} && ($modver = $module->VERSION)) and do {
		$modver =~ s/_//g;
		$modver < $version{$module} and do {
		    push @probs,
		    "$module version $version{$module} needed";
		    next;
		};
	    };
	    return $module;
	}
	{
	    my $inx = 1;
	    while (my @clr = caller($inx++)) {
		$clr[3] eq '(eval)' and next;
		my @raw = split '::', $clr[3];
		substr ($raw[-1], 0, 1) eq '_' and next;
		push @probs, "for method $raw[-1]";
		last;
	    }
	}
	my $pfx = 'Error -';
	$self->_wail(map {my $x = "$pfx $_\n"; $pfx = ' ' x 7; $x} @probs);
	return;	# Can't get here, but Perl::Critic does not know this.
    }

}	# end local symbol block.

#	$output = $self->_macro($name,@args)
#
#	Execute the named macro. The @args are of course optional.

sub _macro {
    my ($self, $name, @args) = @_;
    $self->{macro}{$name} or $self->_wail("No such macro as '$name'");
    my $frames = $self->_frame_push(macro => [@args]);
    $self->{frame}[-1]{level1} = $self->{macro}{$name}{level1};
    my $macro = $self->{frame}[-1]{macro}{$name} =
	delete $self->{macro}{$name};
    my $output;
    my $err;
    my $ok = eval {
	foreach (@{ $macro->{def} }) {
	    if (defined (my $buffer = $self->execute($_))) {
		$output .= $buffer;
	    }
	}
	1;
    } or $err = $@;
    $self->_frame_pop($frames);
    $ok or $self->_wail($err);
    return $output;
}


#	$angle = _parse_angle ($string)

#	Parses an angle in degrees, hours:minutes:seconds, or
#	degreesDminutesMsecondsS and returns the angle in degrees.

sub _parse_angle {
    my $angle = shift;
    defined $angle or return;
    if ( $angle =~ m/ : /smx ) {
	my ($h, $m, $s) = split ':', $angle;
	$s ||= 0;
	$m ||= 0;
	$h ||= 0;
	$m += $s / 60;
	$h += $m / 60;
	$angle = $h * 360 / 24;
    } elsif ( $angle =~
	m{ \A ( [-+] )? (\d*) d
	    ( \d* (?: [.] \d*)? ) (?: m
	    ( \d* (?: [.] \d* )? ) s? )? \z
	}smxi ) {
	$angle = ((($4 || 0) / 60) + ($3 || 0)) / 60 + ($2 || 0);
	$angle = -$angle if $1 && $1 eq '-';
    }
    return $angle;
}

#	$distance = $self->_parse_distance ($string, $units)

#	Strips 'm', 'km', 'au', 'ly', or 'pc' from the end of $string,
#	the default being $units. Converts to km.

{
    my %units = (
	au => AU,
	ft => 0.0003048,
	km => 1,
	ly => LIGHTYEAR,
	m => .001,
	mi => 1.609344,
	pc => PARSEC,
    );

    sub _parse_distance {
	my ($self, $string, $dfdist) = @_;
	defined $dfdist or $dfdist = 'km';
	my $dfunits = $dfdist =~ s/ ( [[:alpha:]]+ ) \z //smx ? $1 : 'km';
	my $units = lc (
	    $string =~ s/ ( [[:alpha:]]+ ) \z //smx ? $1 : $dfunits);
	$units{$units}
	    or $self->_wail( "Units of '$units' are unknown" );
	$string ne '' or $string = $dfdist;
	looks_like_number ($string)
	    or $self->_wail( "'$string' is not a number" );
	return $string * $units{$units};
    }
}

#	$time = $satpass2->_parse_time($string, $default)

#	Parses a time string in any known format. Strings with a
#	leading "+" or "-" are assumed to be relative to the last
#	explicit setting. Otherwise the time is assumed to be explicit,
#	and passed to Date::Manip. The parsed time is returned. If the
#	time to be parsed is false (in the Perl sense) we return the
#	default (if specified) or the current time. We die on an
#	invalid time.

sub _parse_time {
    my ($self, $time, $default) = @_;
    my $pt = $self->{time_parser};
    if ( defined( my $time = $pt->parse( $time, $default ) ) ) {
	return $time;
    }
    $self->_wail( "Invalid time '$time'" );
    return;
}


#	Reset the last time set.

sub _parse_time_reset {
    my ( $self ) = @_;
    my $pt = $self->{time_parser};
    defined $pt
	or confess 'Programming error - $self->{time_parser} not defined';
    $pt->reset();
    return $pt->base();
}

#	$string = _rad2hms ($angle)

#	Converts the given angle in radians to hours, minutes, and
#	seconds (of right ascension, presumably)

sub _rad2hms {
    my $sec = shift;
    $sec *= 12 / PI;
    my $hr = floor( $sec );
    $sec = ( $sec - $hr ) * 60;
    my $min = floor( $sec );
    $sec = ( $sec - $min ) * 60;
    my $rslt = sprintf '%2d:%02d:%02d', $hr, $min, floor( $sec + .5 );
    return $rslt;
}

#	$line = $self->_read_continuation( $in, $error_message );
#
#	Acquire a line from $in, which must be a code reference taking
#	the prompt as an argument. If $in is not a code reference, or if
#	it returns undef, we _wail() with the error message.  Otherwise
#	we return the line read. I expect this to be used only by
#	_tokenize().

sub _read_continuation {
    my ( $self, $in, $error ) = @_;
    $in and defined( my $more = $in->(
	    my $prompt = $self->get( 'continuation_prompt' ) ) )
	or do {
	    $error or return;
	    ref $error eq 'CODE' and return $error->();
	    $self->_wail( $error );
	};
    $self->{echo} and $self->_whinge( $prompt, $more );
    $more =~ m/ \n \z /smx or $more .= "\n";
    return $more;
}

#	$self->_rewrite_level1_macros();
#
#	This method rewrites all macros defined by a satpass
#	initialization file (as opposed to a satpass2 initialization
#	file) to be satpass2-compatable. It also clears the level1 flag
#	so that the satpass-compatible functionality is not invoked.
#
#	Specifically it:
#	* Inserts a 'location' command before 'almanac' and 'pass';
#	* Changes the senses of the -am, -day, and -pm options in
#	  'flare';
#	* Removes delegated attributes from 'localize', replacing them
#	  with a localization of the helper object.
#
#	This method goes away when the satpass functionality does.

{
    my %helper_map = (
	date_format	=> {
	    helper	=> 'formatter',		# Helper obj attr. Req'd.
	},
	desired_equinox_dynamical	=> {
	    helper	=> 'formatter',
	},
	gmt		=> {
	    helper	=> 'formatter',
	},
	local_coord	=> {
	    helper	=> 'formatter',
	},
	time_format	=> {
	    helper	=> 'formatter',
	},
    );

    my %filter = (
	almanac	=> sub {
	    my ( $verb, $line ) = @_;
	    return ( 'location', $line );
	},
	flare	=> sub {
	    my ( $verb, $line ) = @_;
	    $line =~ s/ (?<= \s ) - (am|day|pm) \b /-no$1/smx;
	    return $line;
	},
	localize	=> sub {
	    my ( $verb, $line ) = @_;
	    my @things = split qr{ \s+ }smx, $line;
	    my @output;
	    my %duplicate;
	    foreach my $token ( @things ) {
		$helper_map{$token}
		    and $token = $helper_map{$token}{helper};
		$duplicate{$token}++ or push @output, $token;
	    }
	    return join ' ', @output;
	},
	pass	=> sub {
	    my ( $verb, $line ) = @_;
	    return ( 'location', $line );
	},
	set	=> sub {
	    my ( $verb, $line ) = @_;
	    my @output = [ 'fubar' ];	# Prime the pump.
	    my @input = Text::ParseWords::quotewords( qr{ \s+ }smx, 1,
		$line );
	    shift @input;
	    while ( @input ) {
		my ( $attr, $val ) = splice @input, 0, 2;
		if ( my $helper = $helper_map{$attr} ) {
		    push @output, [ 'tell', $helper->{helper},
			# not quoter( $val ) here, because presumably it
			# is already quoted if it needs to be.
			$helper->{attribute} || $attr, $val ];
		} else {
		    'set' eq $output[-1][0]
			or push @output, [ 'set' ];
		    # not quoter( $val ) here, because presumably it is
		    # already quoted if it needs to be.
		    push @{ $output[-1] }, $attr, $val;
		}
	    }
	    shift @output;	# Get rid of the pump priming.
	    return ( map { join ' ', @{ $_ } } @output );
	},
	st	=> sub {
	    my ( $verb, $line ) = @_;
	    $line =~ s/ \b st \b /tell spacetrack/smx;
	    return $line;
	},
	show	=> sub {
	    my ( $verb, $line ) = @_;
	    my @output = [ 'fubar' ];
	    my @input = split qr{ \s+ }smx, $line;
	    shift @input;
	    foreach my $attr ( @input ) {
		if ( my $helper = $helper_map{$attr} ) {
		    push @output, [ 'tell', $helper->{helper},
			$helper->{attribute} || $attr ];
		} else {
		    'show' eq $output[-1][0]
			or push @output, [ 'show' ];
		    push @{ $output[-1] }, $attr;
		}
	    }
	    shift @output;
	    return ( map { join ' ', @{ $_ } } @output );
	},
    );

    sub _rewrite_level1_macros {
	my ( $self ) = @_;

	while ( my ( $name, $macro ) = each %{ $self->{macro} } ) {

	    delete $macro->{level1} or next;

	    my ( $rewrote, @rslt );
	    foreach ( @{ $macro->{def} } ) {
		if ( m/ ( \S+ ) /smx
			and ( not $self->{macro}{$1}
			    or $1 eq $name )
			and my $code = $filter{$1} ) {
		    push @rslt, $code->( $1, $_ );
		    $rewrote++;
		} else {
		    push @rslt, $_;
		}
	    }

	    $rewrote
		and $macro->{def} = \@rslt;

	}

	return;
    }
}

#	@coordinates = $self->_simbad4 ($query)

#	Look up the given star in the SIMBAD catalog. This assumes
#	SIMBAD 4.

#	We die on any error.

sub _simbad4 {
    my $self = shift;
    $self->_load_module ('Astro::SIMBAD::Client');
    my $query = shift;
    my $simbad = Astro::SIMBAD::Client->new (
	format => {txt => 'FORMAT_TXT_SIMPLE_BASIC'},
	parser => {txt => 'Parse_TXT_Simple'},
	server => $self->{simbad_url},
	type => 'txt',
    );
    my @rslt = $simbad->query (id => $query)
	or $self->_wail("No entry found for $query");
    @rslt > 1
	and $self->_wail("More than one entry found for $query");
    @rslt = map {$rslt[0]{$_} eq '~' ? 0 : $rslt[0]{$_} || 0} qw{
	ra dec plx pmra pmdec radial};
    ($rslt[0] && $rslt[1])
	or $self->_wail("No position returned by $query");
    $rslt[2] = $rslt[2] ? 1000 / $rslt[2] : 10000;
    $rslt[3] and $rslt[3] /= 1000;
    $rslt[4] and $rslt[4] /= 1000;
    return wantarray ? @rslt : join ' ', @rslt;
}

#	$soap_object = _soapdish ($uri, $proxy, $action)

#	Manufacture a SOAP::Lite object for the given uri and proxy.
#	We need this because SOAP::Lite has changed significantly since
#	the 2002 version that is to this day (2006) bundled with
#	ActivePerl.

#	The action argument is the separater for building the
#	SOAPAction header. It defaults to '' (suitable for .NET's
#	delicate digestion). If you want to restore SOAP::Lite's
#	original behavior, specify '#'. Any other values are
#	_NOT_ supported, and may result in a visit from unsympathetic
#	men in snap-brim hats, dark glasses, and bad suits.

sub _soapdish {
    my ($uri, $proxy, $conn) = @_;
    $conn ||= '';
    return SOAP::Lite->can ('default_ns') ?
	SOAP::Lite
	    ->default_ns ($uri)
	    ->on_action (sub {join $conn, @_})
	    ->proxy ($proxy, timeout => 30) :
	SOAP::Lite
	    ->envprefix ('soap')
	    ->on_action (sub {join $conn, @_})
	    ->uri ($uri)
	    ->proxy ($proxy, timeout => 30);
}

#	$result = $self->_tilde_expand($token);
#
#	This does a tilde expansion on the token. If the token does not
#	in fact begin with a tilde, it is simply returned. If it does
#	begin with a tilde, everything between the tilde and the first
#	slash is considered to be a username. If the username is empty
#	the user's home directory is prepended, otherwise the given
#	user's home directory is prepended, or an exception is thrown if
#	getpwnam doesn't work or the user does not exist.

sub _tilde_expand {
    my ( $self, $fn ) = @_;
    $fn =~ m{ \A ~ ( [^/]* ) }smx or return $fn;
    substr $fn, 0, $+[0], $self->_user_home_dir( $1 );
    return $fn;
}

#	@result = _unescape( @args );
#
#	Remove back slash escapes. Nothing fancy is done here; in
#	particular, '\n' does not become a new line, it becomes "n".

sub _unescape {
    my ( @args ) = @_;
    foreach ( @args ) {
	s/ \\ (.) /$1/smxg;
    }
    return @args;
}

#	$dir = $self->_user_home_dir( $user );
#
#	Find the home directory for the given user, croaking if this can
#	not be done. If $user is '' or undef, returns the home directory
#	for the current user.

sub _user_home_dir {
    my ( $self, $user ) = @_;
    defined $user or $user = '';
    '+' eq $user and return Cwd::cwd();
    '' eq $user and return File::HomeDir->my_home();
    my $home_dir = File::HomeDir->users_home( $user );
    defined $home_dir
	or $self->_wail( "Unable to find home for $user" );
    return $home_dir;
}

#	($tokens, $redirect) = $self->_tokenize(
#		{option => $value}, $buffer, [$arg0 ...]);
#
#	This method tokenizes the buffer. The options hash may be
#	omitted, in which case the $buffer to be tokenized is the first
#	argument. After the buffer is an optional reference to an array
#	of arguments to be substituted in.
#
#	This method attempts to parse and tokenize the buffer in a way
#	similar to the bash shell. That is, parameters are interpolated
#	inside double quotes but not single quotes, tilde expansion
#	takes place unless quoted, and spaces delimit tokens only when
#	occurring outside quotes.
#
#	The back slash character ('\') is an escape character. Inside
#	single quotes only the back slash itself and a single quote may
#	be escaped. Otherwise, anything can be escaped.
#
#	The returns are a reference to an array of tokens found, and a
#	reference to a hash of redirections found. This hash will have
#	zero or more of the keys '>' (standard output redirection) and
#	'<' (standard input redirection. The value of each key will be a
#	reference to a hash containing keys 'mode' ('>' or '>>' for
#	output, '<' or '<<' for input) and 'name' (normally the file
#	name).
#
#	The recognized options are:
#
#	    single => 1
#		causes the buffer to be interpreted as a single token.
#
#	    noredirect => 1
#		causes redirects to be illegal.
#
#	If noredirect is specified, only the $tokens reference is
#	returned. If noredirect and single are both specified, the
#	parsed and interpolated token is returned.
#
#	If interpolation is being done, an un-escaped dollar sign
#	introduces the interpolation. This works pretty much the same
#	way as under bash: if the first character after the dollar sign
#	is a left curly bracket, everything to the corresponding right
#	curly bracked specifies the interpolation; if not, the rule is
#	that word characters specify the interpolation.
#
#	A number (i.e. $1) specifies interpolation of an argument.
#	Arguments are numbered starting at 1.
#
#	Otherwise, if the interpolation names an attribute, the value of
#	that attribute is interpolated in, otherwise the named
#	environment variable is interpolated in.
#
#	Most of the fancier forms of interpolation are suported. In the
#	following, word is expanded by recursively calling _tokenize
#	with options {single => 1, noredirect => 1}. But unlike bash, we
#	make no distinction between unset or null. The ':' can be
#	omitted before the '-', '=', '?' or '+', but it does not change
#	the functionality.
#
#	${parameter:-word} causes the given word to be substituted if
#	the parameter is undefined.
#
#	${parameter:=word} is the same as above, but also causes the
#	word to be assigned to the parameter if it is unassigned. Unlike
#	bash, this assignment takes place on positional parameters. If
#	done on an attribute or environment variable, it causes that
#	attribute or environment variable to be set to the given value.
#
#	${parameter:?word} causes the parse to fail with the error
#	'word' if the parameter is undefined.
#
#	${parameter:+word} causes the value of the given word to be used
#	if the parameter is defined, otherwise '' is used.
#
#	${parameter:offset} and ${parameter:offset:length} take
#	substrings of the parameter value. The offset and length must be
#	numeric.

{

    # Special variables.
    # Calling sequence: $special{$name}->(\@args, $relquote)
    my %special = (
	'0' => sub { return $0 },
	'#' => sub { return scalar @{ $_[0] } },
##	'*' => sub { return join ' ', @{ $_[0] } },
##	'@' => sub { return $_[1] ? join( ' ', @{ $_[0] } ) : $_[0] },
	'*' => sub { return $_[1] ? join( ' ', @{ $_[0] } ) : $_[0] },
	'@' => sub { return $_[0] },
	'$' => sub { return $$ },
	'_' => sub { return $^X },
    );

    # Leading punctuation that is equivalent to a method.
    my %command_equivalent = (
	'.'	=> 'source',
	'!' => 'system',
    );
    my $command_equiv_re = do {
	my $keys = join '', sort keys %command_equivalent;
	qr{ [$keys] }smx;
    };

    sub _tokenize {
	my ($self, @parms) = @_;
	my $opt = ref $parms[0] eq 'HASH' ? shift @parms : {};
	my $in = $opt->{in};
	my $buffer = shift @parms;
	$buffer =~ m/ \n \z /smx or $buffer .= "\n";
	my $args = shift @parms || [];
	my @rslt = ( {} );
	my $absquote;	# True if inside ''
	my $relquote;	# True if inside "" (and not in '')
	my $len = length $buffer;
	my $inx = 0;

	# Because I'm not smart enough to do all this with a regular
	# expression, I take the brute force approach and iterate
	# through the buffer to be tokenized. It's a 'while' rather than
	# a 'for' or 'foreach' because that way I get to muck around
	# with the current position inside the loop.

	while ($inx < $len) {
	    my $char = substr $buffer, $inx++, 1;

	    # If we're inside single quotes, the only escapable
	    # characters are single quote and back slash, and all
	    # characters until the next unescaped single quote go into
	    # the current token

	    if ( $absquote ) {
		if ( $char eq '\\' ) {
		    if ( (my $next = substr $buffer, $inx, 1) =~
			m/ ['\\] /smx ) {
			$inx++;
			$rslt[-1]{token} .= $next;
		    } else {
			$rslt[-1]{token} .= $char;
		    }
		} elsif ( $char eq q{'} ) {
		    $absquote = undef;
		} else {
		    $rslt[-1]{token} .= $char;
		    if ( $inx >= $len ) {
			$buffer .= $self->_read_continuation( $in,
			    'Unclosed single quote' );
			$len = length $buffer;
		    }
		}

	    # If we have a backslash, it escapes the next character,
	    # which goes on the current token no matter what it is.

	    } elsif ( $char eq '\\' ) {
		my $next = substr $buffer, $inx++, 1;
		if ( $inx >= $len ) {	# At end of line
		    if ( $relquote ) {	# Inside ""
			$buffer .= $self->_read_continuation( $in,
			    'Unclosed double quote' );
		    } else {		# Between tokens
			$buffer .= $self->_read_continuation( $in,
			    'Dangling continuation' );
			$opt->{single} or push @rslt, {};	# New token
		    }
		    $len = length $buffer;
		} else {
		    $rslt[-1]{token} .= $next;
		}

	    # If we have a single quote and we're not inside double
	    # quotes, we go into absolute quote mode. We also append an
	    # empty string to the current token to force its value to be
	    # defined; otherwise empty quotes do not generate tokens.

	    } elsif ($char eq q{'} && !$relquote) {
		$rslt[-1]{token} .= '';	# Empty string, to force defined.
		$absquote++;

	    # If we have a double quote, we toggle relative quote mode.
	    # We also append an empty string to the current tokens for
	    # the reasons discussed above.

	    } elsif ($char eq '"') {
		$rslt[-1]{token} .= '';	# Empty string, to force defined.
		$relquote = !$relquote;

	    # If we have a whitespace character and we're not inside
	    # quotes and not in single-token mode, we start a new token.
	    # It is possible that we generate redundant tokens this way,
	    # but the unused ones are eliminated later.

	    } elsif ($char =~ m/ \s /smx && !$relquote && !$opt->{single}) {
		push @rslt, {};

	    # If we have a dollar sign, it introduces parameter
	    # substitution, a non trivial endeavor.

	    } elsif ( $char eq '$' && $inx < $len ) {
		my $name = substr $buffer, $inx++, 1;
		my $brkt;

		# Names beginning with brackets are special. We note the
		# fact and scan for the matching close bracket, throwing
		# an exception if we do not have one.

		if ($name eq '{' && $inx < $len) {
		    $brkt = 1;
		    $name = '';
		    my $nest = 1;
		    while ($inx < $len) {
			$char = substr $buffer, $inx++, 1;
			if ($char eq '{') {
			    $nest++;
			} elsif ($char eq '}') {
			    --$nest or last;
			}
			$name .= $char;
		    }
		    $char eq '}'
			or $self->_wail("Missing right curly bracket");
		
		# If the name begins with an alpha or an underscore, we
		# simply append any word ('\w') characters to it and
		# advance the current location past them.

		} elsif ( $name =~ m/ \A [[:alpha:]_] \z /smx ) {
		    pos( $buffer ) = $inx;
		    if ( $buffer =~ m/ \G ( \w* ) /smxgc ) {
			$name .= $1;
			$inx += length $1;
		    }
		}

		# Only bracketed names can be indirected, and then only
		# if the first character is a bang.

		my ($indirect, $value);
		$brkt and $indirect = $name =~ s/ \A ! //smx;

		# If we find a colon and/or one of the other cabbalistic
		# characters, we need to do some default processing.

		if ($name =~ m/ (.*?) ( [:]? [\-\+\=\?] | [:] ) (.*) /smx) {
		    my ($name, $flag, $rest) = ($1, $2, $3);

		    # First we do indirection if that was required.

		    $indirect
			and $name = $self->_tokenize_var(
			    $name, $args, $relquote, $indirect);

		    # Next we find out whether we have an honest-to-God
		    # colon, since that might specify substring
		    # processing.

##		    my $colon = $flag =~ s/ \A : //smx ? ':' : '';
		    $flag =~ s/ \A : //smx;

		    # We run the stuff after the first cabbalistic
		    # character through the tokenizer, since further
		    # expansion is possible here.

		    my $mod = _tokenize(
			$self,
			{ single => 1, noredirect => 1, in => $in },
			$rest, $args);
		    chomp $mod;	# Don't want trailing \n here.

		    # At long last we get the actual value of the
		    # variable. This will be either undef, a scalar, or
		    # a list reference.

		    $value = $self->_tokenize_var(
			$name, $args, $relquote);

		    # The value is logically defined if it is a scalar
		    # and not undef, or if it is an array reference and
		    # the array is not empty.

		    my $defined = ref $value ? @$value : defined $value;

		    # The '+' cabbalistic sign replaces the value of the
		    # variable if it is logically defined.

		    if ($flag eq '+') {
			$value = $defined ? $mod : '';

		    # If the variable is defined, only substring
		    # processing is possible. This actually is
		    # implemented as slice processing if the value is an
		    # array reference.

		    } elsif ($defined) {
			if ($flag eq '') {
			    my @pos = split ':', $mod, 2;
			    foreach ( @pos ) {
				s/ \A \s+ //smx;
			    }
			    @pos > 2
				and $self->_wail(
				"Substring expansion has extra arguments" );
			    foreach ( @pos ) {
				m/ \A [-+]? \d+ \z /smx
				    or $self->_wail(
				    "Substring expansion argument non-numeric"
				);
			    }
			    if (ref $value) {
				if (@pos > 1) {
				    $pos[1] += $pos[0] - 1;
				} else {
				    $pos[1] = $#$args;
				}
				$pos[1] > $#$value and $pos[1] = $#$value;
				$value = [@$value[$pos[0] .. $pos[1]]];
			    } else {
				# We want to disable warnings if we slop
				# outside the string.
				no warnings qw{substr};
				$value = @pos == 1 ? substr $value, $pos[0] :
				    substr $value, $pos[0], $pos[1];
			    }
			}

		    # If the cabbalistic sign is '-', we supply the
		    # remainder of the specification as the default.

		    } elsif ($flag eq '-') {
			$value = $mod;

		    # If the cabbalistic sign is '=', we supply the
		    # remainder of the specification as the default. We
		    # also set the variable to the value, for future
		    # use. Note that special variables may not be set,
		    # and result in an exception.

		    } elsif ($flag eq '=') {
			$value = $mod;
			if ( $special{$name} || $name !~ m/ \D /smx ) {
			    $self->_wail("Cannot assign to \$$name");
##			} elsif ($name !~ m/\D/) {
##			    $args->[$name - 1] = $value;
			} elsif (exists $mutator{$name}) {
			    $self->set($name => $value);
			} else {
			    $self->{exported}{$name} = $value;
			}

		    # If the cabbalistic sign is '?', we throw an
		    # exception with the remainder of the specification
		    # as the text.

		    } elsif ($flag eq '?') {
			$self->_wail($mod);

		    # If there is no cabbalistic sign at all, we fell
		    # through here trying to do substring expansion on
		    # an undefined variable. Since Bash allows this, we
		    # will to, though with misgivings.

		    } elsif ( $flag eq '' ) {
			$value = '';

		    # Given the way the parser works, the above should
		    # have exhausted all possibilities. But being a
		    # cautious programmer ...

		    } else {
			confess "Programming Error - \$flag = '$flag'. ",
			"This should not happen";
		    }

		# Without any cabbalistic signs, variable expansion is
		# easy. We perform the indirection if needed, and then
		# grab the value of the variable, which still can be
		# undef, a scalar, or an array reference.

		} else {
		    $indirect
			and $name = $self->_tokenize_var(
			$name, $args, $relquote, $indirect);
		    $value = $self->_tokenize_var(
			$name, $args, $relquote);
		}

		# If the value is not logically defined (i.e. it is
		# undef or an empty array) we do nothing.

		if (ref $value ? !@$value : !defined $value) {

		# If the value is an array reference, we append each
		# element to the current token, and then create a new
		# token for the next element. The last element's empty
		# token gets discarded, since we may need to append
		# more data to the last element (e.g. "$@ foo").

		} elsif (ref $value) {
		    foreach (@$value) {
			$rslt[-1]{token} .= $_;
			push @rslt, {};
		    }
		    pop @rslt;

		# A scalar is the only remaining possibility. We append
		# its value to the current token.

		} else {
		    $rslt[-1]{token} .= $value;
		}

		# Here ends the variable expansion code.

	    # If the character is an angle bracket or a pipe, we have a
	    # redirect specification. This always starts a new token. We
	    # flag the token as a redirect, stuff all matching
	    # characters into the mode (throwing an exception if there
	    # are too many), consume any trailing spaces, and set the
	    # token value to the empty string to prevent executing this
	    # code again when we hit the first character of the file
	    # name. Note that redirect tokens always get tilde
	    # expansion.

	    } elsif ( $char =~ m/ [<>|] /smx ) {
		push @rslt, {
		    redirect => 1,
		    type => ($char eq '<' ? '<' : '>'),
		    mode => ($char eq '|' ? '|-' : $char),
		    expand => ($char ne '|')
		};
		while ($inx < $len) {
		    my $next = substr $buffer, $inx++, 1;
		    $next =~ m/ \s /smx and next;
		    if ($next eq $char) {
			$rslt[-1]{mode} .= $next;
			length $rslt[-1]{mode} > 2
			    and $self->_wail(
			    "Syntax error near $rslt[-1]{mode}");
		    } else {
			--$inx;
			$rslt[-1]{token} = '';
			last;
		    }
		}

	    # If the token already exists at this point, the current
	    # character, whatever it is, is simply appended to it.

	    } elsif (exists $rslt[-1]{token} || $relquote) {
		$rslt[-1]{token} .= $char;

	    # If the character is a tilde, we flag the token for tilde
	    # expansion.

	    } elsif ($char eq '~') {
		$rslt[-1]{tilde}++;
		$rslt[-1]{token} .= $char;

	    # If the character is a hash mark, it means a comment. Bail
	    # out of the loop.
	    } elsif ( $char eq '#' ) {
		last;

	    # Else we just put it in the token.
	    } else {
		$rslt[-1]{token} .= $char;
	    }
	}

	# We have run through the entire string to be tokenized. If
	# there are unclosed quotes of either sort, we declare an error
	# here.

	$absquote and $self->_wail( 'Unclosed terminal single quote' );
	$relquote and $self->_wail( 'Unclosed terminal double quote' );

	# Go through our prospective tokens, keeping only those that
	# were actually defined, and shuffling the redirects off into
	# the redirect hash.

	my (@tokens, %redir);
	foreach (@rslt) {
	    exists $_->{token} or next;
	    if ($_->{redirect}) {
		my $type = $_->{type};
		$redir{$type} = {
		    mode => $_->{mode},
		    name => ($_->{expand} ?
			$self->_tilde_expand($_->{token}) :
			$_->{token}),
		};
	    } else {
		push @tokens, $_->{tilde} ? $self->_tilde_expand($_->{token}) :
		    $_->{token};
	    }
	}

	# Replace leading punctuation with the corresponding method.

	if ( defined $tokens[0] and
		$tokens[0] =~ s/ \A ( $command_equiv_re ) //smx ) {
	    if ( $tokens[0] eq '' ) {
		$tokens[0] = $command_equivalent{$1};
	    } elsif ( $opt->{single} ) {
		$tokens[0] = join ' ', $command_equivalent{$1},
		    $tokens[0];
	    } else {
		unshift @tokens, $command_equivalent{$1};
	    }
	}

	# With the {single} and {noredirect} options both asserted,
	# there is only one token, so we return it directly.

	($opt->{single} && $opt->{noredirect}) and return $tokens[0];

	# With the {noredirect} option asserted, we just return a
	# reference to the tokens found.

	$opt->{noredirect} and return \@tokens;

	# Otherwise we return a list, with a reference to the token list
	# as the first element, and a reference to the redirect hash as
	# the second element.

	return (\@tokens, \%redir);
    }

    # Retrieve the value of a variable.
    sub _tokenize_var {
	my ($self, $name, $args, $relquote, $indirect) = @_;

	defined $name and $name ne ''
	    or return $indirect ? '' : undef;

	$special{$name} and do {
	    my $val = $special{$name}->($args, $relquote);
	    return ($indirect && ref $val) ? '' : $val;
	};

	$name !~ m/ \D /smx
	    and return $args->[$name - 1];

	exists $accessor{$name}
	    and return $self->get($name);

	exists $self->{exported}{$name}
	    and return $self->{exported}{$name};

	return $ENV{$name};
    }
}

#	$self->_wail(...)
#
#	Either die or croak with the arguments, depending on the value
#	of the 'warning' attribute. If we die, a trailing period and
#	newline are provided if necessary. If we croak, any trailing
#	punctuation and newline are stripped.

sub _wail {
    my ($self, @args) = @_;
    $self->{_warner}->wail( @args );
    return;	# We can't hit this, but Perl::Critic does not know that.
}

#	$self->_whinge(...)
#
#	Either warn or carp with the arguments, depending on the value
#	of the 'warn' attribute. If we warn, a trailing period and
#	newline are provided if necessary. If we carp, any trailing
#	punctuation and newline are stripped.

sub _whinge {
    my ($self, @args) = @_;
    $self->{_warner}->whinge( @args );
    return;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2 - Forecast satellite visibility.

=head1 SYNOPSIS

 use Astro::App::Satpass2;
 # Instantiate and set our location
 my $satpass2 = Astro::App::Satpass2->new(
     location => '1600 Pennsylvania Ave, Washington DC',
     latitude => 38.898748,    # degrees
     longitude => -77.037684,  # degrees
     height => 16.68,          # meters
 );
 # Acquire ISS data from NASA
 $satpass2->tell( qw{ spacetrack spaceflight -all } );
 # Display our location
 $satpass2->location();
 # Display visible ISS passes over our location
 $satpass2->pass();

Or equivalently, from the F<satpass2> script which is installed with
this package,

 $ satpass2
          ... front matter displayed here ...
 satpass2> # set our location
 satpass2> set location '1600 Pennsylvania Ave, Washington DC'
 satpass2> set latitude 38.898748 longitude -77.037684
 satpass2> set height 16.68
 satpass2> # Acquire ISS data from NASA
 satpass2> tell spacetrack spaceflight -all
 satpass2> # Display our location
 satpass2> location
 satpass2> # Display visible ISS passes over our location
 satpass2> pass
 satpass2> # Guess what
 satpass2> exit

The script is implemented in terms of the L<run()|/run> method. Blank
lines and comments are ignored. The first token in the line is the
method name, and subsequent tokens are arguments to that method. See
L<run()|/run> for the details of that method, and L</TOKENIZING> for
details of the tokenizer. Finally, see L<initfile()|/initfile> for where
to put your initialization file, which is just a script that gets
executed every time you invoke the L<run()|/run> method.

If you want to be interactive, simply

 use Astro::App::Satpass2;
 Astro::App::Satpass2->run(@ARGV);

which is essentially the content of the F<satpass2> script.  In this
last case, the user will be prompted for commands once the commands in
@ARGV are used up, unless those commands include 'exit'.

=head1 NOTICE

This is alpha code. It has been tested on my box, but has limited
exposure to the wild. Also, the public interface may not be completely
stable, though I will try to call attention to any incompatible changes.

The eventual plan is to retire the F<satpass> script in favor of this
package, and to rename the satpass-less F<Astro-satpass> distribution to
F<Astro-Coord-ECI>.

=head1 OVERVIEW

This class implements an application to predict satellite visibility and
related phenomena. It is a mostly-compatible rewrite and eventual
replacement of the F<satpass> script in distribution C<Astro-satpass>,
aimed at making it easier to test, and removing some of the odder cruft
that has accumulated in the F<satpass> script.

The easiest way to make use of this class is via the bundled F<satpass2>
script, which simply calls the L<run()|/run> method.
L<Astro::App::Satpass2::TUTORIAL|Astro::App::Satpass2::TUTORIAL> covers
getting started with this script. If you do nothing else, see the
tutorial on setting up an initialization file, since the L<satpass2>
script will be much more easy to use if you configure some things up
front.

You can also instantiate an C<Astro::App::Satpass2> object yourself and
access all its functionality programmatically. If you are doing this you
may still want to consult the
L<TUTORIAL|Astro::App::Satpass2::TUTORIAL>, because the F<satpass2>
commands correspond directly to C<Astro::App::Satpass2> methods.

=head1 Optional Modules

An attempt has been made to keep the requirements of this module
reasonably modest. But there are a number of optional modules which, if
installed, give you increased functionality. If you do not install these
initially and find you want the added functionality, you can always
install them later. The optional modules are:

=over

=item L<Astro::SIMBAD::Client|Astro::SIMBAD::Client>

This module looks up the positions of astronomical bodies in the SIMBAD
database at L<http://simbad.u-strasbg.fr/>. This is only used by the
C<lookup> subcommand of the L<sky()|/sky> method.

=item L<Astro::SpaceTrack|Astro::SpaceTrack>

This module retrieves satellite orbital elements from various sources.
Since you have to have these to predict satellite positions, this is the
least optional of the optional modules. Without it, you would have to
download orbital elements some other way and then use the
L<load()|/load> method to import them into C<Astro::App::Satpass2>.

=item L<Date::Manip|Date::Manip>

This module is a very flexible (and very large) time parser. If it is
installed, C<Astro::App::Satpass2> will use it to parse times. If it is
not available a home-grown ISO-8601-ish parser will be used. There are
really three options here:

* If you have Perl 5.10 or above, you can install the latest version of
L<Date::Manip|Date::Manip>.

* If you a Perl before 5.10, the latest version of
L<Date::Manip|Date::Manip> will not work, and you will have to install
version 5.56. This version of C<Date::Manip> is known not to support
summer time (or daylight saving time, if you will), and may have other
deficiencies versus the current release.

* The home-grown parser is
L<Astro::App::Satpass2::ParseTime::ISO86O1|Astro::App::Satpass2::ParseTime::ISO8601>.
This does not support summer time, nor time zones other than the user's
default time and GMT. Dates and times must be specified as numeric
year-month-day hour:minute:second, though there is some flexibility on
punctuation, and as a convenience you can use C<yesterday>, C<today>, or
C<tomorrow> in lieu of the C<year-month-day>.

=item L<DateTime|DateTime> and L<DateTime::TimeZone|DateTime::TimeZone>

If both of these are available, C<Astro::App::Satpass2> will use them to
format dates. If they are not, it will use C<POSIX::strftime>. If you
are using C<POSIX::strftime>, time zones other than the default time
zone and GMT are not supported, though if you set the L<tz|/tz>
attribute C<Astro::App::Satpass2> will place its value in C<$ENV{TZ}>
before calling C<strftime()> in case the underlying code pays attention
to this.

If you have L<DateTime|DateTime> and
L<DateTime::TimeZone|DateTime::TimeZone> installed,
C<Astro::App::Satpass2> will let you use C<Cldr> time formats if you
like, instead of C<strftime> formats.

=item L<Geo::WebService::Elevation::USGS|Geo::WebService::Elevation::USGS>

This module is only used by the L<height()|/height> method, or
indirectly by the L<geocode()|/geocode> method. If you are not
interested in these you do not need this module.

=item L<SOAP::Lite|SOAP::Lite>

This module is used by the L<geocode()|/geocode> and L<height()|/height>
methods. If you are not interested in these you do not need this module.

=item L<Time::HiRes|Time::HiRes>

This module is only used by the L<time()|/time> method. If you are not
interested in finding out how long things take to run, you do not need
this module.

=item L<Time::y2038|Time::y2038>

This module is only needed if you are interested in times outside the
range of times representable in your Perl. This was typically 1970
through 2038 in 32-bit Perls before Perl 5.12. In Perl 5.12 the Y2038
bug was fixed, and a much wider range of times is available. You may
also find that a wider range of times is available in 64-bit Perls.

At least some versions of L<Time::y2038|Time::y2038> have had trouble on
Windows-derived systems, including Cygwin. I<Caveat user.>

=back

=head1 METHODS

Most methods simply correspond to commands in the C<satpass2> script,
and the arguments correspond to arguments in the script. Such methods
will be identified in the following as 'interactive methods.'

A few methods are used for manipulating the C<Astro::App::Satpass2> object
itself, or for doing things not available to the C<satpass2> script.
These are identified as 'non-interactive methods.'

When the documentation specifies that a method takes options, they may
be specified either as command-style options or as a hash.

If options are specified command-style, the option name must be preceded
by a dash, and may be abbreviated. Option arguments are either specified
as a separate argument or appended to the option name.

If options are specified in a hash, a reference to the hash must be the
first argument to the method. The hash keys are the option names (in
full, but without leading dashes), and the hash values are the values of
the options.

For example, hypothetical method C<foo()> may be called with boolean
option C<bar> and string option C<baz> in any of the following ways:

 $satpass2->foo( '-bar', -baz => 'burfle' );
 $satpass2->foo( '-bar', '-baz=burfle' );
 $satpass2->foo( { bar => 1, baz => 'burfle' } );

When the documentation says 'nothing is returned', this means the
subroutine returns with a C<return> statement without an argument, which
returns C<undef> in scalar context, and an empty list in list context.

=head2 new

 $satpass2 = Astro::Satpass2->new();

This non-interactive method instantiates a new Astro::Satpass2 object.
Any arguments are passed to the L<set()|/set> method.

=head2 alias

 $output = $satpass2->alias();
 satpass2> alias

This interactive method just wraps the
L<Astro::Coord::ECI::TLE alias()|Astro::Coord::ECI::TLE/alias> method,
which returns the known class name aliases. The output is zero or more
lines of text, each line giving an alias and its equivalent class.

If arguments are given, they should be pairs of aliases and class names,
and will add to or replace the currently-known aliases. If the class
name is false in the Perl sense (i.e. '', 0, or undef) the alias, if it
exists, is deleted.

=head2 almanac

 $output = $satpass2->almanac(...);
 satpass2> almanac

This interactive method returns almanac data for the current location.
This consists of all data returned by the C<almanac()> method for all
objects in the sky which support this method.

It takes up to two arguments, which represent start time and end time.
The default start time is midnight of the current day in the local time
zone, or in GMT if the L</gmt> attribute is true. The default end time
is a day after the current start time. See L</SPECIFYING TIMES> for how
to specify times.

The following options are recognized:

 -choose chooses objects to report;
 -dump produces debugging output;
 -horizon produces rise/set times;
 -quarter produces quarter events;
 -rise is a synonym for -horizon;
 -set is a synonym for -horizon;
 -transit reports transit across zenith or (sometimes) nadir;
 -twilight reports begin/end of twilight.

Option C<-dump> is unsupported in the sense that the author makes no
commitments as to what it does, nor does he commit not to change or
remove it without notice.

Option C<-choose> chooses which objects to report. It takes as an
argument the names of one or more bodies (case-insensitive), separated
by commas, and it can be specified multiple times. If C<-choose> is not
specified, all objects in the sky are reported.

The other options specify what output to produce. If none are specified,
all are turned on by default. If only negated options are specified
(e.g. -noquarter), unspecified options are asserted by default.
Otherwise unspecified options are considered to be negated.

B<Note well> that unlike the F<satpass> script, the output from this
method does not normally include location. The location is included only
if the command is issued from a F<satpass> initialization file (as
opposed to an C<Astro::App::Satpass2> initialization file), or from a macro
defined in a F<satpass> initialization file. This functionality will be
revoked when support for the F<satpass> script is dropped.

=head2 begin

 $satpass2->begin();
 satpass2> begin

This interactive method begins a localization block, which extends to
the corresponding L<end()|/end> or to the end of the source file or
macro. Nothing is returned.

=head2 cd

 $satpass2->cd();
 satpass2> cd

This interactive method changes to the users' home directory, or to the
given directory if one is specified as an argument. Tilde expansion is
done on the argument if appropriate. Nothing is returned.

=head2 choose

 $satpass2->choose( 25544, 'hst' )
 satpass2> choose 25544 hst

This interactive method drops from the observing list any objects that
do not meet the given selection criteria. Numbers greater than 999 are
taken to represent OID numbers, and compared to each object's 'id'
attribute.  Anything else is made into a regular expression and matched
to the object's 'name' attribute.

The following options may be specified:

 -epoch to select the best item for the given epoch.

Nothing is returned.

=head2 clear

 $satpass2->clear();
 satpass2> clear

This interactive method clears the observing list. It takes no
arguments. Nothing is returned.

=head2 dispatch

 $output = $satpass2->dispatch( 'flare', 'today 12:00:00', '+1' );

This non-interactive method takes as its arguments the name of an
interactive method and its arguments, calls the method, and returns
whatever the method calls.

Any method executed via this method is considered to have been executed
interactively.

=head2 drop

 $satpass2->drop( 25544, 'hst' );
 satpass2> drop 25544 hst

This interactive method inverts the sense of L<choose()|/choose>,
removing from the observing list all bodies that match the selection
criteria. Nothing is returned.

=head2 dump

 $output = $satpass2->dump();
 satpass2> dump

This interactive method is unsupported, and is used for debugging
purposes. It may disappear, or its functionality change, without notice.

Currently it loads a dumper class (either some C<YAML> module or
C<Data::Dumper>) and returns a dump of the C<Astro::App::Satpass2> object.

=head2 echo

 $output = $satpass2->echo( 'Hello, sailor!' );
 satpass2> echo 'Hello, sailor!'

This interactive method joins its arguments with spaces, appends a
newline, and returns the result. It is so named because it is
anticipated that the caller will print the result.

The following option may be specified:

 -n to suppress the newline at the end of the echoed text.

=head2 end

 $satpass2->end();
 satpass2> end

This interactive method ends a localization block. Nothing is returned.
It is an error to have an end without a corresponding L<begin()|/begin>.

=head2 execute

 $output = $satpass2->execute( <<'EOD' );
 st set direct 1
 st celestrak stations
 choose iss
 pass 'today 12:00:00' +7
 EOD

This non-interactive method takes as its arguments lines of text. The
arguments are split on C<\n>. Each line is tokenized (see L</TOKENIZING>
for the details), output redirection is performed, and the tokens are
passed to L<dispatch()|/dispatch> for execution.  Exceptions raised by
L<dispatch()|/dispatch> or the methods it calls will not be trapped.

The output of L<dispatch()|/dispatch> is sent to whatever output is
selected. If no output at all is selected (that is, if the C<stdout>
attribute is C<undef> and no output redirection was specified) the
output will be returned.  Otherwise undef will be returned.

Blank lines, and lines beginning with '#' (comments) are ignored.

=head2 exit

 $satpass2->exit();
 satpass2> exit

This interactive method is used to unwind the context stack and
terminate execution. If executed in a block labeled SATPASS2_EXECUTE
(as in the L</run> method for example), it does a 'last' on that block.
Otherwise it displays a warning to STDERR and exits Perl. Nothing is
returned.

=head2 export

 $satpass2->export( $name [, $value] );
 satpass2> export name [ value ]

This interactive method exports the value of the named attribute to an
environment variable having the same name. If the optional value
argument is passed, the value of the attribute is set.

If the named attribute does not exist, an environment variable of the
given name is created, and assigned the given value, which in this case
is not optional.

Either way, nothing is returned.

Once an attribute has been exported, the environment variable tracks
changes in the value of the attribute. This includes not only explicit
changes, but those made as a result of leaving a localization block.

=head2 flare

 $output = $satpass2->flare( 'today 18:00', '+1' );
 satpass2> flare 'today 18:00' +1

This interactive method predicts flares from any bodies in the observing
list capable of flaring. The optional arguments are the start time of
the prediction (defaulting to the current day at noon) and the end time
of the prediction (defaulting to C<'+7'>). See L</SPECIFYING TIMES> for
how to specify times.

The following options are available:

C<-am> displays morning flares -- that is, those after midnight but
before morning twilight. This can be negated by specifying C<-noam>.

C<-choose> chooses bodies from the observing list. It works the same way
as the choose method, but does not alter the observing list. You can
specify multiple bodies by specifying -choose multiple times, or by
separating your choices with commas. If -choose is not specified, the
whole observing list is used.

C<-day> displays daytime flares -- that is, those between morning
twilight and evening twilight. This can be negated by specifying
C<-noday>.

C<-pm> displays evening flares -- that is, those between evening twilight
and midnight. This can be negated by specifying C<-nopm>.

C<-questionable> requests that satellites whose status is questionable
(i.e. 'S') be included. Typically these are spares, or moving between
planes. You may use C<-spare> as a synonym for this.

C<-quiet> suppresses any errors generated by running the orbital model.
These are typically from obsolete data, and/or decayed satellites.
Bodies that produce errors will not be included in the output.

B<Note well> that the sense of the C<-am>, C<-day>, and C<-pm> options
is opposite to that in the F<satpass> script. However, if they are used
in a F<satpass> initialization script, or in a macro defined in a
F<satpass> initialization script, the F<satpass> sense of these options
will be used, and they will be inverted internally to the
C<Astro::App::Satpass2> sense. This F<satpass> compatibility will be retracted
when the F<satpass> script is retired.

Once the C<-am>, C<-day>, and C<-pm> options have their C<Astro::App::Satpass2>
sense, unspecified options are defaulted to false if any of these
options is asserted, or true otherwise. For example, specifying C<-noam>
has the same effect as specifying C<-day -pm>, and specifying none of
the three options is the same as specifying C<-am -day -pm>.

=head2 geocode

 $output = $satpass2->geocode('1600 Pennsylvania Ave, Washington DC');
 satpass2> geocode '1600 Pennsylvania Ave, Washington DC'

This interactive method looks up its argument at L<http://geocoder.us/>.
If exactly one match is found, the location, latitude, and longitude
attributes are set accordingly. If exactly one match is found and the
L</autoheight> attribute is true, the L<height()|/height> method will be
called on the resultant position.

The argument can be defaulted, in which case the current location
attribute is looked up.

This method will fail if the L<SOAP::Lite|SOAP::Lite> module can not be
loaded.

The results of the lookup are returned.

=head2 geodetic

 $satpass2->geodetic( $name, $latitude, $longitude, $elevation );
 satpass2> geodetic name latitude longitude elevation

This interactive method adds a geodetic position to the observing list.
The arguments are the name of the object, the latitude and longitude of
the object (in degrees by default, see L</SPECIFYING ANGLES> for
details), and the height of the object (in kilometers by default, see
L</SPECIFYING DISTANCES> for details) above the current ellipsoid (WGS84
by default). Nothing is returned.

The motivation was to try to judge the observability of those Wallops
Island cloud studies. The L</pass> method will not report on these, but
the L</position> method will.

=head2 get

 $value = $satpass2->get( $name );

This non-interactive method returns the value of the given attribute.
See L<show()|/show> for the corresponding interactive method.

=head2 height

 $output = $satpass2->height( $latitude, $longitude );
 satpass2> height latitude longitude

This interactive method queries the USGS online database for the height
of the ground above sea level at the given latitude and longitude. If
these were not specified, they default to the current settings of the
L</latitude> and L</longitude> attributes.

If the query succeeds, this method returns the 'set' command necessary
to set the height to the retrieved value.

This method will fail if the
L<Geo::WebService::Elevation::USGS|Geo::WebService::Elevation::USGS>
module can not be loaded.

=head2 help

 $output =  $satpass2->help(...)
 satpass2> help

This interactive method can be used to get usage help. Without
arguments, it displays the documentation for this class (hint: you are
reading this now). You can get documentation for related Perl modules by
specifying the appropriate arguments, as follows:

 eci ------ Astro::Coord::ECI
 iridium -- Astro::Coord::ECI::TLE::Iridium
 moon ----- Astro::Coord::ECI::Moon
 sun ------ Astro::Coord::ECI::Sun
 st ------- Astro::SpaceTrack
 star ----- Astro::Coord::ECI::Star
 tle ------ Astro::Coord::ECI::TLE
 utils ---- Astro::Coord::ECI::Utils

The viewer is whatever is the default for your system.

Under Mac OS 9 or below, this method simply returns an apology, since
L<Pod::Usage|Pod::Usage> appears not to work there.

If you set the L<webcmd|/webcmd> attribute properly, this method will
launch the L<http://search.cpan.org/> page for this package, and
arguments will be ignored.

In any case, nothing is returned.

=head2 init

 $output = $satpass2->init();

This non-interactive method computes the name of the initialization
file, and executes it if it is present. The output (if any) is the
output of the individual commands executed by the initialization file.

If you pass a defined value as an argument, that value will be taken as
a file name, and that file will be executed if possible.  That is, this
method's functionality becomes the same as source(), but without the
possibility of passing the '-optional' option.

If you do not pass a defined value as an argument, the following files
are checked for, and the first one found is executed:

 - The file specified by the SATPASS2INI environment variable;
 - The file returned by the initfile interactive method;
 - The file specified by the SATPASSINI environment variable;
 - The file used by the satpass script.

If none of these is found, this method returns nothing.

If the initialization file is for F<satpass> rather than
C<Astro::App::Satpass2>, any commands issued in it will be interpreted
in their F<satpass> meaning, to the extent possible. Also, an attempt
will be made to rewrite the commands in any macros defined into their
C<Astro::App::Satpass2> equivalents. This rewriting is a purely textual
operation, and you may want to verify your macro definitions.

As a side effect, the name of the file actually used is stored in the
L</initfile attribute>. This is cleared if the initialization file was
not found.

=head2 initfile

 $output = $satpass2->initfile();
 satpass2> initfile

This interactive method simply returns the name of the default
initialization file, which is heavily OS-specific. This method is
actually used to find the default initialization file, but it is exposed
to give an easy way for the user to figure out where this code expects
to find the initialization file. See also the L<init() method|/init> for
other places initialization files may be found, and the
L<initfile attribute>,
which records the name of the actual file loaded by the last call to
L<init()|/init>,

The initialization file is always named F<satpass2rc>. It is located in
the directory specified by

 File::HomeDir->my_dist_config( 'Astro-App-Satpass2' )

Unfortunately, this method returns C<undef> unless the directory
actually exists, and is sketchily documented. As of this writing, though
(February 2011), the F<Astro-App-Satpass2/> directory will be found in
directory F<Perl/> in your documents directory, or in directory
C<.perl/> if L<File::HomeDir|File::HomeDir> thinks your documents
directory is your home directory. The exception is on FreeDesktop.org
systems (e.g. Linux), where the F<Perl/> directory is found by default
in C<.config/> under your home directory.

There are two options to this method:

* C<-create-directory> causes the directory for the initialization file
to be created;

* C<-quiet> suppresses the exception which is normally thrown if the
directory for the initialization file is not found, and
C<-create-directory> was not asserted, and instead causes the method to
simply return.

=head2 list

 $output = $satpass2->list(...);
 satpass2> list

This interactive method returns a listing of all bodies in the observing
list. If the observing list is empty and the L</warn_on_empty> attribute
is true, a warning is issued.

The C<-choose> option may be used to select which bodies are listed.
This selects bodies to list just like the L<choose()|/choose> method,
but the observing list is unaffected. To choose multiple bodies, either
specify the option multiple times, separate the choices with commas, or
both.

=head2 load

 $satpass2->load( $filename, ... );
 satpass2> load filename

This interactive method does glob and bracket expansion on its arguments
(which have already been tilde-expanded by the tokenizer) by running
them through L<File::Glob::bsd_glob()|File::Glob/bsd_glob>. The
resultant files are assumed to contain orbital elements which are loaded
into the observing list. An exception is thrown if no files remain after
the glob operation, or if any file can not be opened.

The C<-verbose> option causes each file name to be listed to C<STDERR>
before the file is processed.

Nothing is returned.

=head2 localize

 $satpass2->localize( qw{ formatter horizon } );
 satpass2> localize formatter horizon
 $satpass2->localize( { all => 1 } );
 satpass2> localize -all
 $satpass2->localize( { except => 1 }, qw{ formatter horizon } );
 satpass2> localize -except formatter horizon

This interactive method localizes the values of the attributes given in
the argument list to the current macro, source file, or begin block.
Nested macros or source files will see the changes, but commands outside
the scope of the localization will not. The arguments must be the names
of valid attributes. Attempts to localize a value more than once in the
same scope will be ignored. Nothing is returned.

The C<-except> option causes the argument list to be used as an
exception list, and all attributes except those in the argument list are
localized. You can use C<-all> as a synonym for C<-except>; it may look
more natural when there are no arguments.

=head2 location

 $output = $satpass2->location();
 satpass2> location

This interactive method returns the current location.

=head2 macro

 $output = $satpass2->macro( $subcommand, $arg ...);
 satpass2> macro subcommand arg ...

This interactive method manipulates macros. The following subcommands
are available:

 'brief' lists the names of defined macros;
 'list' lists the definitions of macros;
 'delete' deletes macros;
 'define' defines a macro.

For semi-compatibility backward, each of these can be specified with a
leading dash (e.g. '-delete'). With the leading dash specified,
subcommands can be abbreviated as long as the abbreviation is unique.
For example, '-del' is equivalent to 'delete', but 'del' is not.

If no arguments at all are provided to C<macro()>, 'brief' is assumed.

If a single argument is provided that does not match a subcommand name,
'list' is assumed.

If more than one argument is provided, and the first does not match a
subcommand name, 'define' is assumed.

The first argument of the 'define' subcommand is the macro name, and
subsequent arguments are the commands that make up that macro. For
example, 'say' can be defined in terms of 'echo' by

 $satpass2->macro( define => say => 'echo $@' );

For subcommands other than 'define', the arguments are macro names.

The C<brief> and C<list> subcommands return their documented output. The
C<delete> and C<define> subcommands return nothing.

Macros can be called programmatically via the L<dispatch()|/dispatch>
method.

=head2 pass

 $output = $satpass2->pass( 'today 12:00:00', '+7' );
 satpass2> pass 'today 12:00:00' +7

This interactive method computes and returns the visible passes of any
bodies in the observing list. The optional arguments are the start time of
the prediction (defaulting to the current day at noon) and the end time
of the prediction (defaulting to C<'+7'>). See L</SPECIFYING TIMES> for
how to specify times.

The following options are available:

C<-appulse> selects appulses for display. It can be negated by
specifying C<-noappulse>, though a more efficient way to not get
appulses is to clear the sky.

C<-choose> chooses bodies from the observing list to report on. Multiple
bodies can be chosen either by providing a comma-delimited list as an
argument, specifying C<-choose> multiple times, or both. The choice is
made in the same way as by the L<choose()|/choose> method, but the
observing list is not affected.

C<-chronological> causes the output to be in chronological order by
pass. If this option is not asserted (or is explicitly negated using
C<-nochronological>) the order is by satellite, though it remains
chronological for a particular satellite.

C<-dump> is a debugging tool. It is unsupported in the sense that the
author reserves the right to change or revoke its functionality without
notice.

C<-horizon> selects the satellite rise and set for display. Synonyms are
C<-rise> and C<-set> -- that is C<-rise> selects both rise and set, as
does C<-set>. This can be negated by specifying C<-nohorizon>,
C<-norise>, or C<-noset>.

C<-illumination> selects passage of the satellite into or out of the
Earth's shadow for display. This can be negated by specifying
C<-noillumination>.

C<-quiet> suppresses any errors generated by running the orbital model.
These are typically from obsolete data, and/or decayed satellites.
Bodies that produce errors will not be included in the output.

C<-transit> selects the satellite transit across the meridian for
display. Synonyms are C<-maximum> and C<-culmination>. These can be
negated by specifying C<-notransit>, C<-nomaximum>, or
C<-noculmination>.

The C<-appulse>, C<-horizon>, C<-illumination> and C<-transit> options
(and their synonyms) specify what output to produce. If none are
specified, all are turned on by default. If only negated options are
specified (e.g. -noappulse), unspecified options are asserted by
default. Otherwise, unspecified options are considered to be negated.

B<Note well> that unlike the F<satpass> script, the output from this
method does not normally include location. The location is included only
if the command is issued from a F<satpass> initialization file (as
opposed to an C<Astro::App::Satpass2> initialization file, or from a macro
defined in a F<satpass> initialization file. This functionality will be
revoked when support for the F<satpass> script is dropped.

=head2 phase

 $output = $satpass2->phase();
 satpass2> phase

This interactive method computes and returns the phase of any bodies in
the sky which support this. The optional argument is the time of the
prediction (defaulting to the current time). See L</SPECIFYING TIMES>
for how to specify times.

=head2 position

 $output = $satpass2->position(...);
 satpass2> position ...

This interactive method computes and returns the positions of all bodies
in the observing list and in the sky. For bodies on the observing list
that can flare, flare status is displayed for all sources of flares on
the body.

There is one argument, which is the time for the computation, which
defaults to the current time.

The following options may be specified:

C<-choose=choice> selects bodies to display. This can be specified
multiple times to select multiple bodies, or the C<choice> argument can
be a comma-separated list of things to choose, or both. The choices are
implemented in exactly the same way as for the L<choose()|/choose>
method, but the observing list is not affected, and the choice is
applied to objects in the sky as well.

C<-questionable> causes flare data to be provided on bodies whose
ability to produce predictable flares is questionable.

C<-quiet> suppresses any errors generated by running the orbital model.
These are typically from obsolete data, and/or decayed satellites.
Bodies that produce errors will not be included in the output.

C<-spare> is a synonym for C<-questionable>.

The C<endtime> and C<interval> arguments and the C<-realtime> option,
which were present in the original F<satpass> script, have been
retracted. If you need any of these, please contact the author.

=head2 quarters

 $output = $satpass2->quarters($start_time, $end_time, ...);
 satpass2> quarters start_time end_time ...

This interactive method computes and returns the quarters for any
objects in the sky that have this functionality.

It takes up to two arguments, which are the start and end time covered.
The start time defaults to midnight of the current day in the local time
zone, or GMT if the L</gmt> attribute is true. The end time defaults to
30 days after the start time. See L</SPECIFYING TIMES> for how to
specify times.

The following option is available:

 -dump produces debugging output.

The -dump option should be considered a troubleshooting tool, which may
change or disappear without notice.

=head2 run

 Astro::App::Satpass2->run(...);

This non-interactive method runs the application. The arguments are the
options and commands to be passed to the application.

The valid options are:

 -filter to suppress banner text;
 -gmt to output time in GMT;
 -initfile name of the initialization file to use;
 -version to display the output of version() and return.

The -filter option defaults to true if STDIN is not a terminal.

The steps in running the application are:

1) If the first argument is a code reference, it is pulled off the
argument list and used for input. Otherwise default input code is
generated as described later.

2) The arguments are parsed as though they are a command line.

3) If the input is from a terminal and the -filter option was not
specified, a banner is printed.

4) The initialization file is located and run. If you specified an
initialization file via the C<-initfile> option, you will be warned if
it was not found. If the initialization file contains the C<exit>
command, it will be executed, and the run will end at this step.

5) Any remaining options corresponding to attribute values (currently
only C<-gmt>) are applied.

6) Any remaining arguments after removing all options are assumed to be
commands, and passed to the L<execute()|/execute> method. If one of
these is the C<exit> command, the run will end at this step.

7) Further commands are read as described below.

By default, commands come from C<STDIN>, but any commands passed as
arguments are executed first. How commands are read from C<STDIN>
depends on a number of factors. If C<STDIN> is a terminal and
Term::ReadLine can be loaded, a Term::ReadLine object is instantiated
and used to read input.  If C<STDIN> is a terminal and Term::ReadLine
can not be loaded, the prompt is printed to STDERR and C<STDIN> is read.
If C<STDIN> is not a terminal, it is read.

The default command acquisition behavior can be changed by passing, as
the first argument, a code reference. This should refer to a subroutine
that expects the prompt as its only argument, and returns the next
input. This code should return C<undef> to indicate a logical
end-of-file.

The exit command causes the method to return.

This method can also be called on an Astro::App::Satpass2 object. For example:

 use Astro::App::Satpass2;
 my $app = Astro::App::Satpass2->new(
     prompt => 'Your wish is my command: '
 );
 $app->run();

=head2 save

 $satpass2->save( $file_name );
 satpass2> save file_name

This interactive method saves your current settings to the named file.
If no file is named, they are saved to the default configuration file.
If the file already exists, you will be prompted unless you specified
the C<-overwrite> option. Nothing is returned.

File name F<-> is special, and causes output to go wherever standard
output is being sent.

This method saves all attribute values of the C<Astro::App::Satpass2> object,
all attributes of the L<Astro::SpaceTrack|Astro::SpaceTrack> object
being used to retrieve TLE data, and all defined macros. If you
overwrite a configuration file, any other contents of the file will be
lost.

The following options are allowed:

C<-changes> causes only changes from the default attributes to be
written to the output file.

C<-overwrite> causes the output file to overwrite an existing file of
the same name (if any) without getting confirmation from the user.

=head2 set

 $satpass2->set($name => $value ...);
 satpass2> set name value ...

This interactive method sets the values of the given
L<attributes|/ATTRIBUTES>. More than one attribute can be set at a time.
Nothing is returned.

When this method is being executed interactively (i.e. via the
L</dispatch> method, as opposed to being called directly as a method),
certain attributes may not be set. Also, the literal C<'undef'> is taken
to represent the undefined value.

=head2 show

 $output = $satpass2->show( $name, ... );
 satpass2> show name ...

This interactive method returns the values of the given attributes,
formatted as 'set' commands. If no arguments are given, the values of
all non-deprecated attributes that may be set interactively are
returned.

If you specify the C<-changes> option, only those values that have been
changed from the default are returned.

=head2 sky

 $output = $satpass2->sky( $subcommand ...);
 satpass2> sky subcommand ...

This interactive method manipulates the background objects. The
$subcommand argument determines what manipulation is done, and the
interpretation of subsequent arguments depends on this. The
interpretation of the subcommand names is not case-sensitive. If no
subcommand is given, 'list' is assumed.

The possible subcommands are:

'Add' adds an object to the background. The first argument is the name
of the object. 'Sun' and 'Moon' (not case-sensitive) are special cases,
and cause the Sun or Moon to be added. Anything else is assumed to be
the name of a star, and its coordinates must be given, in the following
order: right ascension (in either degrees or hours, minutes, or
seconds), declination (in degrees), range (optionally with units of
meters ('m'), kilometers ('km'), astronomical units ('au'), light years
('ly'), or parsecs ('pc', the default) appended), proper motion in right
ascension and declination (in degrees per year) and in recession (in
kilometers per second). All but right ascension and declination may be
omitted. It is an error to attempt to add an object which is already
listed among the background objects. Nothing is returned.

'Clear' clears all background objects. It takes no arguments. Nothing is
returned.

'Drop' removes background objects. The arguments are the names of the
background objects to be removed, or portions thereof. They are made
into a case-insensitive regular expression to perform the removal.
Nothing is returned.

'List' returns a string containing a list of the background objects, in
the format of the 'sky add' commands needed to re-create them. If no
subcommand at all is given, 'list' is assumed.

'Lookup' takes as its argument a name, looks that name up in the
University of Strasbourg's SIMBAD database, and adds the object to the
background. An error occurs if the object can not be found. This
subcommand will fail if the
L<Astro::SIMBAD::Client|Astro::SIMBAD::Client> module can not be loaded.
Nothing is returned.

=head2 source

 $output = $satpass2->source( $file_name );
 satpass2> source file_name

This interactive method takes commands from the given file and runs
them. The concatenated output is returned.

Normally an exception is thrown if the file can not be opened. If the
C<-optional> option is specified, open failures cause the method to
return C<undef>.

=head2 st

 $output = $satpass2->st( $method ...);
 satpass2> st method ...

This interactive method is deprecated in favor of the
L<tell( 'spacetrack' )|/tell> method. If you don't like all the
typing that implies in interactive mode, you can define 'st' as a
macro:

 satpass2> macro define st 'tell spacetrack $@'

This interactive method calls L<Astro::SpaceTrack|Astro::SpaceTrack>
(which must be installed) to load satellite data. The arguments are the
L<Astro::SpaceTrack|Astro::SpaceTrack> method name and any arguments to
that method. As special cases, 'show' is made equivalent to 'get', 'get'
will display all attribute values if called without a value, and
'localize' will localize attribute values to a block. The return is
whatever the method returns.

The following options are allowed on any retrieval:

 -all specifies the retrieval of all manned spaceflight elements;
 -descending specifies the return of data in descending order;
 -last5 specifies the return of the last 5 elements;
 -end specifies the end time for the data to be fetched;
 -start specifies the start time for the data to be fetched;
 -sort specifies the type of sort to do on the data;
 -verbose gets output for normally-silent functions.

All options except for -verbose are specific to
L<Astro::SpaceTrack|Astro::SpaceTrack>, and are silently ignored unless
relevant to the method being called.

The following options are allowed on the 'get' or 'show' commands:

 -changes reports only changes from the defaults used by Astro::App::Satpass2.

This method will fail if the L<Astro::SpaceTrack|Astro::SpaceTrack>
module can not be loaded.

=head2 status

 $output = $satpass2->status( $subcommand, ... );
 satpass2> status subcommand ...

This interactive method manipulates the satellite status cache. This
currently only covers Iridium satellites. The arguments are a subcommand
(defaulting to 'show'), and possibly further arguments that depend on
that subcommand.  Briefly, the valid subcommands are:

add - adds a body to the status table, possibly replacing an existing
entry. The arguments are OID, type, status, name, and comment. The type
would typically be 'iridium', and status typically '+' (operational),
'S' (spare), or '-' (failed). Name and comment default to empty.

clear - clears the status table. You can specify a type, and only that
type would be cleared, but currently there is only one type.

drop - drops an entry from the status table. The argument is the OID.

show - displays the status table, formatted as a series of 'status add'
commands.

There are two options:

-name specifies that the data for the C<show> subcommand be displayed in
order by name. It is allowed but ignored on any other subcommand.

This method is really just a front-end for the
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE>
L<status()|Astro::Coord::ECI::TLE/status> method. See the documentation
for that for more details.

=head2 system

 $output = $satpass2->system(...);
 satpass2> system ...
 satpass2> !...

This interactive method does glob and bracket expansion on its arguments
(which have already been tilde-expanded by the tokenizer) by running
them through L<File::Glob::bsd_glob()|File::Glob/bsd_glob>, and executes
them as a command on the system. Since tokenizing is done by
Astro::App::Satpass2, there is no shell processing, and the quoting rules are
those of Astro::App::Satpass2, not those of the underlying operating system.

If the L</stdout> attribute is a terminal, output goes directly to the
terminal, thus making things like 'less' possible. Otherwise output is
captured and returned.

=head2 tell

 $satpass2->tell( formatter => template =>
     local_coord => 'azel' );
 satpass2> tell formatter template local_coord azel

This interactive method modifies one of the objects to which
functionality has been delegated, I<in situ.> The arguments are the
attribute name of the object to be modified, the method to call on that
object, and any arguments to that method. The results of the method call
are returned.

The only supported attributes are L<formatter|/formatter>,
L<satpass|/satpass>, and L<time_parser|/time_parser>.

If this method is called interactively (i.e. as a result of calling
L<dispatch()|/dispatch> either directly or indirectly via
C<execute()|/execute> or C<run()|/run>), it behaves differently in a
couple of respects:

First, if the object is C<formatter> and the method is
C<desired_equinox_dynamical> used as a mutator, the new value is parsed
as a time. See L</SPECIFYING TIMES> for the details.

Second, all methods are routed through the object's C<decode()> method.

=head2 time

 $output = $satpass2->time( $method ...);
 satpass2> time method ...

This interactive method times the given method. The arguments are the
name of an interactive method and the arguments to that method. The
return is whatever the called method returns. The timings are written to
standard error.

This method will fail if the L<Time::HiRes|Time::HiRes> module can not
be loaded.

=head2 tle

 $output = $satpass2->tle(...);
 satpass2> tle ...

This interactive method returns the actual TLE data for the observing
list. If any arguments are passed, they select the items to be
displayed, in the same way that L</choose> does, though in this case the
contents of the observing list are unaffected.

The following option is allowed:

 -verbose produces an expanded list, with data labeled.

=head2 unexport

 $satpass2->unexport( $name, ... );
 satpass2> unexport name ...

This interactive method undoes the effects of L<export()|/export>.
Unlike that method, multiple things can be unexported with a single
call. It is not an error to unexport something that was never exported.

=head2 validate

 $satpass2->validate( $options, $start_time, $end_time );
 satpass2> validate [ options ] start_time end_time

This interactive method validates the current observing list in the
given time range by performing position calculations at relevant times
in the range.

The only valid option is

 -quiet - suppress output of validation failures.

The start time defaults to noon of the current day; the end time
defaults to seven days after the start time.

This method really just wraps the C<validate()> methods in either
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE>, or
L<Astro::Coord::ECI::TLE::Set|Astro::Coord::ECI::TLE::Set>, as
appropriate.

=head2 version

 $output = $satpass2->version();
 satpass2> version

This interactive method simply returns C<Astro::App::Satpass2> version
information.

=head1 ATTRIBUTES

The Astro::App::Satpass2 object has a number of attributes to configure its
operation. In general:

Attributes that represent angles are in degrees, but may be set in other
representations (e.g. degrees, minutes, and seconds). See L</SPECIFYING
ANGLES> for more detail.

Boolean (i.e. true/false) attributes are set by convention to 1 for
true, or 0 for false. The evaluation rules are those of Perl itself:
0, '', and the undefined value are false, and everything else is true.

There are a few attributes whose names duplicate the names of methods.
These will be identified as attributes, for the sake of internal links.
For example, L</appulse>, but L</height attribute>.

The attributes are:

=head2 appulse

This numeric attribute specifies the maximum angle reportable by the
L</pass> method between the orbiting body and any of the background
objects. If the body passes closer than this, the closest point will
appear as an event in the pass. The intent is to capture transits or
near approaches.

If this attribute is set to 0, no check for close approaches to
background objects will be made.

See L</SPECIFYING ANGLES> for ways to specify an angle. This attribute
is returned in decimal degrees.

The initial setting is 0.

=head2 autoheight

This boolean attribute determines whether the L</geocode> method
attempts to acquire the height of the location above sea level.  It does
this only if the parameter is true and the geocoding returns exactly one
location. You may wish to turn this off (i.e. set it to 0) if the USGS
elevation service is being balky.

The default is 1 (i.e. true).

=head2 backdate

This boolean attribute determines whether the L</pass> method will
attempt to use orbital elements before their effective date. It is
actually simply propagated to the C<backdate> attribute of the
individual TLE objects, and so takes effect on a per-object basis. If it
is false, the L</pass> method will silently move the start of the pass
prediction to the effective date of the data if the specified pass start
is earlier than the effective date of the data.

The default is 0 (i.e. false). This is different from the old F<satpass>
script, which defaulted it to true.

=head2 background

This boolean attribute determines whether the location of the background
body is displayed when the L</appulse> logic detects an appulse.

The default is 1 (i.e. true).

=head2 continuation_prompt

This string attribute specifies the string used to prompt for
continuations of lines.

The default is C<< '> ' >>.

=head2 country

This attribute is ignored and deprecated.

This string attribute determines the default country for the L</geocode>
and L</height> methods. The intent is that it be an ISO 3166
two-character country code. At the moment it does nothing useful since
there is currently only one source for L</geocode> and L</height> data.

See L<http://www.iso.org/iso/en/prods-services/iso3166ma/index.html>
for the current list of country codes. Note that these are B<not>
always the same as the corresponding top-level geographic domain names
(e.g. Great Britain is 'GB' in ISO 3166 but for historical reasons has
both 'gb' and 'uk' as top-level geographic domain name).

The country codes are case-insensitive, since they will be converted to
lower case for use.

The default is 'us'.

=head2 date_format

This string attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly on the formatter object, or via the
L<tell()|/tell> method.

This attribute allows access to and manipulation of the formatter
object's L<date_format|Astro::App::Satpass2::Format/date_format> attribute.
This is normally used as a C<strftime (3)> format to format a date. See
the L<date_format|Astro::App::Satpass2::Format/date_format> documentation for
the default. See the documentation of the actual formatter class being
used for what it does.

This string attribute specifies the format used to display
dates. Documentation of the C<strftime (3)> subroutine may be found at
L<http://www.openbsd.org/cgi-bin/man.cgi?query=strftime&apropos=0&sektion=0&manpath=OpenBSD+Current&arch=i386&format=html>,
among other places.

The above is a long URL, and may be split across multiple lines. More
than that, the formatter may have inserted a hyphen at the break, which
needs to be taken out to make the URL good. I<Caveat user.>

=head2 debug

This numeric attribute turns on debugging output. The only supported
value is 0. The author makes no representation of what will happen if a
non-zero value is set, not does he promise that the behavior for a given
non-zero value will not change from release to release.

The default is 0.

=head2 desired_equinox_dynamical

This string attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly, or via the L<tell()|/tell>
method.

This attribute allows access to and manipulation of the formatter
object's
L<desired_equinox_dynamical|Astro::App::Satpass2::Format/desired_equinox_dynamical>
attribute. This is normally used to specify the desired equinox for
inertial coordinates. See the
L<desired_equinox_dynamical|Astro::App::Satpass2::Format/desired_equinox_dynamical>
documentation for the default. See the documentation of the actual
formatter class being used for what it does.

Note that while the wrapped attribute is a number, this class treats it
as a string. This results in a certain lack of orthogonality among the
behaviors of the L</set>, L</get>, and L</show> methods.

The L</set> method runs its input through the time parser object's
L<parse_time|Astro::App::Satpass2::ParseTime/parse> method. Since that expects
to parse a string of some sort, you can not (unfortunately) pass in a
Perl time. See the L<Astro::App::Satpass2::ParseTime|Astro::App::Satpass2::ParseTime>
documentation for the details.

The L</get> method simply returns a Perl time.

The L</show> method formats the value of the attribute in a way that can
(hopefully!) be parsed by any of the time parsers supplied with this
package.

=head2 echo attribute

This boolean attribute causes commands that did not come from the
keyboard to be echoed. Set it to a non-zero value to watch your scripts
run, or to debug your macros, since the echo takes place B<after>
parameter substitution has occurred.

The default is 0.

=head2 ellipsoid

This string attribute specifies the name of the reference ellipsoid to
be used to model the shape of the earth. Any reference ellipsoid
supported by see L<Astro::Coord::ECI|Astro::Coord::ECI> may be used.

The default is 'WGS84'.

=head2 error_out

This boolean attribute specifies the behavior on encountering an error.

If this attribute is true, all macros, source files, etc are aborted on
an error, and control is returned to the caller, or to the L<run()|/run>
method if that is where we came from. If standard in is not a terminal,
we exit.

If this attribute is false, errors are reported, but otherwise ignored.

The default is 0 (i.e. false).

=head2 exact_event

This boolean attribute specifies whether the L</pass> method should
compute visibility events (rise, set, max, into or out of shadow,
beginning or end of twilight) to the nearest second. If false, such
events are reported to the step size specified when the L</pass> method
was called.

The default is 1 (i.e. true).

=head2 explicit_macro_delete

This boolean attribute is ignored and deprecated. It exists because the
F<satpass> script required it to deal with a change in the functionality
of the C<macro> command.

The default is 1 (i.e. true).

=head2 extinction

This boolean attribute specifies whether magnitude estimates take
atmospheric extinction into account. It should be set true if you are
interested in measured brightness, and false if you are interested in
estimating magnitudes versus nearby stars.

The default is 1 (i.e. true).

=head2 filter

Setting this boolean attribute true suppresses the front matter that is
normally output by the L<run()|/run> method if standard input is a
terminal. If standard input is not a terminal, the front matter is not
provided anyway.

The default is undef (i.e. false).

=head2 flare_mag_day

This numeric attribute specifies the limiting magnitude for the flare
calculation for flares that occur during the day. For this purpose, it
is considered to be day if the elevation of the Sun is above the
L<twilight|/twilight> attribute.

The default is -6.

=head2 flare_mag_night

This numeric attribute specifies the limiting magnitude for the flare
calculation for flares that occur during the night. For this purpose, it
is considered to be night if the elevation of the Sun is below the
L<twilight|/twilight> attribute.

The default is 0.

=head2 formatter

This attribute specifies the class to be used to format output. You can
set it to either the actual formatter object, or to the name of the
class to use. In the latter case, an object of the appropriate class
will be instantiated, so C<get( 'formatter' )> always returns an object.
A call to C<show( 'formatter' )>, however, will always show the class
name.

When setting the formatter to a class name, the leading
C<'Astro::App::Satpass2::Format::'> may be omitted.

Minimal constraints on the formatter class are imposed, but while it
need not be a subclass of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, it C<must> conform to
that class' interface.

The default is C<'Astro::App::Satpass2::Format::Classic'>.

=head2 geometric

This boolean attribute specifies whether satellite rise and set should
be computed versus the geometric horizon or the effective horizon
specified by the L</horizon> attribute. If true, the computation is
versus the geometric horizon (elevation 0 degrees). If false, it is
versus whatever the L</horizon> attribute specifies.

The default is 1 (i.e. true).

=head2 gmt

This boolean attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly, or via the L<tell()|/tell>
method.

This attribute allows access to and manipulation of the formatter
object's L<gmt|Astro::App::Satpass2::Format/gmt> attribute. This is normally
used to specify whether time is displayed in local or Greenwich Mean
Time (a.k.a. Universal Time).  See the L<gmt|Astro::App::Satpass2::Format/gmt>
documentation for the default. See the documentation of the actual
formatter class being used for what it does.

The default will normally be 0 (i.e. false).

=head2 height attribute

This numeric attribute specifies the height of the observer above mean
sea level, in meters. To specify in different units, see L</SPECIFYING
DISTANCES>. The L<get()|/get> method returns meters.

There is no default; you must specify a value.

=head2 horizon

This numeric attribute specifies the minimum elevation a body must
attain to be considered visible, in degrees. If the L</geometric>
attribute is false, the rise and set of the satellite are computed
versus this setting also.

See L</SPECIFYING ANGLES> for ways to specify an angle. This attribute
is returned in decimal degrees.

The default is 20 degrees.

=head2 initfile attribute

This string attribute records the name of the file actually used by the
most recent L<init()|/init> call. It will be C<undef> if L<init()|/init>
has not been called, or if the most recent L<init()|/init> call did not
execute a file.

This attribute may not be set.

The default is C<undef>.

=head2 latitude

This numeric attribute specifies the latitude of the observer in degrees
north of the Equator. If your observing location is south of the
Equator, specify a negative number.

See L</SPECIFYING ANGLES> for ways to specify an angle. This attribute
is returned in decimal degrees.

There is no default; you must specify a value.

=head2 lit

This boolean attribute specifies how to determine if a body is lit by
the Sun.  If true (i.e. 1) it is considered to be lit if the upper limb
of the sun is above the horizon, as seen from the body. If false (i.e.
0), the body is considered lit if the center of the sun is above the
horizon.

The default is 1 (i.e. true).

=head2 local_coord

This string attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly, or via the L<tell()|/tell>
method.

This string attribute allows access to and manipulation of the formatter
object's L<local_coord|Astro::App::Satpass2::Format/local_coord> attribute.
This is normally used to specify the desired coordinates displayed by
the L</flare>, L</pass>, and L</position> methods. See the
L<Astro::App::Satpass2::Format local_coord|Astro::App::Satpass2::Format/local_coord>
documentation for the default. See the documentation of the actual
formatter class being used for what it does.

The formatter class should implement the following values:

'az_rng' - displays azimuth and range;

'azel' - displays elevation and azimuth;

'azel_rng' - displays elevation, azimuth, and range;

'equatorial' - displays right ascension and declination;

'equatorial_rng' - displays right ascension, declination, and range;

undef - displays the default ('azel_rng').

The default is undef.

=head2 location attribute

This string attribute contains a text description of the observer's
location.  This is not used internally, but if it is not empty it will
be displayed by the L</location> method.

There is no default; the attribute is undefined unless you supply a
value.

=head2 longitude

This numeric attribute specifies the longitude of the observer in
degrees east of Greenwich, England.  If your observing location is west
of Greenwich (as it would be if you live in North or South America),
specify a negative number.

See L</SPECIFYING ANGLES> for ways to specify an angle. This attribute
is returned in decimal degrees.

There is no default; you must specify a value.

=head2 model

This string attribute specifies the model to be used to predict the
satellite position. This is used to set the
L<Astro::Coord::ECI::TLE|Astro::Coord::ECI::TLE> model attribute, and
the valid values are the same as for that package. An attempt to set an
invalid model will result in an exception.

The default is 'model', which specifies whatever model is favored.

=head2 perltime

This boolean attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly, or via the L<tell()|/tell>
method.

This boolean attribute allows access to and manipulation of the time
parser object's L<perltime|Astro::App::Satpass2::ParseTime/perltime> attribute.
This is normally used (if at all) to specify that the Perl time
built-ins be used to construct the parsed time. See the
L<perltime|Astro::App::Satpass2::ParseTime/perltime> documentation for the
default. See the documentation of the actual time parser class being
used for what it does.

This attribute was originally introduced because versions of
L<Date::Manip|Date::Manip> prior to 6.0 did not properly handle the
transition from standard time to summer time. Of those time parsers
distributed with this package, only
L<Astro::App::Satpass2::ParseTime::Date::Manip::v5|Astro::App::Satpass2::ParseTime::Date::Manip::v5>
uses this attribute.

The default will normally be 0 (i.e. false).

=head2 prompt

This string attribute specifies the string used to prompt for commands.

The default is C<< 'satpass2> ' >>.

=head2 simbad_url

This string attribute does not, strictly speaking, specify a URL, but
does specify the server to use to perform SIMBAD lookups (see the
'lookup' subcommand of the L</sky> method). Currently-legal values are
C<'simbad.u-strasbg.fr'> (the original site) and C<'simbad.harvard.edu'>
(Harvard University's mirror).

The default is C<'simbad.u-strasbg.fr'>.

=head2 singleton

If this boolean attribute is true, the script uses
L<Astro::Coord::ECI::TLE::Set|Astro::Coord::ECI::TLE::Set> objects to
represent all bodies. If false, the set object is used only if the
observing list contains more than one instance of a given NORAD ID. This
is really only useful for testing purposes.

Use of the L<Astro::Coord::ECI::TLE::Set|Astro::Coord::ECI::TLE::Set>
object causes calculations to take about 15% longer.

The default is 0 (i.e. false).

=head2 spacetrack

This attribute is the L<Astro::SpaceTrack|Astro::SpaceTrack> object used
by the L</st> method. You must set it to an Astro::SpaceTrack object, or
to undef to clear the attribute. If no
L<Astro::SpaceTrack|Astro::SpaceTrack> object has been explicitly set,
the L</st> method will attempt to load
L<Astro::SpaceTrack|Astro::SpaceTrack> and set this attribute itself. If
it succeeds, this object will be available to the L</get> method.

This attribute may only be manipulated programmatically; it may not be
gotten or set via the L</dispatch> method, and therefore not by the
F<satpass2> script.

The default is undef.

=head2 stdout

This attribute determines what the L</execute> method does with its
output. The possible values are interpreted as follows:

C<undef> - the output is returned;

scalar reference - the output is appended to the scalar;

code reference - the code is called, with the output as its argument;

array reference - the output is split after newlines, and the result
pushed onto the array;

anything else - the print() method is called on the attribute value,
with the output as its argument.

This attribute may only be manipulated programmatically; it may not be
gotten or set via the L</dispatch> method, and therefore not by the
F<satpass2> script.

The default is the C<STDOUT> file handle.

=head2 time_format

This string attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly, or via the L<tell()|/tell>
method.

This attribute allows access to and manipulation of the formatter
object's L<time_format|Astro::App::Satpass2::Format/time_format> attribute.
This is normally used as a C<strftime(3)> format to format a time. See
the L<time_format|Astro::App::Satpass2::Format/time_format> documentation for
the default. See the documentation of the actual formatter class being
used for what it does.

The formatter class, if it makes use of this attribute at all, should
interpret the value of this attribute as a C<strftime(3)> format.

This string attribute specifies the strftime(3) format used to display
times.  Documentation of the C<strftime(3)> subroutine may be found at
L<http://www.openbsd.org/cgi-bin/man.cgi?query=strftime&apropos=0&sektion=0&manpath=OpenBSD+Current&arch=i386&format=html>,
among  other places.

The above is a long URL, and may be split across multiple lines. More
than that, the formatter may have inserted a hyphen at the break, which
needs to be taken out to make the URL good. I<Caveat user.>

=head2 time_parser

This attribute specifies the class to be used to parse times.  You can
set it to either the actual parser object, or to the name of the class
to use. In the latter case, an object of the appropriate class will be
instantiated, so C<get( 'time_parser' )> always returns an object.  A
call to C<show( 'time_parser' )>, however, will always show the class
name.

When setting this attribute to a class name, the leading
C<'Astro::App::Satpass2::ParseTime::'> can be omitted.

The time parser must be a subclass of
L<Astro::App::Satpass2::ParseTime|Astro::App::Satpass2::ParseTime>.

The default is C<'Astro::App::Satpass2::ParseTime'>, which actually returns one
of its subclasses, preferring the one that uses
L<Date::Manip|Date::Manip>. If L<Date::Manip|Date::Manip> is not
installed, you get
L<Astro::App::Satpass2::ParseTime::ISO8601|Astro::App::Satpass2::ParseTime::ISO8601>,
which is a home-grown parser for ISO-8601-ish times, and maybe better
than nothing.

=head2 twilight

This attribute specifies the elevation of the Sun at which day becomes
night or vice versa, in degrees. B<This will normally be a negative
number>, since a positive number says the Sun is above the horizon.

The words C<'civil'>, C<'nautical'>, or C<'astronomical'> are also
acceptable, as is any unique abbreviation of these words. They specify
-6, -12, and -18 degrees respectively.

See L</SPECIFYING ANGLES> for ways to specify an angle. This parameter
is displayed in decimal degrees, unless C<'civil'>, C<'nautical'>, or
C<'astronomical'> was specified.

The default is C<'civil'>.

=head2 tz

This string attribute is deprecated. It is provided for backward
compatibility with the F<satpass> script. The preferred way to
manipulate this is either directly, or via the L<tell()|/tell>
method on the relevant objects.

This string attribute specifies both the default time zone for date
parsing and the time zone for formatting of local times. This
overloading exists for historical reasons, but will change in the
future.  At any event it takes effect to the extent the date parser and
formatter objects support it.

If you are running under Mac OS 9 or less, or under VMS, you may have to
set this. Otherwise, you normally should not bother unless you are
deliberately doing input or producing output for a time zone other than
either your own, or GMT.

=head2 verbose

This boolean attribute specifies whether the L</pass> method should give
the position of the satellite every step that it is above the horizon.
If false, only rise, set, max, into or out of shadow, and the beginning
or end of twilight are displayed.

The default is 0 (i.e. false).

=head2 visible

This boolean attribute specifies whether the L</pass> method should
report only visible passes (if true) or all passes (if false). A pass is
considered to have occurred if the satellite, at some point in its path,
had an elevation above the horizon greater than the L<horizon|/horizon>
attribute.  A pass is considered visible if it is after the end of
evening twilight or before the beginning of morning twilight for the
observer (i.e. "it's dark"), but the satellite is illuminated by the
Sun.

The default is 1 (i.e. true).

=head2 warning

This boolean attribute specifies whether warnings and errors are
reported via C<carp> and C<croak>, or via C<warn> and C<die>. If true,
you get C<warn> and C<die>, if false C<carp> and C<croak>. This is set
true in the object instantiated by the L<run()|/run> method.

The default is 0 (i.e. false).

=head2 warn_on_empty

This boolean attribute specifies whether the L<list()|/list> interactive
method warns on an empty list. If false, you just get nothing back from
it.

The default is 1 (i.e. true).

=head2 webcmd

This string attribute specifies the system command to spawn to display a
web page. If not the empty string, the L<help|/help> method uses it to
display the help for this package on L<http://search.cpan.org/>. Mac OS
X users will find C<'open'> a useful setting, and Windows users will
find C<'start'> useful.

This functionality was added on speculation, since there is no good way
to test it in the initial release of the package.

The default is '' (i.e. the empty string), which leaves the
functionality disabled.

=head1 SPECIFYING ANGLES

This class accepts angle input in the following formats:

* Decimal degrees.

* Hours, minutes, and seconds, specified as C<hours:minutes:seconds>.
You would typically only use this for right ascension. You may specify
fractional seconds, or fractional minutes for that matter.

* Degrees, minutes, and seconds, specified as
C<degreesDminutesMsecondsS>.  The letters may be specified in either
case, and trailing letters may be omitted. You may specify fractional
seconds, or fractional minutes for that matter.

Examples:

 23.4 specifies 23.4 degrees.
 1:22.3 specifies an hour and 22.3 minutes
 12d33m5 specifies 12 degrees 33 minutes 5 seconds

Right ascension is always positive. Declination and latitude are
positive for north, negative for south. Longitude is positive for east,
negative for west.

=head1 SPECIFYING DISTANCES

This class accepts distances in a number of units, which are specified
by appending them to the magnitude of the distance. The default unit is
usually C<km> (kilometers), but for the L</height attribute> it is C<m>
(meters). The following units are recognized:

 au - astronomical units;
 ft - feet;
 km - kilometers;
 ly - light years;
 m -- meters;
 mi - statute miles;
 pc - parsecs.

=head1 SPECIFYING TIMES

This class (or, more properly, the modules it is based on) does not, at
this point, do anything fancy with times. It simply handles them as Perl
scalars, with the limitations that that implies.

Times may be specified absolutely, or relative to the previous absolute
time, or to the time the object was instantiated if no absolute time has
been specified.

=head2 Absolute time

Any time string not beginning with '+' or '-' is assumed to be an
absolute time, and is fed to one of the
L<Astro::App::Satpass2::ParseTime|Astro::App::Satpass2::ParseTime> modules for
parsing. What is legal here depends on which parser is in use. If you
have L<Date::Manip|Date::Manip>, you will get a parser based on that
module, with all the functionality that implies. If
L<Date::Manip|Date::Manip> is not installed, you get
L<Astro::App::Satpass2::ParseTime::ISO8601|Astro::App::Satpass2::ParseTime::ISO8601>,
which parses a subset of the ISO 8601 times, as a fall-back.

L<Date::Manip|Date::Manip> has at least some support for locales, so
check the L<Date::Manip|Date::Manip> documentation before you assume you
must enter dates in English. The ISO 8601 format is all-numeric.

=head2 Relative time

A relative time is specified by '+' or '-' and an integer number of
days. The number of days must immediately follow the sign. Optionally, a
number of hours, minutes, and seconds may be specified by placing
whitespace after the day number, followed by hours:minutes:seconds. If
you choose not to specify seconds, omit the trailing colon as well. The
same applies if you choose not to specify minutes. For example:

+7 specifies 7 days after the last-specified time.

'+7 12' specifies 7 days and 12 hours after the last-specified time.

If a relative time is specified as the first time argument to a method,
it is relative to the most-recently-specified absolute time, even if
that absolute time was specified by default. Relative times in
subsequent arguments to the same method are relative to the
previously-specified time, whether absolute or relative. For example:

 $satpass2->almanac( '', '+5' );

establishes the most-recently-specified time as 'today midnight', and
does an almanac for 5 days from that time. If the next method call is

 $satpass2->almanac( '+5', '+3' );

this produces almanac output for three days, starting 5 days after
'today midnight'.

=head1 TOKENIZING

When this class is used via the L<run()|/run> or L<execute()|/execute>
methods, method names and arguments are derived by tokenizing lines of
text. No attempt has been made to provide full shell-style tokenization
with all the bells and whistles, but such features as do exist are based
on C<bash(1)>. The tokenization rules are:

The line is broken into tokens on spaces, unless the spaces are quoted
or escaped as described below.

A back slash (C<\>) escapes the next character, turning a meta-character
into a normal one. Lines can be continued by placing the back slash at
the end of the line.

Single quotes (C<''>) cause everything inside them to be taken as a
single token, and almost anything inside them to be taken as a literal.
Unlike C<bash(1)>, but like C<perl(1)>, the back slash is recognized,
but its only use is to escape a single quote or another back slash.

Double quotes (C<"">) cause everything inside them to be taken as a
single token. Unlike single quotes, all meta-characters except single
quotes are recognized inside double quotes.

The dollar sign (C<$>) introduces an interpolation. If the first
character after the dollar sign is not a left curly bracket, that
character and any following word characters name the thing to be
interpolated, which may be either an argument (specified by its number,
starting from 1), an L<attribute|/ATTRIBUTES> of the object, an
environment variable, or any of the following special characters:

 0 - The name of the Perl script ($0);
 # - The number of positional arguments;
 * - All arguments, but joined by white space inside double
     quotes;
 @ - All arguments as individual tokens;
 $ - The process ID;
 _ - The name of the Perl executable ($^X).

The name of the thing to be interpolated can be enclosed in curly
brackets if needed to delimit it from following text. This also allows
the substitution of text for the argument, as follows:

C<${parameter:-text}> causes the given text to be substituted if the
parameter is undefined.

C<${parameter:=text}> is the same as above, but also causes the text to
be assigned to the parameter if it is unassigned. Like C<bash(1)>, this
assignment can not take place on numbered parameters or special
variables. If done on an attribute or environment variable, it causes
that attribute or environment variable to be set to the given value.

C<${parameter:?text}> causes the parse to fail with the error 'text' if
the parameter is undefined.

C<${parameter:+text}> causes the value of the given text to be used if
the parameter is defined, otherwise '' is used.

C<${parameter:offset}> and C<${parameter:offset:length}> take substrings
of the parameter value. The offset and length must be numeric.

Note that token expansion takes place inside curly brackets.

An exclamation mark (C<!>) in front of the name of an interpolated
parameter introduces a level of indirection, B<provided> it occurs
inside curly brackets. That is, if environment variable C<FOO> is
defined as C<'BAR'>, and environment variable C<BAR> is defined as
C<'BAZ'>, then C<${!FOO}> interpolates C<'BAZ'>.  Only one level of
indirection is supported.

One of the angle bracket characters (C<< < >> or C<< > >>) or the
vertical bar character (C<|>) introduce a redirection specification
(and, incidentally, a new token). Anything after the meta-characters in
the same token is taken to be the file or program name.

Any unquoted token or redirection file name which begins with a tilde
(C<~>) has tilde expansion performed on everything up to the first slash
(C</>), or the end of the token, B<provided> the operating system
supports this.  The empty username is expanded using C<getpwuid()> if
this is supported, or various possibly-OS-specific environment variables
if not. Non-empty user names are expanded if C<getpwnam()> is supported
B<and> the user actually exists; otherwise an exception is raised. Tilde
expansion is not done inside quotes (either single or double), even if
the tilde is the first character. This is consistent with C<bash(1)>.

Wild card expansion is never performed by the tokenizer. If an
individual method does wild card expansion on its arguments, this will
be noted in its documentation.

=head1 DIFFERENCES FROM SATPASS

The functionality provided by this package is similar, but not
identical, to the functionality provided by the F<satpass> script
included in package F<Astro-satpass>. Compatibility has been retained
unless there appeared to be a pressing reason to make a change, but this
rewrite has also provided an opportunity to rethink some things that
appeared to need rethinking.

The following differences from F<satpass> are known to exist:

=head2 Tokenization

Assigning a new value to an undefined positional parameter is no longer
allowed. The F<satpass> script allowed C<${1:=Foo}>, but this package
does not. The idea was to be consistent with C<bash(1)>.

=head2 Added commands/methods

Some methods have been added which do not appear as commands in
F<satpass>. Those methods, and the reason for their addition, are:

=over

=item begin, end

The restructuring involved in the rewrite made it possible to have
explicit localization blocks, which I kind of wanted all along.

=item location

It was decided to have an explicit method to display the location,
rather than have certain methods (e.g. 'pass') display it, and others
(e.g. 'flare') not. In other words, I decided I was not smart enough to
know when a user would want the location displayed.

=item time

The F<satpass> script had a C<-time> option whenever I wanted to time
something. The architecture of this package made it simpler to just have
a separate interactive method.

=back

=head2 Deprecated commands

Some commands are deprecated, but will remain for backward compatibility
until support for C<satpass> is dropped. After this happens, they will
be put through a deprecation cycle and disappear.

=over

=item st

This command/method is deprecated in favor of the
L<tell()|/tell> command/method, with first argument
C<'spacetrack'>. It will remain until support for the F<satpass> script
is dropped, and then be put through a deprecation cycle and removed.

People using the 'st' command interactively can define 'st' as a macro:

 satpass2> macro define st 'tell spacetrack $@'

Note that the elimination of this command/method leaves you no way to
localize individual attributes of the L<spacetrack|/spacetrack>
attribute. You can still localize the whole object, though. Please
contact me if you need the removed functionality.

=back

=head2 Dropped commands

Some commands that appear in the F<satpass> script have been dropped,
for various reasons. The commands, and the reasons for eliminating them,
are given below.

=over

=item check_version

This command was originally added because I wanted to split the
F<satpass> script off from L<Astro::Coord::ECI|Astro::Coord::ECI>, but
CPAN does not detect changes in scripts.

It was dropped because the F<satpass2> script is trivial. Added
functionality will (almost always) go in C<Astro::App::Satpass2>, and changes
there will be detected by CPAN or CPANPLUS.

=item store, retrieve

These were added on a whim, and I have never even come close to using
them. If you have a need for them please contact me.

=item times

This was added because I was working on a way to extend the time range
and wanted a way to check the code. This work was stalled, and the
L<Time::y2038|Time::y2038> module and Perl 5.12 both appear to make it
obsolete anyway.

=back

=head2 Modified commands/methods

Some commands that appear in the F<satpass> script have been modified.
The commands, and the reasons for their modification, appear below.

=over

=item almanac

The location of the observing station is no longer emitted as part of
the output; an explicit location() is needed. I decided that I was not
really smart enough to know when the user would want this output.

Until support for the F<satpass> script is dropped, though, output from
this command will still include the location if the command is issued
from a F<satpass> initialization file (as opposed to an C<Astro::App::Satpass2>
initialization file), or from a macro defined in a F<satpass>
initialization file.

=item flare

The sense of the C<-am>, C<-day>, and C<-pm> options is reversed from
the sense in F<satpass>. That is, in F<satpass>, C<-am> meant not to
display morning flares, whereas in C<Astro::App::Satpass2>, C<-noam> means not
to display morning flares.

In order to ease the transition to C<Astro::App::Satpass2>, these options will
be taken in their F<satpass> sense (and inverted to their new sense
before use) if the C<flare> command is used in a F<satpass>
initialization file, or in a macro defined in a F<satpass>
initialization file. There is no supported way to get the F<satpass>
behavior when using the C<flare> command in any other environment, or
when calling the C<flare()> method. This functionality will be revoked
when support for F<satpass> is dropped.

=item geocode

This method no longer handles locations in Canada, because the
underlying web service changed its access policy. This functionality
became unsupported in satpass 0.021 (Astro-satpass 0.021 13-Feb-2009)
for pretty much the same reason.

=item pass

The location of the observing station is no longer emitted as part of
the output; an explicit location() is needed. I decided that I was not
really smart enough to know when the user would want this output.

Until support for the F<satpass> script is dropped, though, output from
this command will still include the location if the command is issued
from a F<satpass> initialization file (as opposed to an C<Astro::App::Satpass2>
initialization file), or from a macro defined in a F<satpass>
initialization file.

=item position

The method generates position information for a single time. The
F<satpass> time range and C<-realtime> functions have been
revoked. This function was added when I had vague dreams of figuring out
how to drive a telescope off the output, but so far those dreams are
unrealized, and I can think of no other use for the functionality. The
rewritten output mechanism is not capable of actually displaying output
in realtime, and handling multiple times in a system that separates
formatting from computation appeared to be too difficult to tackle
without an incentive.

=back

=head2 Dropped attributes

=over

=item simbad_version

This attribute was used to select the version of the SIMBAD protocol to
use to access L<http://simbad.u-strasbg.fr/>. Since only version 4 is
currently supported, and this has been the default in F<satpass> for
some time, this attribute is eliminated.

=back

=head2 Modified attributes

=over

=item backdate

This attribute defaults to false (i.e. 0). In the F<satpass> script, it
defaulted to true.

=item country

This attribute existed to support selection of geocoding servers, but
since geocoder.ca changed its access policy only geocoder.us is
supported, and this attribute is ignored and deprecated. This attribute
will be dropped when support for F<satpass> is dropped.

=item date_format

This attribute is deprecated. It is properly an attribute of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, and is implemented as a
wrapper for that class' C<date_format> attribute. It will be dropped
when support for F<satpass> is dropped.

=item desired_equinox_dynamical

This attribute is deprecated. It is properly an attribute of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, and is implemented as a
wrapper for that class' C<desired_equinox_dynamical> attribute. It will
be dropped when support for F<satpass> is dropped.

=item explicit_macro_delete

This attribute is ignored and deprecated, since the C<Astro::App::Satpass2>
macro() functionality always requires an explicit C<delete> to delete a
macro. This attribute will be dropped when support for F<satpass> is

=item gmt

This attribute is deprecated. It is properly an attribute of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, and is implemented as a
wrapper for that class' C<gmt> attribute. It will be dropped when
support for F<satpass> is dropped.

=item local_coord

This attribute is deprecated. It is properly an attribute of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, and is implemented as a
wrapper for that class' C<local_coord> attribute. It will be dropped
when support for F<satpass> is dropped.

=item time_format

This attribute is deprecated. It is properly an attribute of
L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>, and is implemented as a
wrapper for that class' C<time_format> attribute. It will be dropped
when support for F<satpass> is dropped.

=item twilight

The F<satpass> mutator forced the sign to be negative. The
C<Astro::App::Satpass2> mutator does not. Note that a positive setting means
the Sun is above the horizon.

=back

=head1 ENVIRONMENT VARIABLES

C<SATPASS2INI> can be used to specify an initialization file to use in
lieu of the default. This can still be overridden by the
C<-initialization_file> command option.

C<SATPASSINI> will be used in a last-ditch effort to find an
initialization file, if C<-initialization_file> is not specified,
C<SATPASS2INI> does not exist, and the initialization file was not found
in its default location.

=head1 BUGS

Bugs can be reported to the author by mail, or through
L<http://rt.cpan.org/>.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

TIGER/LineE<reg> is a registered trademark of the U.S. Census Bureau.

=cut

# ex: set textwidth=72 :
