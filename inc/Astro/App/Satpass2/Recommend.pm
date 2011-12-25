package Astro::App::Satpass2::Recommend;

use strict;
use warnings;

use Carp;
use Config;

my ( $is_5_010, $is_5_012 );

eval {
    require 5.012;
    $is_5_012 = $is_5_010 = 1;
} or eval {
    require 5.010;
    $is_5_010 = 1;
};

sub recommend {
    my @recommend;
    my $pkg_hash = __PACKAGE__ . '::';
    no strict qw{ refs };
    foreach my $subroutine ( sort keys %$pkg_hash ) {
	$subroutine =~ m/ \A _recommend_ \w+ \z /smx or next;
	my $code = __PACKAGE__->can( $subroutine ) or next;
	defined( my $recommendation = $code->() ) or next;
	push @recommend, "\n" . $recommendation;
    }
    @recommend and warn <<'EOD', @recommend,

The following optional modules were not found:
EOD
    <<'EOD';

It is not necessary to install these now. If you decide to install them
later, this software will make use of them when it finds them.

EOD
    return;
}

sub _recommend_astro_simbad_client {
    local $@ = undef;
    eval { require Astro::SIMBAD::Client; 1 } and return;
    return <<'EOD';
    * Astro::SIMBAD::Client is not installed.
      This module is required for the 'lookup' subcommand of the
      Astro::App::Satpass2 sky() method, but is otherwise unused by this
      package. If you do not intend to use this functionality,
      Astro::SIMBAD::Client is not needed.
EOD
}

sub _recommend_astro_spacetrack {
    local $@ = undef;
    eval {
	require Astro::SpaceTrack;
	Astro::SpaceTrack->VERSION( 0.016 );
	1;
    } and return;
    return <<'EOD';
    * Astro::SpaceTrack version 0.016 or higher is not installed. This
      module is required for the Astro::App::Satpass2 st() method, but is
      otherwise unused by this package. If you do not intend to use this
      functionality, Astro::SpaceTrack is not needed.
EOD
}

sub _recommend_date_manip {
    local $@ = undef;
    eval { require Date::Manip; 1 } and return;
    my $recommendation = <<'EOD';
    * Date::Manip is not installed.
      This module is not required, but the alternative to installing it
      is to specify times in ISO 8601 format.  See 'SPECIFYING TIMES' in
      the 'Astro::App::Satpass2' documentation for the details.
EOD
    $is_5_010 or $recommendation .= <<'EOD';

      Unfortunately, the current Date::Manip requires Perl 5.10. Since
      you are running an earlier Perl, you can try installing Date-Manip
      5.54, which is the most recent version that does _not_ require
      Perl 5.10. This version of Date::Manip does not understand summer
      time (a.k.a. daylight saving time).
EOD
    return $recommendation;
}

sub _recommend_datetime {
    local $@ = undef;
    eval {
	require DateTime;
	require DateTime::TimeZone;
	1;
    } and return;
    return <<'EOD';
    * DateTime and/or DateTime::TimeZone are not installed.
      These modules are used to format times, and provide full time zone
      support. If they are not installed, POSIX::strftime() will be
      used, and you may find that you can not display correct local
      times for zones other than your system's default zone.
EOD
}

sub _recommend_geo_coder {
    local $@ = undef;
    eval { require Geo::Coder::Geocoder::US; 1 }
	or eval { require Geo::Coder::OSM; 1 }
	or eval { require Geo::Coder::TomTom; 1 }
	or return <<'EOD';
    * None of Geo::Coder::Geocoder::US, Geo::Coder::OSM, or
      Geo::Coder::TomTom is installed.
      One of these modules is required by the Astro::App::Satpass2
      geocode() method, but they are otherwise unused by this package.
      If you do not intend to use this functionality, these modules are
      not needed. Basically:

      Geo::Coder::Geocoder::US uses http://geocoder.us/, covers only the
          USA, and can only be queried once every 15 seconds;

      Geo::Coder::OSM uses Open Street Map, whose coverage is better in
          Europe than the USA;

      Geo::Coder::TomTom has the best coverage, but uses an undocumented
          and unsupported interface.
EOD
    return;
}

sub _recommend_geo_webservice_elevation_usgs {
    local $@ = undef;
    eval { require Geo::WebService::Elevation::USGS; 1 } and return;
    return <<'EOD';
    * Geo::WebService::Elevation::USGS is not installed.
      This module is required for the Astro::App::Satpass2 height()
      method, but is otherwise unused by this package. If you do not
      intend to use this functionality, Geo::WebService::Elevation::USGS
      is not needed.
EOD
}

sub _recommend_lwp_useragent {
    local $@ = undef;
    eval {
	require LWP::UserAgent;
	require URI::URL;
	1;
    } and return;
    return <<'EOD';
    * LWP::UserAgent and/or URI::URL are not installed.
      These modules are required if you want to use URLs in the init(),
      load(), or source() methods. If you do not intend to use URLs
      there, you do not need these packages. Both packages are
      requirements for most of the other Internet-access functionality,
      so you may get them implicitly if you install some of the other
      modules.
EOD
}

sub _recommend_time_hires {
    local $@ = undef;
    eval { require Time::HiRes; 1 } and return;
    return <<'EOD';
    * Time::HiRes is not installed.
      This module is required for the Astro::App::Satpass2 time()
      method, but is otherwise unused by this package. If you do not
      intend to use this functionality, Time::HiRes is not needed.
EOD
}

{

    my %misbehaving_os = map { $_ => 1 } qw{ MSWin32 cygwin };

    # NOTE WELL
    #
    # The description here must match the actual time module loading and
    # exporting logic in Astro::Coord::ECI::Utils.

    sub _recommend_time_y2038 {
	eval { require Time::y2038; 1 } and return;
	$is_5_012 and return;	# Perl 5.12 is Y2038-compliant.
	my $recommendation = <<'EOD';
    * Time::y2038 is not installed.
      This module is not required, but if installed allows you to do
      computations for times outside the usual range of system epoch to
      system epoch + 0x7FFFFFFF seconds.
EOD
	$misbehaving_os{$^O} and $recommendation .= <<"EOD";
      Unfortunately, Time::y2038 has been known to misbehave when
      running under $^O, so you may be better off just accepting the
      restricted time range.
EOD
	( $Config{use64bitint} || $Config{use64bitall} )
	    and $recommendation .= <<'EOD';
      Since your Perl appears to support 64-bit integers, you may well
      not need Time::y2038 to do computations for times outside the
      so-called 'usual range.' Time::y2038 will be used, though, if it
      is available.
EOD
	return $recommendation;
    }

}

1;

=head1 NAME

Astro::Coord::ECI::Recommend - Recommend modules to install. 

=head1 SYNOPSIS

 use lib qw{ inc };
 use Astro::Coord::ECI::Recommend;
 Astro::Coord::ECI::Recommend->recommend();

=head1 DETAILS

This package generates the recommendations for optional modules. It is
intended to be called by the build system. The build system's own
mechanism is not used because we find its output on the Draconian side.

=head1 METHODS

This class supports the following public methods:

=head2 recommend

 Astro::Coord::ECI::Recommend->recommend();

This static method examines the current Perl to see which optional
modules are installed. If any are not installed, a message is printed to
standard out explaining the benefits to be gained from installing the
module, and any possible problems with installing it.

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
