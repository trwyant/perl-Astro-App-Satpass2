package Astro::App::Satpass2::Warner;

use 5.008;

use strict;
use warnings;

use Carp;

our @CARP_NOT = ( qw{
    Astro::App::Satpass2
    Astro::App::Satpass2::Format
    Astro::App::Satpass2::Format::Dump
    Astro::App::Satpass2::Format::Template
    Astro::App::Satpass2::FormatTime::DateTime
    Astro::App::Satpass2::FormatValue
    Astro::App::Satpass2::Geocode
    Astro::App::Satpass2::Geocode::Geocoder::US
    Astro::App::Satpass2::Geocode::OSM
    Astro::App::Satpass2::Geocode::TomTom
    Astro::App::Satpass2::ParseTime::Date::Manip::v5
    Astro::App::Satpass2::ParseTime::Date::Manip::v6
    Astro::App::Satpass2::ParseTime::ISO8601
} );

our $VERSION = '0.000_37';

sub new {
    my ( $class, @arg ) = @_;
    ref $class and $class = ref $class;
    my $self = {};
    bless $self, $class;
    while ( @arg ) {
	my ( $name, $value ) = splice @arg, 0, 2;
	my $code = $self->can( $name )
	    or $self->wail( "Warner has no such method as $name" );
	$self->$name( $value );
    }
    return $self;
}

sub wail {
    my ($self, @args) = @_;
    my $msg = join '', @args;
    chomp $msg;
    if ($self->warning()) {
	$msg =~ m/[.?!]\z/msx or $msg .= '.';
	die $msg, "\n";
    } else {
	$msg =~ s/[.?!]\z//msx;
	croak $msg;
    }
}

sub warning {
    my ( $self, @arg ) = @_;
    if ( @arg ) {
	$self->{warning} = shift @arg;
	return $self;
    } else {
	return $self->{warning};
    }
}

sub whinge {
    my ($self, @args) = @_;
    my $msg = join '', @args;
    chomp $msg;
    if ($self->warning()) {
	$msg =~ m/ [.?!] \z /msx or $msg .= '.';
	warn $msg, "\n";
    } else {
	$msg =~ s/ [.?!] \z //msx;
	carp $msg;
    }
    return;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Warner - Output warning and error messages

=head1 SYNOPSIS

 use Astro::App::Satpass2::Warner

 my $warner = Astro::App::Satpass2::Warner->new();
 $warner->whinge( 'This is a warning, or a carp' );
 $warner->wail( 'This is a die, or a croak' );

=head1 DESCRIPTION

This class is private to the C<Astro::App::Satpass2> package. The author
reserves the right to modify or revoke it without notice. The
documentation is purely for the benefit of the author.

This class manages the reporting of error messages, generating them by
either C<warn> and c<die>, or C<carp> and C<croak> as the user desires.
If the C<warn> attribute is true, you get C<warn> or C<die>. If false,
you get C<carp> or C<croak>.

=head1 METHODS

This class supports the following public methods:

=head2 new

This static method instantiates an C<Astro::App::Satpass2::Warner>
object. It takes as arguments name/value pairs which will be passed to
the relevant subroutine. It is probably only useful to set C<warning>.

=head2 wail

This method concatenates all its arguments, and passes them to C<die>
(if the C<warn> attribute is true) or C<croak> (if the C<warn> attribute
is false).

=head2 warning

If called without an argument, this method returns the value of the
C<warning> attribute. If called with an argument, it sets the value of
the C<warning> attribute.

The initial value of the attribute is false.

=head2 whinge

This method concatenates all its arguments, and passes them to C<warn>
(if the C<warn> attribute is true) or C<carp> (if the C<warn> attribute
is false).


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
