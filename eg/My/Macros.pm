package My::Macros;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2 };

use Astro::App::Satpass2::Utils qw{ __arguments };
use Astro::Coord::ECI::Utils qw{ rad2deg };

our $VERSION = '0.000_01';

sub angle : Verb( radians! places=i ) {
    my ( $self, $opt, $name1, $name2, $time ) = __arguments( @_ );
    $time = $self->__parse_time( $time, time );
    defined $name1
	and defined $name2
	or $self->wail( 'Two names or OIDs must be provided' );
    my @things = $self->__choose(
	{ bodies => 1, sky => 1 },
	[ $name1, $name2 ],
    );
    @things
	or $self->wail( 'No bodies chosen' );
    @things < 2
	and $self->wail( 'Only 1 body (',
	    $things[0]->get( 'name' ),
	    ') chosen' );
    @things > 2
	and $self->wail( scalar @things, ' bodies chosen' );
    my $station = $self->station()->universal( $time );
    foreach my $body ( @things ) {
	$body->universal( $time );
    }
    my $angle = $station->angle( @things );
    $opt->{radians}
    or $angle = rad2deg( $angle );
    defined $opt->{places}
	or return "$angle\n";
    return sprintf "%.*f\n", $opt->{places}, $angle;
}

sub hi : Verb() {
    my ( $self, $opt, $name ) =
	Astro::App::Satpass2::__arguments( @_ );
    defined $name
	or $name = 'world';
    return "Hello, $name!\n";
}

sub dumper : Verb() {
    my ( $self, @args ) = @_;
    use YAML;
    return ref( $self ) . "\n" . Dump( \@args );
}

1;

__END__

=head1 NAME

My::Macros - Implement 'macros' using code.

=head1 SYNOPSIS

The following assumes this file is actually findable in C<@INC>:

 satpass2> macro load My::Macros
 satpass2> hi Yehudi
 Hello, Yehudi!
 satpass2> angle sun moon -places 2
 102.12
 satpass2>

=head1 DESCRIPTION

This Perl package defines code macros for Astro::App::Satpass2. These
are implemented as subroutines, but do not appear as methods of
Astro::App::Satpass2. Nonetheless, they are defined and called the same
way an Astro::App::Satpass2 interactive method is called, and return
their results as text.

=head1 SUBROUTINES

This class supports the following public subroutines, which are
documented as though they are methods of Astro::App::Satpass2:

=head2 angle

 $output = $satpass2->dispatch( angle => 'sun', 'moon', 'today noon' );
 satpass2> angle sun moon 'today noon'

This subroutine computes and returns the angle between the two named
bodies at the given time. The time defaults to the current time.

The following options may be specified, either as command-line-style
options or in a hash as the second argument to C<dispatch()>:

=over

=item -places number

This option specifies the number of places to display after the decimal.
If it is specified, the number of degrees is formatted with C<sprintf>.
If not, it is simply interpolated into a string.

=item -radians

This option specifies that the angle is to be returned in radians.
Otherwise it is returned in degrees.

=back

=head2 dumper

 $output = $satpass2->dispatch( 'dumper', 'foo', 'bar' );
 satpass2> dumper foo bar

This subroutine is a diagnostic that displays the class name of its
first argument (which under more normal circumstances would be its
invocant), and a C<YAML> C<Dump()> of a reference to the array of
subsequent arguments.

There are no options.

=head2 hi

 $output = $satpass2->dispatch( 'hi', 'sailor' );
 satpass2> hi sailor
 Hello sailor!

This subroutine simply returns its optional argument C<$name> (which
defaults to C<'world'>) interpolated into the string
C<"Hello, $name\n">.

There are no options.

=head1 SEE ALSO

L<Astro::App::Satpass2|Astro::App::Satpass2>

L<Astro::App::Satpass2::Macro::Code|Astro::App::Satpass2::Macro::Code>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
