package App::Satpass2::FormatTime::DateTime::Cldr;

use 5.006002;

use strict;
use warnings;

use base qw{
    App::Satpass2::FormatTime::DateTime
    App::Satpass2::FormatTime::Cldr
};

use App::Satpass2::Copier qw{ __instance };
use Carp;
use DateTime;
use DateTime::TimeZone;
use POSIX ();

our $VERSION = '0.000_07';

sub __format_datetime {
    my ( $self, $object, $tplt ) = @_;
    return $object->format_cldr( $tplt );
}

1;

__END__

=head1 NAME

App::Satpass2::FormatTime::DateTime::Cldr - Format time using DateTime->format_cldr()

=head1 SYNOPSIS

 use App::Satpass2::FormatTime::DateTime::Cldr;
 my $tf = App::Satpass2::FormatTime::DateTime::Cldr->new();
 print 'It is now ',
     $tf->format_datetime( 'HH:mm:SS', time, 1 ),
     " GMT\n";

=head1 NOTICE

This class and its subclasses are private to the
L<App::Satpass2|App::Satpass2> package. The author reserves the right to
add, change, or retract functionality without notice.

=head1 DETAILS

This subclass of
L<App::Satpass2::FormatTime::DateTime|App::Satpass2::FormatTime::DateTime>
formats times using C<DateTime->format_cldr()>. Time zones other than the
default local zone are handled using
L<DateTime::TimeZone|DateTime::TimeZone> objects.

All this class really provides is the interface to
C<< DateTime->format_cldr() >>. Everything else is inherited.

=head1 METHODS

This class provides no public methods over and above those provided by
L<App::Satpass2::FormatTime::DateTime|App::Satpass2::FormatTime::DateTime>
and
L<App::Satpass2::FormatTime::Strftime|App::Satpass2::FormatTime::Strftime>.

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

# ex: set textwidth=72 :
