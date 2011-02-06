package Astro::App::Satpass2::Copier;

use strict;
use warnings;

use Carp;
use Clone ();
use Scalar::Util qw{ blessed looks_like_number };

use base qw{ Exporter };

our @EXPORT_OK = qw{ __instance __quoter };

our $VERSION = '0.000_07';

sub attribute_names {
    return ();
}

sub clone {
    my ( $self ) = @_;
    return Clone::clone( $self );
}

sub copy {
    my ( $self, $copy ) = @_;
    foreach my $attr ( $self->attribute_names() ) {
	$copy->$attr( $self->$attr() );
    }
    return $self;
}

sub create_attribute_methods {
    my ( $self ) = @_;
    my $class = ref $self || $self;
    foreach my $attr ( $self->attribute_names() ) {
	$class->can( $attr ) and next;
	my $method = $class . '::' . $attr;
	no strict qw{ refs };
	*$method = sub {
	    my ( $self, @args ) = @_;
	    if ( @args ) {
		$self->{$attr} = $args[0];
		return $self;
	    } else {
		return $self->{$attr};
	    }
	};
    }
    return;
}

#	__instance( $object, $class );
#
#	Returns true if $object is an instance of $class, and false
#	otherwise. $object must be a reference.

sub __instance {
    my ( $object, $class ) = @_;
    ref $object or return;
    blessed( $object ) or return;
    return $object->isa( $class );
}

#	$quoted = __quoter( $string )

#	Quotes and escapes the input string if and as necessary for parser.

sub __quoter {
    my ( $string ) = @_;
    return 'undef' unless defined $string;
    return $string if looks_like_number ($string);
    return "''" unless $string;
    return $string unless $string =~ m/ [\s'"\$] /smx;
    $string =~ s/ ( [\\"\$] ) /\\$1/smxg;
    return qq{"$string"};
}


1;

__END__

=head1 NAME

Astro::App::Satpass2::Copier - Object copying functionality for Astro::App::Satpass2

=head1 SYNOPSIS

 package Astro::App::Satpass2::Foo;
 
 use strict;
 use warnings;
 
 use base qw{ Astro::App::Satpass2::Copier };
 
 sub new { ... }
 
 sub attribute_names {
     return ( qw{ bar baz } );
 }
 
 __PACKAGE__->create_attribute_methods();
 
 1;

=head1 DETAILS

B<This class is private> to the L<Astro::App::Satpass2|Astro::App::Satpass2> package.
The author reserves the right to modify it in any way or retract it
without prior notice.

=head1 METHODS

This class supports the following public methods:

=head2 attribute_names

 print join( ', ', $obj->attribute_names() ), "\n";

This method returns the names of the object's attribute_names.

Subclasses should override this. Immediate subclasses B<should> call
C<SUPER::attribute_names()>, and indirect subclasses B<must> call
C<SUPER::attribute_names()>. A subclass' override would look something like
this:

 sub attribute_names {
     my ( $self ) = @_;
     return ( $self->SUPER::attribute_names(), qw{ foo bar baz } );
 }

=head2 clone

 my $clone = $obj->clone();

This method returns a clone of the original object, taken using
C<Clone::clone()>.

Overrides C<may> call C<SUPER::clone()>. If they do not they bear
complete responsibility for producing a correct clone of the original
object.

=head2 copy

 $obj->copy( $copy );

This method copies the attribute values of the original object into the
attribute_names of the copy object. The original object is returned.

The copy object need not be the same class as the original, but it must
support all attributes the original supports.

=head2 create_attribute_methods

 __PACKAGE__->create_attribute_methods();

This method may be called exactly once by the subclass to create
accessor/mutator methods. This method assumes that the object is based
on a hash reference, and stores attribute values in same-named keys in
the hash. The created methods have the same names as the attributes.
They are accessors if called without arguments, and mutators returning
the original object if called with arguments.  Methods already in
existence when this method is called will not be overridden.

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