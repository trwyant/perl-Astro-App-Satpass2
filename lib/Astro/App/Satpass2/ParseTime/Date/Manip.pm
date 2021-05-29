package Astro::App::Satpass2::ParseTime::Date::Manip;

use strict;
use warnings;

use parent qw{ Astro::App::Satpass2::ParseTime };

use Astro::App::Satpass2::Utils qw{
    back_end
    load_package
    __date_manip_backend
    __parse_class_and_args
    @CARP_NOT
};

our $VERSION = '0.047_005';

sub __class_name {
    return __PACKAGE__;
}

sub attribute_names {
    my ( $self ) = @_;
    return ( $self->SUPER::attribute_names(), qw{ back_end station } );
}

sub delegate {
    my $back_end;
    defined ( $back_end = __date_manip_backend() )
	or return $back_end;
    return __PACKAGE__ . "::v$back_end";
}

sub station {
    my ( $self, @args ) = @_;
    if ( @args > 0 ) {
	not defined $args[0]
	    or $args[0]->isa( 'Astro::Coord::ECI' )
	    or $self->wail( 'Station must be an Astro::Coord::ECI' );
	$self->{station} = $args[0];
	if ( my $dm = $self->_get_dm_field( 'object' ) ) {
	    # NOTE that we have no way to introspect Date::Manip to see
	    # if it has the 'location' config, so since Date::Manip uses
	    # warn() to report errors, we just blindly set it and
	    # swallow the possible warning.
	    local $SIG{__WARN__} = sub {};
	    $dm->config( location => $args[0] );
	}
	return $self;
    }
    return $self->{station};
}

sub __back_end_default {
    my ( undef, $cls ) = @_;
    return defined $cls ? $cls : 'Date::Manip::Date';
}

sub __back_end_validate {
    my ( $self, $cls ) = @_;
    $cls->isa( 'Date::Manip::Date' )
	or $self->wail( "$cls is not a Date::Manip::Date" );
    return;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::ParseTime::Date::Manip - Parse time for Astro::App::Satpass2 using Date::Manip

=head1 SYNOPSIS

 my $delegate = Astro::App::Satpass2::ParseTime::Date::Manip->delegate();

=head1 DETAILS

This class is simply a trampoline for
L<< Astro::App::Satpass2::ParseTime->new()|Astro::App::Satpass2::ParseTime/new >> to
determine which Date::Manip class to use.

=head1 METHODS

This class supports the following public methods:

=head2 back_end

 $pt->back_end( 'Date::Manip::Date' );
 my $back_end = $pt->back_end();

This method is both accessor and mutator for the object's back end class
name. This class must be a subclass of
L<Date::Manip::Date|Date::Manip::Date>.

=head2 delegate

 my $delegate = Astro::App::Satpass2::ParseTime::Date::Manip->delegate();

This static method returns the class that should be used based on which
version of L<Date::Manip|Date::Manip> could be loaded. If
C<< Date::Manip->VERSION() >> returns a number less than 6,
'L<Astro::App::Satpass2::ParseTime::Date::Manip::v5|Astro::App::Satpass2::ParseTime::Date::Manip::v5>'
is returned. If it returns 6 or greater,
'L<Astro::App::Satpass2::ParseTime::Date::Manip::v6|Astro::App::Satpass2::ParseTime::Date::Manip::v6>'
is returned. If L<Date::Manip|Date::Manip> can not be loaded, C<undef>
is returned.

=head2 station

 $pt->station( $satpass2->station() );
 my $station = $pt->station();

This method is both accessor and mutator for the object's station
attribute. This must be an L<Astro::Coord::ECI|Astro::Coord::ECI>
object, or C<undef>.

This attribute is used to set the back end's C<location> config item. If
the back end does not have this config item, the fact is ignored --
silently, with any luck.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-App-Satpass2>,
L<https://github.com/trwyant/perl-Astro-App-Satpass2/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2021 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
