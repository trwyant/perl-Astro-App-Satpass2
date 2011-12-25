use 5.008;

use strict;
use warnings;

use lib qw{ inc };
use Astro::App::Satpass2::Meta;
use Astro::App::Satpass2::Recommend;

use ExtUtils::MakeMaker qw{WriteMakefile};

my $meta = Astro::App::Satpass2::Meta->new();

(my $mmv = ExtUtils::MakeMaker->VERSION) =~ s/_//g;

my %attr = (
    NAME => 'Astro::App::Satpass2',
    VERSION_FROM => 'lib/Astro/App/Satpass2.pm',
    PREREQ_PM => $meta->requires(),
    PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
    EXE_FILES => [qw{bin/satpass2}],
    'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
    AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
    ABSTRACT => 'Predict satellite visibility using Astro::Coord::ECI',
);

$mmv >= 6.31 and $attr{LICENSE} = 'perl';

if ( $mmv >= 6.4501 ) {
    $attr{META_ADD} = {
	no_index => {
	    directory => [ qw{ inc t xt } ],
	},
    };
    $attr{META_MERGE} = {
	dynamic_config => 1,
	resources => {
	    bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-App-Satpass2',
	    license => 'http://dev.perl.org/licenses/',
	},
    };
} else {
    $attr{PREREQ_PM}{'Test::More'} = 0.40;
}

$mmv >= 6.4701 and $attr{MIN_PERL_VERSION} = $meta->requires_perl();

$mmv >= 6.5501
    and $attr{BUILD_REQUIRES} = $meta->build_requires()
    or $mmv >= 6.4501
    and $attr{META_MERGE}{build_requires} = $meta->build_requires();

Astro::App::Satpass2::Recommend->recommend();

WriteMakefile (%attr);
