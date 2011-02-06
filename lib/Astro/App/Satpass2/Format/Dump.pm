package Astro::App::Satpass2::Format::Dump;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Format };

use Carp;

our $VERSION = '0.000_07';

my %dumper_hash = (
    YAML => sub {
	require YAML;
	return YAML->can( 'Dump' );
    },
    'YAML::Syck' => sub {
	require YAML::Syck;
	return YAML::Syck->can( 'Dump' );
    },
    'YAML::XS' => sub {
	require YAML::XS;
	return YAML::XS->can( 'Dump' );
    },
    'YAML::Tiny' => sub {
	require YAML::Tiny;
	return YAML::Tiny->can( 'Dump' );
    },
    'Data::Dumper' => sub {
	require Data::Dumper;
	return Data::Dumper->can( 'Dumper' );
    },
    'JSON' => sub {
	require JSON;
	return JSON->can( 'to_json' );
    },
);

{

    my $dumper_default;

    sub new {
	my ( $class, @args ) = @_;
	my $self = $class->SUPER::new( @args );
	if ( ! $self->dumper() ) {
	    if ( $dumper_default ) {
		$self->dumper( $dumper_default );
	    } else {
		$self->dumper(
		    'YAML,YAML::Syck,YAML::XS,YAML::Tiny,Data::Dumper'
		);
		$dumper_default = $self->dumper();
	    }
	}
	return $self;
    }

}

sub dumper {
    my ( $self, @args ) = @_;
    @args or return $self->{+__PACKAGE__}{dumper};
    my $val = shift @args;
    my $ref = ref $val;
    if ( ! $ref ) {
	foreach my $possible ( split qr{ , }smx, $val ) {
	    my $code = $dumper_hash{$possible} or next;
	    $code = eval { $code->(); } or next;
	    $val = $code;
	    last;
	}
	ref $val
	    or croak "Unknown or unavailable dumper class '$val'";
    } elsif ( $ref ne 'CODE' ) {
	croak 'Dumper must be a code ref or the name of a known class';
    }
    $self->{+__PACKAGE__}{dumper} = $val;
    return $self;
}

sub _dump {
    my ( $self, $object ) = @_;
    if ( defined $object ) {
	return $self->dumper()->( $object );
    } else {
	return '';
    }
}

# TODO when code works, _tle_celestia loses the leading underscore.
foreach my $method ( qw{
    almanac flare list location pass phase position tle
    _tle_celestia tle_verbose }
) {
    no strict qw{ refs };
    *$method = \&_dump;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Format::Dump - Format Astro::App::Satpass2 output as dump.

=head1 SYNOPSIS

 use Astro::App::Satpass2::Format::Dump;
 my $fmt = Astro::App::Satpass2::Format::Dump->new();
 foreach my $tle ( @bodies ) {
     $fmt->list( $tle );
 }

=head1 DETAILS

This formatter is a troubleshooting tool which simply dumps the
arguments to the individual formatter methods. The dumper used can be
specified by the L<dumper()|/dumper> method. See this method's
documentation for the default.

This class does B<not> implement any functionality to make use of the
values of any of the attributes of the superclass.

=head1 METHODS

This class supports the following public methods, beyond those provided
by L<Astro::App::Satpass2::Format|Astro::App::Satpass2::Format>:

=head2 dumper

 print $fmt->dumper()->( $something );
 use Data::Dump;
 $fmt->dumper( Data::Dump->can( 'dump' ) );

The C<dumper> attribute is a reference to the code actually used to
perform the dump. This code expects the thing to be dumped as its only
argument.

This method acts as both accessor and mutator for the C<dumper>
attribute. Without arguments it is an accessor, returning the current
value of the C<dumper> attribute.

If passed an argument, that argument becomes the new value of
C<dumper>, and the object itself is returned so that calls may be
chained.

As a convenience, the argument to the mutator can be either a code
reference (accepted as-is) or the name of a known dumper class. More
than one class name can be specified, separated by commas.

The default is that obtained by setting

 $fmt->dumper( 'YAML,YAML::Syck,YAML::XS,YAML::Tiny,Data::Dumper' );

The known dumper classes are L<Data::Dumper|Data::Dumper>, L<JSON|JSON>,
L<YAML|YAML>, L<YAML::Syck|YAML::Syck>, L<YAML::Tiny|YAML::Tiny>, and
L<YAML::XS|YAML::XS>.

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

# ex: set textwidth=72 :