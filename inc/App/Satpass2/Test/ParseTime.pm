package App::Satpass2::Test::ParseTime;

use strict;
use warnings;

use Carp;
use Test::More 0.40;

use base qw{ Exporter };

our @EXPORT = qw{
    diag
    plan
    is
    is_deeply
    isa_ok
    ok
    require_ok
    skip
    time_ok
    time_is
};

sub time_is {
    my ( $pt, $method, @args ) = @_;
    my $name = pop @args;
    my $want = pop @args;
    my $got = eval { $pt->$method( @args ) };
    if ( $@ ) {
	diag( "\$pt->$method( " . join( ', ', map { "'$_'" } @args )
	    . " ) failed: $@" );
	@_ = ( $name );
	goto &fail;
    } else {
	@_ = ( $got, $want, $name );
	no warnings qw{ uninitialized };
	$got == $want or diag(
	    " got $got => " . scalar gmtime( $got ) .
	    " GMT\nwant => " . scalar gmtime( $want ) . " GMT\n" );
	goto &is;
    }

}

sub time_ok {
    my ( $pt, $method, @args ) = @_;
    my $name = pop @args;
    my $got = eval { $pt->$method( @args ) };
    if ( $@ ) {
	diag( "\$pt->$method( " . join( ', ', map { "'$_'" } @args )
	    . " ) failed: $@" );
	@_ = ( $name );
	goto &fail;
    } else {
	@_ = ( $got, $name );
	goto &ok;
    }

}

1;

=head1 NAME

App::Satpass2::ParseTime - <<< replace boilerplate >>>

=head1 SYNOPSIS

<<< replace boilerplate >>>

=head1 DETAILS

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

Copyright (C) 2009-2011, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
