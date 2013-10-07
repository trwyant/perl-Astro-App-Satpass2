package Astro::App::Satpass2::FormatTime;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Copier };

our $VERSION = '0.013_02';

my $delegate = eval {
    require Astro::App::Satpass2::FormatTime::DateTime::Strftime;
    'Astro::App::Satpass2::FormatTime::DateTime::Strftime';
} || do {
    require Astro::App::Satpass2::FormatTime::POSIX::Strftime;
    'Astro::App::Satpass2::FormatTime::POSIX::Strftime';
};

sub new {
    my ( $class, @args ) = @_;
    ref $class and $class = ref $class;

    __PACKAGE__ eq $class and $class = $delegate;

    my $self = {};
    bless $self, $class;
    return $self;
}

sub attribute_names {
    return ( qw{ gmt tz } );
}

sub format_datetime {	## no critic (RequireFinalReturn)
    my ( $self ) = @_;
    # ->weep() throws an exception.
    $self->warner()->weep(
	'Method format_datetime() must be overridden' );
}

{

    my %cache;

    sub format_datetime_width {
	my ( $self, $tplt ) = @_;

	my $class = ref $self;

	exists $cache{$class}{$tplt}
	    and return $cache{$class}{$tplt};

	my ( $time, $wid ) = $self->_format_datetime_width_try( $tplt, undef,
	    year => 2100 );
	( $time, $wid ) = $self->_format_datetime_width_try( $tplt, $time,
	    month => 1 .. 12 );
	( $time, $wid ) = $self->_format_datetime_width_try( $tplt, $time,
	    day => 1 .. 7 );
	( $time, $wid ) = $self->_format_datetime_width_try( $tplt, $time,
	    hour => 6, 18 );

	return ( $cache{$class}{$tplt} = $wid );
    }

}

sub _format_datetime_width_try {
    my ( $self, $tplt, $time, $name, @try ) = @_;
    my $wid;
    my $max_trial;
    foreach my $trial ( @try ) {
	$time = $self->__format_datetime_width_adjust_object(
	    $time, $name, $trial );
	my $size = length $self->format_datetime( $tplt, $time );
	defined $wid and $size <= $wid and next;
	$wid = $size;
	$max_trial = $trial;
    }
    $time = $self->__format_datetime_width_adjust_object( $time, $name, $max_trial );
    return ( $time, $wid );
}

__PACKAGE__->create_attribute_methods();


1;

__END__

=head1 NAME

Astro::App::Satpass2::FormatTime - Format time for output.

=head1 SYNOPSIS

 use Astro::App::Satpass2::FormatTime;
 my $ft = Astro::App::Satpass2::FormatTime->new();
 print 'The time is ', $ft->format_datetime( '%H:%M:%S', time );

=head1 NOTICE

This class and its subclasses are private to the
L<Astro::App::Satpass2|Astro::App::Satpass2> package. The author reserves the right to
add, change, or retract functionality without notice.

=head1 DETAILS

This class abstracts time formatting for Astro::App::Satpass2.

=head1 METHODS

This class supports the following public methods in addition to those
inherited from L<Astro::App::Satpass2::Copier|Astro::App::Satpass2::Copier>.

=head2 new

 my $ft = Astro::App::Satpass2::FormatTime->new();

This method instantiates a time formatter object.

=head2 gmt

 $ft->gmt ( 1 );
 print 'The gmt attribute is ', $ft->gmt() ? "true\n" : "false\n";

This method is both accessor and mutator for the C<gmt> attribute. This
boolean attribute provides a default for the C<gmt> argument of
L<format_datetime()|/format_datetime>.

If called with an argument, the argument becomes the new value of the
C<gmt> attribute. The object is returned to allow call chaining.

If called without an argument, the current value of the C<gmt> attribute
is returned.

=head2 format_datetime

 print 'Time now: ', $ft->format_datetime( '%H:%M:%S', time, 0 ), "\n";

This attribute uses the format passed in the first argument to format
the Perl time passed in the second argument. The third argument, if
defined, overrides the L<gmt|/gmt> attribute, forcing the time to be GMT
if true, or local if false.

The string representing the formatted time is returned.

This method C<must> be overridden by the subclass. The override C<may>
use the value of the L<tz|/tz> attribute to format the local time in the
given zone, provided the value of L<tz|/tz> is defined and not C<''>.
The override C<may> accept times in formats other than Perl epoch, but
it need not document or support these.

=head2 format_datetime_width

 my $wid = $ft->format_datetime_width( '%H:%M:%S' );

This method computes the maximum width required to display a time in the
given format. This is done by assuming only the month, day, and meridian
might affect the width, and then trying each and returning the width of
the widest.

=head2 __format_datetime_width_adjust_object

 my $ref = $self->__format_datetime_width_adjust_object( undef, year => 2100 );

This method B<must> be overridden by the subclass.  It exists to support
L<format_datetime_width()|/format_datetime_width>, and should not be
called directly.  It is not itself supported, in the sense that the
author reserves the right to change or revoke it without notice. Though
since this whole mess is unsupported in that sense, this statement is
redundant.

This method takes as its arguments a time in any format supported by the
L<format_datetime()|/format_datetime> method, the name of a component
(C<year>, C<month>, C<day>, C<hour>, C<minute>, or C<second>), and a
value for that component. The time is returned with the given component
set to the given value. If the time is C<undef>, a new time representing
C<01-Jan-2100 00:00:00> is constructed, adjusted, and returned.

=head2 tz

 $ft->tz( 'mst7mdt' );
 print 'Current zone: ', $ft->tz(), "\n";

This method is both accessor and mutator for the time zone, maintained
on behalf of the subclass. If the subclass overrides this, it B<must>
call SUPER::tz with the same arguments.

If called with an argument, the argument becomes the new zone, with
either C<''> or C<undef> representing the default zone. The object is
returned to allow call chaining.

If called without an argument, the current value of the C<tz> attribute
is returned.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
