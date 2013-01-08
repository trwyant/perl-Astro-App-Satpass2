package Astro::App::Satpass2::Build;

use strict;
use warnings;

use base qw{ Module::Build };

use Carp;
use File::Spec;

my @optionals_dir = qw{ xt author optionals };
my @hide = qw{
    Astro::SIMBAD::Client Astro::SpaceTrack
    Date::Manip DateTime DateTime::TimeZone
    Geo::Coder::Geocoder::US Geo::Coder::OSM Geo::Coder::TomTom
    Geo::WebService::Elevation::USGS
    LWP::UserAgent
    LWP::Protocol
    Time::HiRes Time::y2038
    URI
};

{
    my $done;
    my $hider;

    sub _get_hider {
	$done and return $hider;
	$done = 1;
	# Not using Devel::Hide any more because it does not have a
	# public interface to say if a module is hidden.
	foreach my $module (
		'Test::Without::Module',
#		'Devel::Hide',
	    ) {
	    eval "require $module; 1"
		and return ( $hider = $module );
	}
	return $hider;
    }
}

sub _get_tests_without_optional_modules {
    my @args = @_;
    _get_hider() or return;
    my @cleanup;
    @args or @args = _get_general_tests();
    foreach my $path ( @args ) {
	push @cleanup, File::Spec->catfile( @optionals_dir,
	    ( File::Spec->splitpath( $path ) )[2] );
    }
    return @cleanup;
}

{

    my @general_tests;

    sub _get_general_tests {
	@general_tests and return @general_tests;
	my $th;
	opendir $th, 't'
	    or die "Unable to open directory t: $!\n";
	while ( defined( my $fn = readdir $th ) ) {
	    '.' eq substr $fn, 0, 1 and next;
	    $fn =~ m/ [.] t \z /smx or next;
	    my $path = File::Spec->catfile( 't', $fn );
	    -f $path or next;
	    push @general_tests, $path;
	}
	closedir $th;
	return @general_tests;
    }
}


sub ACTION_make_optional_modules_tests {
    my ( $self, @args ) = @_;

    my $hider = _get_hider() or do {
#	warn "Neither Devel::Hide nor Test::Without::Module available\n";
	return;
    };

    my $gendir = File::Spec->catdir( @optionals_dir );

    -d $gendir
	or mkdir $gendir
	or die "Unable to create $gendir: $!\n";

    foreach my $ip ( _get_general_tests() ) {
	my ( $op ) = _get_tests_without_optional_modules( $ip );
	-f $op and next;
	print "Creating $op\n";
	open my $oh, '>', $op or die "Unable to open $op: $!\n";
	print { $oh } <<"EOD";
package main;

use strict;
use warnings;

use $hider qw{
@{[ my_wrap( @hide ) ]}
};

do '$ip';

1;

__END__

# ex: set textwidth=72 :
EOD
	close $oh;
    }
}

sub ACTION_authortest {
    my ( $self, @args ) = @_;

    my @depends_on = ( qw{ build make_optional_modules_tests } );
    -e 'META.yml' or push @depends_on, 'distmeta';
    $self->depends_on( @depends_on );
    my @test_files = qw{ t xt/author };
    my $optdir = File::Spec->catdir( @optionals_dir );
    -d $optdir and push @test_files, $optdir;
    $self->test_files( @test_files );
    $self->depends_on( 'test' );

    return;
}

sub my_wrap {
    my ( @args ) = @_;
    my @rslt;
    my $left_margin = ' ' x 3;
    my $line;
    foreach my $item ( @args ) {
	defined $line or $line = $left_margin;
	if ( length( $line ) + length( $item ) > 71 ) {
	    push @rslt, $line . "\n";
	    $line = $left_margin;
	}
	$line .= ' ' . $item;
    }
    defined $line and push @rslt, $line;
    @rslt and chomp $rslt[-1];
    return join '', @rslt;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Build - Extend Module::Build for Astro::App::Satpass2

=head1 SYNOPSIS

 perl Build.PL
 ./Build
 ./Build test
 ./Build authortest # supplied by this module
 ./Build install

=head1 DESCRIPTION

This extension of L<Module::Build|Module::Build> adds the following
action to those provided by L<Module::Build|Module::Build>:

  authortest

=head1 ACTIONS

This module provides the following action:

=over

=item authortest

This action runs not only those tests which appear in the F<t>
directory, but those that appear in the F<xt> directory. The F<xt> tests
are provided for information only, since some of them (notably
F<xt/critic.t> and F<xt/pod_spelling.t>) are very sensitive to the
configuration under which they run.

Some of the F<xt> tests require modules that are not named as
requirements. These should disable themselves if the required modules
are not present.

This test is sensitive to the C<verbose=1> argument, but not to the
C<--test_files> argument.

=item distmeta

This action overrides the standard C<distmeta> to generate a generic
F<META.yml>.

=item make_optional_modules_tests

This action creates the tests in the F<xt/author/optionals> directory.
These generally duplicate the tests in the F<t> directory, but the
optional modules are made unavailable using either
L<Test::Without::Module|Test::Without::Module> or
L<Devel::Hide|Devel::Hide>, in that order. If neither of these modules
is available, nothing is done.

There should be no need to invoke this action directly, since the
C<authortest> action depends on it.

=back

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
