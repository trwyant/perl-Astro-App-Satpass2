package Astro::App::Satpass2::Test::App;

use 5.006002;

use strict;
use warnings;

use base qw{ Exporter };

use Carp;

use Scalar::Util qw{ blessed };
use Test::More 0.40;

our @EXPORT = qw{
    class
    execute
    method
};

my $app;

sub class ($) {
    ( $app ) = @_;
    return;
}

sub execute (@) {	## no critic (RequireArgUnpacking)
    splice @_, 0, 0, 'execute';
    goto &method;
}

sub method (@) {	## no critic (RequireArgUnpacking)
    my ( $method, @args ) = @_;
    my ( $want, $title ) = splice @args, -2;
    my $got;
    if ( eval { $got = $app->$method( @args ); 1 } ) {
	'new' eq $method and $app = $got;
	blessed( $got ) and $got = undef;
	foreach ( $want, $got ) {
	    defined and not ref and chomp;
	}
	@_ = ( $got, $want, $title );
	ref $want eq 'Regexp' ? goto &like :
	    ref $want ? goto &is_deeply : goto &is;
    } else {
	$got = $@;
	chomp $got;
	defined $want or $want = 'unknown error';
	ref $want eq 'Regexp'
	    or $want = qr<\Q$want>smx;
	@_ = ( $got, $want, $title );
	goto &like;
    }
}

sub Astro::App::Satpass2::__TEST__is_exported {
    my ( $self, $name ) = @_;
    return exists $self->{exported}{$name} ? 1 : 0;
}

#	$string = $self->__raw_attr( $name, $format )

#	Fetches the raw value of the named attribute, running it through
#	the given sprintf format if that is not undef. THIS IS AN
#	UNSUPPORTED INTERFACE USED FOR TESTING ONLY.

sub Astro::App::Satpass2::__TEST__raw_attr {
    my ( $self, $name, $format ) = @_;
    defined $format or return $self->{$name};
    return sprintf $format, $self->{$name};
}


1;

__END__

=head1 NAME

Astro::App::Satpass2::Test::App - <<< replace boilerplate >>>

=head1 SYNOPSIS

<<< replace boilerplate >>>

=head1 DESCRIPTION

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

Copyright (C) 2011 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
