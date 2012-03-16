package Astro::App::Satpass2::Utils;

use 5.008;

use strict;
use warnings;

use base qw{ Exporter };

use Scalar::Util qw{ blessed looks_like_number };

our $VERSION = '0.002';

our @EXPORT_OK = qw{ has_method instance load_package quoter };

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
    sub load_package {
	my ( $module, @prefix ) = @_;
	defined $module or $module = '';

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

Copyright (C) 2011-2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
