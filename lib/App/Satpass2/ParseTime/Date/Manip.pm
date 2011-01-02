package App::Satpass2::ParseTime::Date::Manip;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_07';

my $delegate;

eval {	## no critic (RequireCheckingReturnValueOfEval)
    require Date::Manip;
    my $ver = Date::Manip->VERSION();
    $ver =~ s/ _ //smxg;
    if ( $ver < 6 ) {
	$delegate = __PACKAGE__ . '::v5';
    } else {
	$delegate = __PACKAGE__ . '::v6';
    }
};

sub delegate {
    return $delegate;
}

1;

=head1 NAME

App::Satpass2::ParseTime::Date::Manip - Parse time for App::Satpass2 using Date::Manip

=head1 SYNOPSIS

 my $delegate = App::Satpass2::ParseTime::Date::Manip->delegate();

=head1 DETAILS

This class is simply a trampoline for
L<< App::Satpass2::ParseTime->new()|App::Satpass2::ParseTime/new >> to
determine which Date::Manip class to use.

=head1 METHODS

This class supports the following public methods:

=head2 delegate

 my $delegate = App::Satpass2::ParseTime::Date::Manip->delegate();

This static method returns the class that should be used based on which
version of L<Date::Manip|Date::Manip> could be loaded. If
C<< Date::Manip->VERSION() >> returns a number less than 6,
'L<App::Satpass2::ParseTime::Date::Manip::v5|App::Satpass2::ParseTime::Date::Manip::v5>'
is returned. If it returns 6 or greater,
'L<App::Satpass2::ParseTime::Date::Manip::v6|App::Satpass2::ParseTime::Date::Manip::v6>'
is returned. If L<Date::Manip|Date::Manip> can not be loaded, C<undef>
is returned.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :

1;

=head1 NAME

App::Satpass2::ParseTime::Date::Manip - <<< replace boilerplate >>>

=head1 SYNOPSIS

<<< replace boilerplate >>>

=head1 DETAILS

<<< replace boilerplate >>>

=head1 METHODS

This class supports the following public methods:

=head1 ATTRIBUTES

This class has the following attributes:


=head1 SEE ALSO

<<< replace or remove boilerplate >>>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
