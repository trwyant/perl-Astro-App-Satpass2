use 5.008;

use strict;
use warnings;

use lib qw{ inc };

use Astro::App::Satpass2::Build;
use Astro::App::Satpass2::Meta;
use Astro::App::Satpass2::Recommend;
use Module::Build;

my $meta = Astro::App::Satpass2::Meta->new();

(my $mbv = Module::Build->VERSION) =~ s/_//g;

my %attr = (
    dist_author => 'Tom Wyant (wyant at cpan dot org)',
    dist_abstract => 'Predict satellite visibility using Astro::Coord::ECI',
    module_name => 'Astro::App::Satpass2',
    license => 'perl',
    requires => $meta->requires(
        'perl'	=> $meta->requires_perl(),
    ),
    build_requires => $meta->build_requires(),
    script_files => [ qw{bin/satpass2} ],
    add_to_cleanup => [ qw{ xt/author/optionals } ],
    dynamic_config => 1,
);

$mbv >= 0.28 and $attr{meta_merge} = {
    no_index => {
	directory => [qw{ inc t xt }],
    },
    resources => {
	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-App-Satpass2',
    },
};

# Don't require Module::Build if we're making a distribution, since the
# the user may simply prefer ExtUtils::MakeMaker.

$mbv >= 0.34
    and $attr{auto_configure_requires} = !$meta->distribution();

Astro::App::Satpass2::Recommend->recommend();

#	Generate a builder object.

my $bldr = Astro::App::Satpass2::Build->new (%attr);

$bldr->create_build_script ();
