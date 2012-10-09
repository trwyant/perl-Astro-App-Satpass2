package Astro::App::Satpass2::Geocode::TomTom;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Geocode };

use Astro::App::Satpass2::Utils qw{ instance };

our $VERSION = '0.009';

use constant GEOCODER_CLASS => 'Geo::Coder::TomTom';

use constant GEOCODER_SITE => 'http://routes.tomtom.com/';

sub geocode {
    my ( $self, $loc ) = @_;

    my $geocoder = $self->geocoder();

    if ( my @rslt = $geocoder->geocode( location => $loc ) ) {
	@rslt = sort { $a->{score} <=> $b->{score} } @rslt;
	my $top = $rslt[-1]{score};
	@rslt = grep { $_->{score} >= $top } @rslt;
	return (
	    map {
		{
##		    country	=> uc $_->{countryISO3},
		    description	=> $_->{formattedAddress},
		    latitude	=> $_->{latitude},
		    longitude	=> $_->{longitude},
		}
	    } @rslt );
    } else {
	return $self->__geocode_failure();
    }

}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Geocode::TomTom - Wrapper for Geo::Coder::TomTom

=head1 SYNOPSIS

 use Astro::App::Satpass2::Geocode::TomTom;
 use YAML;
 
 my $gc = Astro::App::Satpass2::Geocode::TomTom->new();
 print Dump( $gc->geocode( '1600 Pennsylvania Ave, Washington DC' );

=head1 DESCRIPTION

This class wraps the L<Geo::Coder::TomTom|Geo::Coder::TomTom> module,
to provide a consistent interface to
L<Astro::App::Satpass2|Astro::App::Satpass2>.

This class is a subclass of
L<Astro::App::Satpass2::Geocode|Astro::App::Satpass2>.

=head1 METHODS

This class provides no public methods in addition to those provided by
its superclass. However, it overrides the following methods:

=head2 geocode

The results returned by the TomTom service include a relevance score.
Since we're only doing ad-hoc geocoding, we retain only the results with
the highest score. The data returned by
L<Geo::Coder::TomTom|Geo::Coder::TomTom> are mapped to data returned by
this method as follows:

 description - comes from {formattedAddress};
 latitude ---- comes from {latitude};
 longitude --- comes from {longitude}.

=head2 GEOCODER_CLASS

This returns C<'Geo::Coder::TomTom'>.

=head2 GEOCODER_SITE

This returns C<'http://routes.tomtom.com/'>;

=head1 SEE ALSO

L<Geo::Coder::TomTom|Geo::Coder::TomTom> for the details on the heavy
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
