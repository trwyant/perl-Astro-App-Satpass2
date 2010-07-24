#!/usr/local/bin/perl

use strict;
use warnings;

use IO::File;

my $data;
my @nouse;
my $drop_re;
my $shebang;

my $outfile = shift @ARGV || 'satpass2';

-e $outfile and die "File $outfile already exists\n";

foreach my $fn (
    qw{
	lib/Astro/Coord/ECI/Format.pm
	lib/App/Satpass2.pm
	bin/satpass2
    }) {
    my $fh = IO::File->new($fn, '<')
	or die "Unable to open $fn: $!\n";
    my $begin_block;
    if ((my $module = $fn) =~ s/\.pm$//) {
	$module =~ s{.*?/}{};
	$module =~ s{/}{::}g;
	push @nouse, quotemeta ($module);
	$drop_re = qr/use\s+(?:@{[join '|', @nouse]})\b/;
	$begin_block = 1;
    }
    if ($begin_block) {
####	$data .= "BEGIN {\n";
	$data .= "{\n";
    } else {
	local $_ = <$fh>;
	if (m/^#!/) {
	    $shebang = $_;
	} else {
	    ($drop_re && m/$drop_re/) and $data .= '#>> ';
	    $data .= $_;
	}
    }
    my $in_pod = 0;
    while (<$fh>) {
	m/^__END__$/ and last;
	if ($in_pod) {
	    $in_pod = $_ !~ m/^=cut\b/
	} elsif (m/^=/) {
	    $in_pod = 1;
	} elsif (m/^\s*#/) {
	} elsif ($drop_re && m/$drop_re/) {
	    $data .= '#>> ';
	} elsif (m/^\s*package\s+/) {
	    chomp;
	    $_ .= "\t## no critic (ProhibitMultiplePackages)\n";
	}
	$data .= $_;
    }
    $begin_block and $data .= "}\n";
}

{
    $shebang .= <<EOD;
package main;

use strict;
use warnings;

EOD
    open (my $fh, '>', $outfile) or die "Failed to open $outfile: $!\n";
    $shebang and print $fh $shebang;
    print $fh $data;
    close $fh;
    chmod 0755, $outfile or die "Failed to make $outfile executable: $!\n";
}
