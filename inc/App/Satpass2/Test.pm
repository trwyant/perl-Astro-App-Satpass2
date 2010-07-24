package App::Satpass2::Test;

use strict;
use warnings;

use Carp;

use Test::More 0.40 ();

sub new {
    my ( $class, $test_class ) = @_;
    ref $class and $class = ref $class;
    my $self = {
	test_class => $test_class,
    };
    bless $self, $class;
    return $self;
}

sub initialize_tested_object {
    my ( $self ) = @_;
    return $self->{test_obj};
}

sub plan {
    my ( $self, @args ) = @_;
    Test::More::plan( @args );
    return;
}

sub can_ok {
    my ( $self, $method ) = @_;
    @_ = ( $self->{test_class}, $method );
    goto &Test::More::can_ok;
}

sub diag {
    shift @_;
    goto &Test::More::diag;
}

sub method {
    my ( $self, $method, @args ) = @_;
    $self->{test_obj} or return;
    return $self->{test_obj}->$method( @args );
}

sub note {
    my $self = shift;
    goto &Test::More::note;
}

sub method_equals {
    my ( $self, $method, @args ) = @_;
    my $test_name = pop @args;
    my $want = pop @args;
    my $got;
SKIP:
    {
	$self->{test_obj}
	    or Test::More::skip(
		"Could not instantiate $self->{test_class}", 1 );
	if ( eval {
		$got = $self->{test_obj}->$method( @args );
		1;
	    } ) {
	    if ( ref $want ) {
		@_ = ( $got, $want, $test_name );
		goto &Test::More::is_deeply;
	    } else {
		@_ = ( $got, '==', $want, $test_name );
		goto &Test::More::cmp_ok;
	    }
	} else {
	    @_ = ( "$test_name: $@" );
	    goto &Test::More::fail;
	}
    }
    return;
}

sub method_fail {
    my ( $self, $method, @args ) = @_;
    my $test_name = pop @args;
    my $want = pop @args;
    ref $want or $want = qr{@{[ quotemeta $want ]}}smx;
SKIP:
    {
	$self->{test_obj}
	    or Test::More::skip(
		"Could not instantiate $self->{test_class}", 1 );
	if ( eval {
		$self->{test_obj}->$method( @args );
		1;
	    } ) {
	    @_ = ( "$test_name did not throw an exception" );
	    goto &Test::More::fail;
	} else {
	    @_ = ( $@, $want, $test_name );
	    goto &Test::More::like;
	}
    }
    return;
}

sub method_is {
    my ( $self, $method, @args ) = @_;
    my $test_name = pop @args;
    my $want = pop @args;
    my $got;
SKIP:
    {
	$self->{test_obj}
	    or Test::More::skip(
		"Could not instantiate $self->{test_class}", 1 );
	if ( eval {
		$got = $self->{test_obj}->$method( @args );
		1;
	    } ) {
	    @_ = ( $got, $want, $test_name );
	    if ( ref $want ) {
		goto &Test::More::is_deeply;
	    } else {
		defined $_[0] and chomp $_[0];
		defined $_[1] and chomp $_[1];
		goto &Test::More::is;
	    }
	} else {
	    @_ = ( "$test_name: $@" );
	    goto &Test::More::fail;
	}
    }
    return;
}

sub method_ok {
    my ( $self, $method, @args ) = @_;
    my $test_name = pop @args;
SKIP:
    {
	$self->{test_obj}
	    or Test::More::skip(
		"Could not instantiate $self->{test_class}", 1 );
	if ( my $got = eval {
		$self->{test_obj}->$method( @args );
		1;
	    } ) {
	    @_ = ( $got, $test_name );
	    goto &Test::More::ok;
	} else {
	    @_ = ( "$test_name: $@" );
	    goto &Test::More::fail;
	}
    }
    return;
}

sub new_ok {
    my ( $self, @args ) = @_;
    $self->{test_obj} = eval { $self->{test_class}->new( @args ) }
	or Test::More::diag( "Failed to instantiate $self->{test_class}: $@" );
    $self->initialize_tested_object();
    @_ = ( $self->{test_obj}, $self->{test_class} );
    goto &Test::More::isa_ok;
}

sub require_ok {
    my ( $self ) = @_;
    @_ = ( $self->{test_class} );
    goto &Test::More::require_ok;
}

sub skip {
    my $self = shift;
    goto &Test::More::skip;
}


1;

=head1 NAME

App::Satpass2::Test - Test App::Satpass2 classes

=head1 SYNOPSIS

 my $tst = App::Satpass2::Test->new( 'App::Satpass2' );
 $tst->plan( 'no_plan' );
 $tst->require_ok();
 $tst->can( 'new' );
 $tst->new_ok();

=head1 DETAILS

This class expedites the testing of classes in the C<App::Satpass2>
package. It wraps L<Test::More|Test::More> in an object-oriented
interface, with whatever additional support seemed convenient to add.

B<This class is private to the App::Satpass2 package>. This
documentation is solely for the author's benefit, and the author
reserves the right to make any conceivable change to the class,
including retracting it alltogether.

=head1 METHODS

The methods provided by this class break down into two kinds: test
methods and support methods. Because the support methods include
instantiation of the test class, they will be covered first.

=head2 Support Methods

These are the methods that do not actually perform tests. Some wrap the
same-named L<Test::More|Test::More> method; others provide other test
support.

=head3 diag

 $tst->diag( 'This test may fail for unknown reasons' );

This method simply wraps L<Test::More::diag|Test::More/diag>.

=head3 new

 my $tst = App::Satpass2::Test->new( 'App::Satpass2' );

This static method instantiates a new testing object. The argument is
the name of the class to be tested, and is required.

=head3 initialize_tested_object

This method should not be called by the user. It is intended for the use
of subclasses which wish to do initialization on the object to be tested
once it is instantiated by L<new_ok()|/new_ok>. This class'
implementation simply returns the tested object.

Overrides to this method B<must> call
C<< $self->SUPER::initialize_tested_object() >>
to obtain a reference to the object being tested. Overrides must return
this object to the caller.

=head3 method

 $tst->method( gmt => 1 );

This method simply calls a method on the object being tested. The first
argument is the name of the method to call, and subsequent arguments if
any are passed to that method. The results of the method will be
returned.

Attempts to call a non-existent method are not trapped, and will be
messily fatal. If L<new_ok()|/new_ok> has not yet been called, or if it
failed to instantiate an object, this method will simply return.

=head3 note

 $tst->note( 'First phase of test' );

This method simply wraps L<Test::More::note|Test::More/note>.

=head3 plan

 $tst->plan( tests => 42 );

This method simply wraps L<Test::More::plan|Test::More/plan>.

=head3 skip

 $tst->skip( "I'm afraid I can't do that, Dave.", 2001 );

This method simply wraps L<Test::More::skip|Test::More/skip>. Note that
to function properly it must be called in a block labelled C<SKIP:>.

=head2 Test Methods

Each of these methods performs a single test.

=head3 can_ok

 $tst->can_ok( 'new' );

This method tests whether the class being tested has the named method.
It will probably fail if the class has not been loaded.

In practice, this method simply delegates to
L<Test::More::can_ok|Test::More/can_ok>, passing the name of the class
being tested as the first argument, and the requested method as the
second argument.

=head3 method_fail

 $tst->method_fail( set => foo => 'bar',
     'Unknown attribute',
     "Make sure we do not have a 'foo' attribute" );

This method tests whether the given method throws an exception. The
first argument is the method name, the next-to-last argument is either a
string or a regular expression matching the expected exception, and the
last argument is the test name. Any arguments between the method name
and the expected exception are passed as arguments to the method.

If the expected exception is a string, it is run through C<quotemeta>
and then made into a regular expression.

If the given method in fact throws an exception, the exception, the
expected exception, and the test name are passed to
L<Test::More::like|Test::More/like>. If it does not, the test name is
passed to L<Test::More::fail|Test::More/fail>.

If L<new_ok()|/new_ok> has not been called, or if it failed, the test is
skipped.

=head3 method_is

 $tst->method_is( show => 'date_format', '%d-%b-%y',
     'Check current date format' );

This method calls a method on the test object in scalar context, and
tests the result of that method. The first argument is the name of the
method to call, the next-to-last argument is the expected result, and
the last argument is the test name.

If the method succeeds, the result, the expected result, and the test
name are passed to either L<Test::More::is|Test::More/is> (if the
expected result is not a reference) or
L<Test::More::is_deeply|Test::More/is_deeply> (if the expected result is
a reference). If the method fails, the test name and the exception are
concatenated and passed to L<Test::More::fail|Test::More/fail>.

If L<new_ok()|/new_ok> has not been called, or if it failed, the test is
skipped.

=head3 method_ok

 $tst->method_is( get => 'gmt', 'The gmt attribute is true' );

This method calls the given method on the test object in scalar context,
and tests whether the result is boolean true. The first argument is the
method name, the last argument is the test name, and any arguments in
between are passed to the method.

If the method succeeds, its result and the test name are passed to
L<Test::More::is|Test::More/is>. If it fails, the test name and the
exception are concatenated and passed to
L<Test::More::fail|Test::More/fail>.

=head3 new_ok

 $tst->new_ok();

This method instantiates the desired class by calling its C<new()>
method, calls
L<initialize_tested_object()|/initialize_tested_object>, and then passes
control to L<Test::More::isa_ok|Test::More/isa_ok> to make sure we got
the right class back.

Any arguments are passed to the tested class' C<new()> method.

If the instantiation failed, a diagnostic is issued containting the text
of the exception.

=head3 require_ok

 $tst->require_ok();

This method simply wraps
L<Test::More::require_ok|Test::More/require_ok>, passing it the name of
the class being tested.

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

__END__

# ex: set textwidth=72 :
