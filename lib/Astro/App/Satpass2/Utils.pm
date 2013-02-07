package Astro::App::Satpass2::Utils;

use 5.008;

use strict;
use warnings;

use base qw{ Exporter };

use File::HomeDir;
use File::Spec;
use Scalar::Util qw{ blessed looks_like_number };

our $VERSION = '0.012_06';

our @EXPORT_OK = qw{
    has_method instance load_package merge_hashes my_dist_config quoter
    __date_manip_backend
};

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

    sub load_package {
	my ( $module, @prefix ) = @_;
	defined $module or $module = '';

	local @INC = @INC;

	if ( defined $my_lib ) {
	    require lib;
	    lib->import( $my_lib );
	}

	foreach ( $module, @prefix ) {
	    '' eq $_
		and next;
	    m/ \A [[:alpha:]]\w* (?: :: [[:alpha:]]\w* )* \z /smx
		and next;
	    require Carp;
	    Carp::confess( 
		"Programming error - Invalid module name $_"
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

	return ( $loaded{$key} = undef );
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

This exportable subroutine loads a Perl module. The first argument is
the name of the module itself. Subsequent arguments are prefixes to try,
B<without> any trailing colons.

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

 quoter( $string )

This exportable subroutine quotes and escapes its argument as necessary
for the parser. Specifically, if C<$string> is:

* undef, C<'undef'> is returned;

* a number, C<$string> is returned unmodified;

* an empty string, C<''> is returned;

* a string containing white space, quotes, or dollar signs, the value is
escaped and enclosed in double quotes (C<"">).

* anything else is returned unmodified.


=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
