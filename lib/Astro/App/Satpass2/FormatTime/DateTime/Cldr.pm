package Astro::App::Satpass2::FormatTime::DateTime::Cldr;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::FormatTime::DateTime };

use Astro::App::Satpass2::FormatTime::Cldr;
use DateTime;
use DateTime::TimeZone;
use POSIX ();

our $VERSION = '0.031';

# So superclass can ducktype the object that does the real work.
use constant METHOD_USED => 'format_cldr';

sub __format_datetime {
    my ( undef, $date_time, $tplt ) = @_;		# Invocant unused
    my $quoted = 0;
    my $rslt;
    foreach my $elem ( split qr{ ( ' ) }smx, $tplt ) {
	if ( q<'> eq $elem ) {
	    $quoted = ! $quoted;
	} elsif ( $quoted ) {
	    $elem =~ s/ %[{] ( \w+ ) [}] / _expand( $date_time, "$1" ) /smxge;
	}
	$rslt .= $elem;
    }
    return $date_time->format_cldr( $rslt );
}

{
    my %handler = (
	calendar_name	=> sub {
	    my ( $date_time ) = @_;
	    my $code;
	    $code = $date_time->can( 'is_julian' )
		and $code->( $date_time )
		and return 'Julian';
	    return 'Gregorian';
	},
    );

    sub _expand {
	my ( $date_time, $name ) = @_;
	my $code;
	$code = ( $handler{$name} || $date_time->can( $name ) )
	    and return $code->( $date_time );
	return "%{$name}";
    }
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::FormatTime::DateTime::Cldr - Format time using DateTime->format_cldr()

=head1 SYNOPSIS

 use Astro::App::Satpass2::FormatTime::DateTime::Cldr;
 my $tf = Astro::App::Satpass2::FormatTime::DateTime::Cldr->new();
 print 'It is now ',
     $tf->format_datetime( 'HH:mm:SS', time, 1 ),
     " GMT\n";

=head1 NOTICE

This class and its subclasses are private to the
L<Astro::App::Satpass2|Astro::App::Satpass2> package. The author reserves the right to
add, change, or retract functionality without notice.

=head1 DETAILS

This subclass of
L<Astro::App::Satpass2::FormatTime::DateTime|Astro::App::Satpass2::FormatTime::DateTime>
formats times using C<< DateTime->format_cldr() >>. Time zones other
than the default local zone are handled using
L<DateTime::TimeZone|DateTime::TimeZone> objects.

All this class really provides is the interface to
C<< DateTime->format_cldr() >>. Everything else is inherited.

As an enhancement (I hope!) to the L<DateTime|DateTime> C<cldr>
functionality, this module, before calling C<format_cldr()>, examines
all embedded literals in the template, replacing C</%{(\w+)}/> with the
result of the named special-case code (if any), or the results of the
named L<DateTime|DateTime> method (if any). If neither special-case code
nor method exist, the matching string is left as-is.

The following special cases are implemented:

=over

=item calendar_name

This will be either C<'Gregorian'> or C<'Julian'>.

=back

Using this formatter with Julian dates enabled (i.e. with
L<DateTime::Calendar::Christian|DateTime::Calendar::Christian> doing the
heavy lifting) is B<unsupported>, because 
L<DateTime::Calendar::Christian|DateTime::Calendar::Christian> lacks
some of the methods you might want it to have, including
C<format_cldr()>. This package checks for the following methods when it
loads L<DateTime::Calendar::Christian|DateTime::Calendar::Christian>,
and patches them in if they are not there:

    christian_era()
    era()
    era_abbr()
    era_name()
    format_cldr()
    secular_era()
    year_with_era()
    year_with_christian_era()
    year_with_secular_era()

This is unsupported not only because it is tinkering with somebody
else's name space, but because the patches rely on knowing the internals
of L<DateTime::Calendar::Christian|DateTime::Calendar::Christian>, which
may change without warning. I<Caveat coder.>

=head1 METHODS

This class provides no public methods over and above those provided by
L<Astro::App::Satpass2::FormatTime::DateTime|Astro::App::Satpass2::FormatTime::DateTime>
and
L<Astro::App::Satpass2::FormatTime::Strftime|Astro::App::Satpass2::FormatTime::Strftime>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2016 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
