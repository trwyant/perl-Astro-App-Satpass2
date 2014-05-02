package Astro::App::Satpass2::Utils;

use 5.008;

use strict;
use warnings;

use base qw{ Exporter };

use Astro::Coord::ECI::Utils ();
use Cwd ();
use File::HomeDir;
use File::Spec;
use Getopt::Long 2.33;
use Scalar::Util 1.26 qw{ blessed looks_like_number };

our $VERSION = '0.018_01';

our @EXPORT_OK = qw{
    __arguments expand_tilde fold_case
    has_method instance load_package merge_hashes my_dist_config quoter
    __date_manip_backend
};

BEGIN {
    *fold_case = Astro::Coord::ECI::Utils->can( 'fold_case' ) ||
	CORE->can( 'fc' ) ||		# Perl 5.16 amd up
	sub ($) { return lc $_[0] };
}

# Documented in POD

{

    my @default_config = qw{default pass_through};
####    my @default_config = qw{default};

    sub __arguments {
	my ( $self, @args ) = @_;

	has_method( $self, '__parse_time_reset' )
	    and $self->__parse_time_reset();

	@args = map {
	    has_method( $_, 'dereference' ) ?  $_->dereference() : $_
	} @args;

	'HASH' eq ref $args[0]
	    and return ( $self, @args );

	my @data = caller(1);
	my $code = \&{$data[3]};

	local @ARGV = @args;
	my $lgl = $self->_get_attr($code, 'Verb') || [];
	my %opt;
	my $err;
	local $SIG{__WARN__} = sub {$err = $_[0]};
	my $config = 
	    $self->_get_attr($code, 'Configure') || \@default_config;
	my $go = Getopt::Long::Parser->new(config => $config);
	if ( !  $go->getoptions(\%opt, @$lgl) ) {
	    $self->can( 'wail' )
		and $self->wail($err);
	    require Carp;
	    Carp::croak( $err );
	}

	return ( $self, \%opt, @ARGV );
    }
}

# $backend = __date_manip_backend()
#
# This subroutine loads Date::Manip and returns the backend available,
# either 5 or 6. If Date::Manip can not be loaded it returns undef.
#
# The idea here is to return 6 if the O-O interface is available, and 5
# if it is not but Date::Manip is.

sub __date_manip_backend {
    load_package( 'Date::Manip' )
	or return;
    Date::Manip->isa( 'Date::Manip::DM6' )
	and return 6;
    return 5;
}

sub expand_tilde {
    my ( $self, $fn ) = @_;
    defined $fn
	and $fn =~ s{ \A ~ ( [^/]* ) }{ _user_home_dir( $self, $1 ) }smxe;
    return $fn;
}

{
    my %special = (
	'+'	=> sub { return Cwd::cwd() },
	'~'	=> sub { return my_dist_config() },
	''	=> sub { return File::HomeDir->my_home() },
    );
#	$dir = $self->_user_home_dir( $user );
#
#	Find the home directory for the given user, croaking if this can
#	not be done. If $user is '' or undef, returns the home directory
#	for the current user.

    sub _user_home_dir {
	my ( $self, $user ) = @_;
	defined $user
	    or $user = '';

	if ( my $code = $special{$user} ) {
	    defined( my $special_dir = $code->( $user ) )
		or $self->wail( "Unable to find ~$user" );
	    return $special_dir;
	} else {
	    defined( my $home_dir = File::HomeDir->users_home( $user ) )
		or $self->wail( "Unable to find home for $user" );
	    return $home_dir;
	}
    }
}

sub has_method {
    my ( $object, $method ) = @_;

    ref $object or return;
    blessed( $object ) or return;
    return $object->can( $method );
}

sub instance {
    my ( $object, $class ) = @_;
    ref $object or return;
    blessed( $object ) or return;
    return $object->isa( $class );
}


{
    my %loaded;
    my $my_lib = my_dist_config();
    if ( defined $my_lib ) {
	$my_lib = File::Spec->catdir( $my_lib, 'lib' );
	-d $my_lib
	    or $my_lib = undef;
    }
    my %valid_complaint = map { $_ => 1 } qw{ whinge wail weep };

    sub load_package {
#	my ( $module, @prefix ) = @_;
	my @prefix = @_;
	my $self;
	blessed( $prefix[0] )
	    and $self = shift @prefix;
	my $opt = 'HASH' eq ref $prefix[0] ? shift @prefix : {};
	my $module = shift @prefix;

	local @INC = @INC;

	my $use_lib = exists $opt->{lib} ? $opt->{lib} : $my_lib;
	if ( defined $use_lib ) {
	    require lib;
	    lib->import( $use_lib );
	}

	foreach ( $module, @prefix ) {
	    '' eq $_
		and next;
	    m/ \A [[:alpha:]]\w* (?: :: [[:alpha:]]\w* )* \z /smx
		and next;

	    my $msg = "Invalid package name '$_'";

	    if ( $self ) {
	        my $method = $opt->{complaint} || 'weep';
		$valid_complaint{$method}
		    or $method = 'weep';
		$self->can( $method )
		    and return $self->$method( $msg );
	    }

	    require Carp;
	    Carp::confess( 
		"Programming error - $msg"
	    );
	}

	my $key = join ' ', $module, @prefix;
	exists $loaded{$key}
	    and return $loaded{$key};

	push @prefix, '';
	foreach my $pfx ( @prefix ) {
	    my $package = join '::', grep { $_ ne '' } $pfx, $module;
	    '' eq $package
		and next;
	    ( my $fn = $package ) =~ s{ :: }{/}smxg;
	    eval {
		require "$fn.pm";	## no critic (RequireBarewordIncludes)
		1;
	    } or next;
	    return ( $loaded{$key} = $package );
	}

	if ( $opt->{fatal} ) {
	    my $msg = "Can not load $module: $@";
	    my $method = $opt->{fatal};
	    $valid_complaint{$method}
		or $method = 'wail';
	    $self
		and $self->can( $method )
		and return $self->$method( $msg );
	    require Carp;
	    Carp::croak( $msg );
	}

	$loaded{$key} = undef;

	return;
    }
}


# The Perl::Critic annotation on the following line should not (strictly
# speaking) be necessary - but Subroutines::RequireArgUnpacking does not
# understand the unpacking to be subject to the configuration
#     allow_arg_unpacking = grep
sub merge_hashes {	## no critic (RequireArgUnpacking)
    my @args = grep { 'HASH' eq ref $_ } @_;
    @args == 1
	and return $args[0];
    my %rslt;
    foreach my $hash ( @args ) {
	@rslt{ keys %{ $hash } } = values %{ $hash };
    }
    return \%rslt;
}


sub my_dist_config {
    my ( $opt ) = @_;

    return File::HomeDir->my_dist_config(
	'Astro-App-Satpass2',
	{ create => $opt->{'create-directory'} },
    );
}


sub quoter {
    my @args = @_;
    my @rslt = map { _quoter( $_ ) } @args;
    return wantarray ? @rslt : join ' ', @rslt;
}

sub _quoter {
    my ( $string ) = @_;
    return 'undef' unless defined $string;
    return $string if looks_like_number ($string);
    return "''" unless $string;
    return $string unless $string =~ m/ [\s'"\$] /smx;
    $string =~ s/ ( [\\'] ) /\\$1/smxg;
    return qq{'$string'};
}


1;

__END__

=head1 NAME

Astro::App::Satpass2::Utils - Utilities for Astro::App::Satpass2

=head1 SYNOPSIS

 use Astro::App::Satpass2::Utils qw{ instance };
 instance( $foo, 'Bar' )
    or die '$foo is not an instance of Bar';

=head1 DESCRIPTION

This module is a grab-bag of utilities needed by
L<Astro::App::Satpass2|Astro::App::Satpass2>.

This module is B<private> to the
L<Astro::App::Satpass2|Astro::App::Satpass2> package. Any and all
functions in it can be modified or revoked without prior notice. The
documentation is for the convenience of the author.

All documented subroutines can be exported, but none are exported by
default.

=head1 SUBROUTINES

This module supports the following exportable subroutines:

=head2 expand_tilde

 $expansion = $self->expand_tilde( $file_name );

This mixin (so-called) performs tilde expansion on the argument,
returning the result. Arguments that do not begin with a tilde are
returned unmodified. In addition to the usual F<~/> and F<~user/>, we
support F<~+/> (equivalent to F<./>) and F<~~/> (the user's
configuration directory). The expansion of F<~~/> will result in an
exception if the configuration directory does not exist.

All that is required of the invocant is that it support the package's
suite of error-reporting methods C<whinge()>, C<wail()>, and C<weep()>.

=head2 fold_case

 my $folded = fold_case( $text );

THIS SUBROUTINE IS DEPRECATED IN FAVOR OF THE SAME-NAMED SUBROUTINE IN
L<Astro::Coord::ECI::Utils|Astro::Coord::ECI::Utils>. Because this
module is documented as being B<private> to the C<Astro::App::Satpass2>
package, I feel justified in using an accelerated deprecation schedule,
and removing it completely the first release after June 30 2014. In the
meantime it is equated to C<Astro::Coord::ECI::Utils::fold_case()>
provided the latter exists.

This subroutine performs best-effort case folding of data for case-blind
operations. Under Perl 5.16 or higher, it is an alias for the C<fc()>
built-in. Otherwise it is an alias for the C<lc()> built-in if that can
be aliased. As a last resort under older Perls, it is a subroutine that
calls C<lc()> on its argument. The exact output should not be relied on,
and in particular the author may make unannounced twiddles to the
pre-5.16 case if a strong case for something more sophisticated than a
simple C<lc()> manifests itself.

=head2 has_method

 has_method( $object, $method );

This exportable subroutine returns a code reference to the named method
if the given object has the method, or a false value otherwise. What you
actually get is the result of C<< $invocant->can( $method ) >> if the
invocant is a blessed reference, or a return otherwise.

=head2 instance

 instance( $object, $class )

This exportable subroutine returns a true value if C<$object> is an
instance of C<$class>, and false otherwise. The C<$object> argument need
not be a reference, nor need it be blessed, though in these cases the
return is false.

=head2 load_package

 load_package( $module );
 load_package( $module, 'Astro::App::Satpass2' );
 load_package( { lib => '.lib' }, $module );
 $object->load_package( { complaint => 'wail' }. $module );

This exportable subroutine loads a Perl module. The first argument is
the name of the module itself. Subsequent arguments are prefixes to try,
B<without> any trailing colons.

This subroutine can also be called as a method. If this is done errors
will be reported with a call to the invocant's C<weep()> method if that
exists. Otherwise C<Carp> will be loaded and errors will be reported by
C<Carp::confess()>.

An optional first argument is a reference to a hash of option values.
The supported values are:

=over

=item complaint

This specifies how to report errors if C<load_package()> is called as a
method. Valid values are C<'whinge'>, C<'wail'>, and C<'weep'>. An
invalid value is equivalent to C<'weep'>, which is the default. If not
called as a method, this option is ignored and a call to
C<Carp::confess()> is done.

=item fatal

If C<load_package()> is called as a method, this argument specifies how
to report a failure to load the requested module. Valid values are
C<'whinge'>, C<'wail'> and C<'weep'>. An invalid value is equivalent to
C<'wail'>, which is the default. If C<load_package()> is not called as a
method, any true value will cause C<Carp::croak()> to be called, and the
failure B<not> to be recorded, so that the load can be retried with a
different path.

Either way, a false value causes C<load_package()> to simply return if
the requested module can not be loaded.

=item lib

This specifies a directory to add to C<@INC> before attempting the load.
If it is not specified, F<lib/> in the configuration directory is used.
If it is specified as C<undef>, nothing is added to C<@INC>. No
expansion is done on the directory name.

=back

In the examples, if C<$module> contains C<'Foo'>, the first example will
try to C<require 'Foo'>, and the second will try to
C<require 'Astro::App::Satpass2::Foo'> and C<require 'Foo'>, in that
order. The first attempt that succeeds returns the name of the module
actually loaded. If no attempt succeeds, C<undef> is returned.

Arguments are cached, and subsequent attempts to load a module simply
return the contents of the cache.

=head2 merge_hashes

 my $hash_ref = merge_hashes( \%hash1, \%hash2, ... );

This subroutine returns a reference to a hash that contains keys merged
from all the hash references passed as arguments. Arguments which are
not hash references are removed before processing. If there are no
arguments, an empty hash is returned. If there is exactly one argument,
it is returned. If there is more than one argument, a new hash is
constructed from all keys of all hashes, and that hash is returned. If
the same key appears in more than one argument, the value from the
right-most argument is the one returned.

=head2 my_dist_config

 my $cfg_dir = my_dist_config( { 'create-directory' => 1 } );

This subroutine simply wraps

 File::HomeDir->my_dist_config( 'Astro-App-Satpass2' );

You can pass an optional reference to an options hash (sic!). The only
supported option is {'create-directory'}, which is passed verbatim to
the C<File::HomeDir> C<'create'> option.

If the configuration directory is found or successfully created, the
path to it is returned. Otherwise C<undef> is returned.

=head2 quoter

 say scalar quoter( @vals );
 say quoter( @vals );

This exportable subroutine quotes and escapes its arguments as necessary
for the parser. Specifically, if an argument is:

* undef, C<'undef'> is returned;

* a number, C<$string> is returned unmodified;

* an empty string, C<''> is returned;

* a string containing white space, quotes, or dollar signs, the value is
escaped and enclosed in double quotes (C<"">).

* anything else is returned unmodified.

If called in scalar context, the results are concatenated with
C<< join ' ', ... >>. Otherwise they are simply returned.

=head2 __arguments

 my ( $self, $opt, @args ) = __arguments( @_ );

This subroutine is intended to be used to unpack the arguments of an
C<Astro::App::Satpass2> interactive method or a code macro.

Specifically, this subroutine expects to be called from a subroutine or
method that has the C<Verb()> attribute, and expects the contents of the
parentheses in the C<Verb()> attribute to be a set of
white-space-delimited L<Getopt::Long|Getopt::Long> option
specifications. Further, if the subroutine has a C<Configure()>
attribute, it will be used to configure the L<Getopt::Long|Getopt::Long>
object.

The first argument is expected to be the invocant, and is always
returned intact.

Subsequent arguments are preprocessed by calling their C<dereference()>
method if it exists. This is a severe wart on the code, but was needed
(I thought) to get certain arguments through C<Template-Toolkit>.
Arguments that do not have a C<dereference()> method are left
unmodified, as are any unblessed arguments.

If the first remaining argument after preprocessing is a hash reference,
it is assumed that the options have already been processed, and we
simply return the invocant and the remaining arguments as they now
stand.

If the first remaining argument after preprocessing is B<not> a hash
reference, we run all the remaining arguments through
L<Getopt::Long|Getopt::Long>, and return the invocant, the options hash
populated by L<Getopt::Long>, and all remaining arguments. If
L<Getopt::Long|Getopt::Long> encounters an error an exception is thrown.
This is done using the invocant's C<wail()> method if it has one,
otherwise C<Carp> is loaded and C<Carp::croak()> is called.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
