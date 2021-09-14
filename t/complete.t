package main;

use 5.008;

use strict;
use warnings;

BEGIN {
    delete $ENV{TZ};
}

use Astro::App::Satpass2;
use Test::More 0.88;	# Because of done_testing();

my $app = $Astro::App::Satpass2::READLINE_OBJ = Astro::App::Satpass2->new();

complete( '', get_builtins() );

$app->macro( define => hi => 'echo hello world' );
$app->macro( define => bye => 'echo goodbye cruel world' );

complete( '', [ sort @{ get_builtins() }, qw{ bye hi } ],
    q<Complete '' after defining macros> );

complete( 'a', [ qw{ alias almanac } ] );

complete( 'al', [ qw{ alias almanac } ] );

complete( 'alm', [ qw{ almanac } ] );

complete( 'z', [] );

complete( 'almanac -h', [ qw{ -horizon } ] );

complete( 'almanac --h', [ qw{ --horizon } ] );

complete( 'macro ', [ qw{ brief define delete list load } ] );

complete( 'macro l', [ qw{ list load } ] );

complete( 'macro lo', [ qw{ load } ] );

complete( 'macro load -', [ qw{ -lib -verbose } ] );

complete( 'macro load --', [ qw{ --lib --verbose } ] );

complete( 'macro list ', [ qw{ bye hi } ] );

complete( 'macro list h', [ qw{ hi } ] );

complete( 'macro list z', [] );

complete( 'sky ', [ qw{ add class clear drop list load lookup tle } ] );

complete( 'sky l', [ qw{ list load lookup } ] );

complete( 'sky lo', [ qw{ load lookup } ] );

complete( 'sky loa', [ qw{ load } ] );

complete( 'sky class -', [ qw{ -add -delete } ] );

complete( 'sky class --', [ qw{ --add --delete } ] );

done_testing;

sub complete {
    my ( $line, $want, $name ) = @_;

    my $start = length $line;
    my $text;
    if ( $line =~ m/ ( \S+ ) \z /smx ) {
	$start -= length $1;
	$text = ( split qr< \s+ >smx, $line )[-1];
    } else {
	$text = '';
    }
    my @rslt = Astro::App::Satpass2::__readline_completer_function(
	$text, $line, $start );
    @_ = ( \@rslt, $want, $name || "Complete '$line'" );
    goto &is_deeply;
}

sub get_builtins {
    my @rslt;
    foreach ( sort keys %Astro::App::Satpass2:: ) {
	m/ \A _ /smx
	    and next;
	my $code = Astro::App::Satpass2->can( $_ )
	    or next;
	Astro::App::Satpass2->__get_attr( $code, 'Verb' )
	    or next;
	push @rslt, $_;
    }
    return \@rslt;
}

1;

# ex: set textwidth=72 :
