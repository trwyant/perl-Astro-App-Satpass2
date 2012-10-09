package Astro::App::Satpass2::Geocode::OSM;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Geocode };

use Astro::App::Satpass2::Utils qw{ instance };

our $VERSION = '0.009';

use constant GEOCODER_CLASS => 'Geo::Coder::OSM';

use constant GEOCODER_SITE => 'http://nominatim.openstreetmap.org/';

sub geocode {
    my ( $self, $loc ) = @_;

    my $geocoder = $self->geocoder();

    if ( my @rslt = $geocoder->geocode( location => $loc ) ) {
	return (
	    map {
		{
##		    country		=> uc $_->{address}{country_code},
		    description	=> _description( $_ ),
		    latitude	=> $_->{lat},
		    longitude	=> $_->{lon},
		}
	    } @rslt );
    } else {
	return $self->__geocode_failure();
    }

}

sub _description {
    my ( $info ) = @_;
    my $desc = $info->{display_name};
    $desc =~ s/ [^,]+ , \s* //smx;
    $desc =~ s/ \A ( \d+ ) , /$1/smx;	# Oh, for 5.10 and \K
    return $desc;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Geocode::OSM - Wrapper for Geo::Coder::OSM

=head1 SYNOPSIS

 use Astro::App::Satpass2::Geocode::OSM;
 use YAML;
 
 my $gc = Astro::App::Satpass2::Geocode::OSM->new();
 print Dump( $gc->geocode( '10 Downing St, London England' );

=head1 DESCRIPTION

This class wraps the L<Geo::Coder::OSM|Geo::Coder::OSM> module,
to provide a consistent interface to
L<Astro::App::Satpass2|Astro::App::Satpass2>.

This class is a subclass of
L<Astro::App::Satpass2::Geocode|Astro::App::Satpass2>.

=head1 METHODS

This class provides no public methods in addition to those provided by
its superclass. However, it overrides the following methods:

=head2 geocode

The data returned by L<Geo::Coder::OSM|Geo::Coder::OSM> are mapped to
data returned by this method as follows:

 description - comes from {display_name};
 latitude ---- comes from {lat};
 longitude --- comes from {lon}.

=head2 GEOCODER_CLASS

This returns C<'Geo::Coder::OSM'>.

=head2 GEOCODER_SITE

This returns C<'http://nominatim.openstreetmap.org/'>.

=head1 SEE ALSO

L<Geo::Coder::OSM|Geo::Coder::OSM> for the details on the heavy
lifting.

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
