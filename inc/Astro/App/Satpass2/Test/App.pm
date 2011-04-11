package Astro::App::Satpass2::Test::App;

use 5.006002;

use strict;
use warnings;

use base qw{ Exporter };

use Carp;

use Scalar::Util qw{ blessed };
use Test::More 0.40;

use Astro::App::Satpass2;

our @EXPORT = qw{
    check_access
    class
    execute
    method
};

my $app = 'Astro::App::Satpass2';

sub check_access ($) {
    my ( $url ) = @_;

    eval {
	require LWP::UserAgent;
	1;
    } or return "Can not load LWP::UserAgent";

    my $ua = LWP::UserAgent->new()
	or return "Can not instantiate LWP::UserAgent";

    my $rslt = $ua->get( $url )
	or return "Can not get $url";

    $rslt->is_success or return $rslt->status_line;

    return;
}

sub class ($) {
    ( $app ) = @_;
    return;
}

sub execute (@) {	## no critic (RequireArgUnpacking)
    splice @_, 0, 0, 'execute';
    goto &method;
}

sub method (@) {	## no critic (RequireArgUnpacking)
    my ( $method, @args ) = @_;
    my ( $want, $title ) = splice @args, -2;
    my $got;
    if ( eval { $got = $app->$method( @args ); 1 } ) {
	'new' eq $method and $app = $got;
	blessed( $got ) and $got = undef;
	foreach ( $want, $got ) {
	    defined and not ref and chomp;
	}
	@_ = ( $got, $want, $title );
	ref $want eq 'Regexp' ? goto &like :
	    ref $want ? goto &is_deeply : goto &is;
    } else {
	$got = $@;
	chomp $got;
	defined $want or $want = 'Unexpected error';
	ref $want eq 'Regexp'
	    or $want = qr<\Q$want>smx;
	@_ = ( $got, $want, $title );
	goto &like;
    }
}

sub Astro::App::Satpass2::__TEST__frame_stack_depth {
    my ( $self ) = @_;
    return scalar @{ $self->{frame} };
}

sub Astro::App::Satpass2::__TEST__is_exported {
    my ( $self, $name ) = @_;
    return exists $self->{exported}{$name} ? 1 : 0;
}

#	$string = $self->__raw_attr( $name, $format )

#	Fetches the raw value of the named attribute, running it through
#	the given sprintf format if that is not undef. THIS IS AN
#	UNSUPPORTED INTERFACE USED FOR TESTING ONLY.

sub Astro::App::Satpass2::__TEST__raw_attr {
    my ( $self, $name, $format ) = @_;
    defined $format or return $self->{$name};
    return sprintf $format, $self->{$name};
}


1;

__END__

=head1 NAME

Astro::App::Satpass2::Test::App - Help test Astro::App::Satpass2;

=head1 SYNOPSIS

 use lib qw{ inc };
 use Astro::App::Satpass2::Test::App;
 
 ... set location ...
 
 execute 'almanac 20100401T000000Z', <<'EOD', 'Test almanac'
 ... expected almanac output ...
 EOD


=head1 DESCRIPTION

This entire module is private to the C<Astro-App-Satpass2> distribution.
It may be changed or retracted without notice. This documentation is for
the convenience of the author.

This module exports subroutines to help test the
L<Astro::App::Satpass2|Astro::App::Satpass2> class. It works by holding
an C<Astro::App::Satpass2> object. The exported subroutines generally
perform tests on this object.

=head1 SUBROUTINES

This module exports the following subroutines:

=head2 check_access

 SKIP: {
     my $tests = 2;
     my $rslt;
     $rslt = check_access 'http://celestrak.com/'
         and skip $rslt, $tests
     ... two tests ...
 }

This subroutine checks access to the given URL. It returns a false value
if it has access to the URL, or an appropriate message otherwise.
Besides the usual reasons of net connectivity or host availability, it
may fail because L<LWP::UserAgent|LWP::UserAgent> can not be loaded.

=head2 class

 class 'Astro::App::Satpass2';

This subroutine replaces the stored object (if any) with the given class
name. The stored object is initialized to C<'Astro::App::Satpass2'>.

=head2 execute

 execute 'location', <<'EOD', 'Verify location';
 Location: 1600 Pennsylvania Ave NW Washington DC 20502
           Latitude 38.8987, longitude -77.0377, height 17 m
 EOD

This subroutine calls the C<execute()> method on the stored object and
tests the result. The last argument is the test name; the next-to-last
is the expected result.  All other arguments are arguments to
C<execute()>.

This is really just a convenience wrapper for L<method()|/method>.

=head2 method

 method 'new', undef, 'Instantiate a new object';
 method get => 'twilight', 'civil', 'Confirm civil twilight';
 method set => twilight => 'astronomical', undef,
     'Set astronomical twilight';

This subroutine calls an arbitrary method on the stored object and tests
the result. The last argument is the test name, and the next-to-last
argument is the desired result. The first argument is the method name,
and all other arguments (if any) are arguments to the method. If the
method is 'new', the result becomes the new stored object.

If the method fails, the desired value is compared to the exception
using C<like()>, after converting the desired value to a C<Regex> if
needed.

If the method returns a blessed reference, the return for testing
purposes is set to C<undef>. In this case, all we're doing is testing to
see if the method call succeeded.

If the desired result is a C<Regexp>, the results are tested with
C<like()>. If it is any other reference, the test is done with
C<is_deeply()>. Otherwise, they are tested with C<is()>.

=head1 METHODS

This module also does some aspect-oriented programming (read: 'violates
encapsulation') by placing the following methods in the
L<Astro::App::Satpass2|Astro::App::Satpass2> name space:

=head2 __TEST__frame_stack_depth

 method __TEST__frame_stack_depth => 1, 'Stack is empty';

This method returns the context frame stack depth. There is always 1
frame, even when the stack is nominally empty.

=head2 __TEST__is_exported

 method __TEST__is_exported => 'foo', 1, 'Foo is exported';

This method returns C<1> if the given variable is currently exported,
and C<0> otherwise.

=head2 __TEST__raw_attr

 method __TEST__raw_attr => '_twilight', '%.3f', -0.215,
     'Twilight in radians';

This method bypasses the accessors and accesses attribute values
directly. It takes one or two arguments. The first is the name of the
hash key to be accessed. The second argument, which is optional, is an
C<sprintf> format to run the value through.

=head1 SEE ALSO

L<Astro::App::Satpass2|Astro::App::Satpass2>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
