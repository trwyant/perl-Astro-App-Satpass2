package Astro::App::Satpass2::Test::Format;

use strict;
use warnings;

use Carp;

use lib qw{ inc };

use base qw{ Astro::App::Satpass2::Test };

sub initialize_tested_object {
    my ( $self ) = @_;
    if ( my $obj = $self->SUPER::initialize_tested_object() ) {
	$obj->gmt( 1 );
	$obj->can( 'provider' ) and $obj->provider( __PACKAGE__ );
    }
    return $self;
}

sub format_fail {
    my ( $self, $template, $want, $test_name ) = @_;
    $self->method( template => $self->{+__PACKAGE__}{template},
	$template );
    @_ = ( $self, $self->{+__PACKAGE__}{method}, @{
	    $self->{+__PACKAGE__}{args} }, $want, $test_name );
    goto &Astro::App::Satpass2::Test::method_fail;
}

sub format_is {
    my ( $self, $template, $want, $test_name ) = @_;
    $self->method( template => $self->{+__PACKAGE__}{template},
	$template );
    @_ = ( $self, $self->{+__PACKAGE__}{method}, @{
	    $self->{+__PACKAGE__}{args} }, $want, $test_name );
    goto &Astro::App::Satpass2::Test::method_is;
}

sub format_setup {
    my ( $self, $template, $method, @args ) = @_;
    $self->{+__PACKAGE__}{template} = $template;
    $self->{+__PACKAGE__}{method} = $method;
    $self->{+__PACKAGE__}{args} = \@args;
    return;
}

1;

=head1 NAME

Astro::App::Satpass2::Test::Format - Test Astro::App::Satpass2::Format classes

=head1 SYNOPSIS

 my $tst = Astro::App::Satpass2::Test::Format->new(
     'Astro::App::Satpass2::Format::Classic' );
 $tst->plan( 'no_plan' );
 $tst->require_ok();
 $tst->can( 'new' );
 $tst->format_setup( position => position => {
     body => $moon,
     station => $station,
 } );
 $tst->format_is( '%-azimuth', '42', 'Azimuth of Moon' );
 $tst->format_fail( '%space(station)', 'is forbidden',
     '%space does not take the (station) argument' );

=head1 DETAILS

This class expedites the testing of classes in the
C<Astro::App::Satpass2::Format> package. It subclasses
L<Astro::App::Satpass2::Test|Astro::App::Satpass2::Test>, overriding and adding
methods as convenient.

B<This class is private to the Astro::App::Satpass2 package>. This
documentation is solely for the author's benefit, and the author
reserves the right to make any conceivable change to the class,
including retracting it alltogether.

=head1 METHODS

The methods provided by this class break down into two kinds: test
methods and support methods. Because the support methods include
instantiation of the test class, they will be covered first.

All methods whose names begin with C<format_> assume that the formatter
object has a C<template()> method which takes a template name and value,
and which controls the formatting. Using these on a class which does not
have a C<template()> method will cause your test to die horribly.

Consequently the examples for the C<format_> methods do 

=head2 Support Methods

These are the methods that do not actually perform tests. Some wrap the
same-named L<Test::More|Test::More> method; others provide other test
support.

=head3 initialize_tested_object

 $tst->initialize_tested_object();

This method must not be called by the user. It overrides the superclass'
method of the same name, to modify the default values of the
C<date_format>, C<gmt>, and C<provider> attributes to C<'%Y/%m/%d'>,
C<1>, and the name of this package respectively.

=head3 format_setup

 $tst->format_setup( pass => pass => $pass_data );

This method performs setup for the C<format_> methods which actually
perform tests. The first argument is the name of the template to be
modified, the second argument is the name of the formatting method to
call, and subsequent arguments are passed to the formatting method.

=head2 Test Methods

Each of these methods performs a single test.

=head3 format_fail

 $tst->format_fail( '%space(station)', 'is forbidden',
     '%space does not take the (station) argument' );

This convenience method sets the template named in the first argument of
the previous L<format_setup()|/format_setup> call to the value of the
first argument, then delegates the rest of its functionality to
L<< $tst->method_fail()|Astro::App::Satpass2::Test/method_fail >>, passing it the
method name and arguments specified in the previous call to
L<format_setup()|/format_setup>, and the expected error and test name
passed in this method's second and third arguments.

=head3 format_is

 $tst->format_is( '%-azimuth', '42', 'Azimuth of Moon' );

This convenience method sets the template named in the first argument of
the previous L<format_setup()|/format_setup> call to the value of the
first argument, then delegates the rest of its functionality to L<<
$tst->method_is()|Astro::App::Satpass2::Test/method_is >>, passing it the method
name and arguments specified in the previous call to
L<format_setup()|/format_setup>, and the expected result and test name
passed in this method's second and third arguments.

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

__END__

# ex: set textwidth=72 :
