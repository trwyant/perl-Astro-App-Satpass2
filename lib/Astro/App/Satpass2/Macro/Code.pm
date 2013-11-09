package Astro::App::Satpass2::Macro::Code;

use 5.008;

use strict;
use warnings;

use base qw{ Astro::App::Satpass2::Macro };

use Astro::App::Satpass2::Utils qw{ expand_tilde load_package quoter };

our $VERSION = '0.014_02';

sub init {
    my ( $self ) = @_;
    $self->SUPER::init();
    my $parent = $self->parent();
    my %popt = ( complaint => 'wail', fatal => 'wail' );
    exists $self->{lib}
	and $popt{lib} = $self->expand_tilde( $self->{lib} );
    my $module = $self->load_package(
	\%popt, $self->name(), 'Astro::App::Satpass2::Macro::Code'
    );
    $module->isa( 'Astro::App::Satpass2' )
	or $self->wail( "$module is not a subclass of Astro::App::Satpass2" );

    my %implements;		# Names and references to found code
    my $stb = "${module}::";	# Name of loaded symbol table

    # Fairly deep magic begins here. We need symbolic references to
    # traverse the symbol table of the loaded code, so:
    no strict qw{ refs };

    while ( my ( $name, $val ) = each %$stb ) {

	# We are only interested in symbols that start with word
	# characters, excluding '_'
	$name =~ m/ \A \w /smx
	    and not $name =~ m/ \A _ /smx
	    or next;

	# We need a reference to the entry's glob, which we obtain by
	# symbolic reference.
	my $glob = \$val;

	# If the code slot is empty we ignore it.
	*{$glob}{CODE}
	    or next;

	# If the code does not have the Verb() attribute, we ignore it.
	# TODO technically we have an encapsulation failure here which
	# needs to be fixed up.
	$parent->_get_attr( *{$glob}{CODE}, 'Verb' )
	or next;

	# Record the fact that the module defines this name.
	$implements{$name} = *{$glob}{CODE};
    }


    # End of symbol table magic.
    $self->{implements} = \%implements;
    return;
}

sub execute {
    my ( $self, $name, @args ) = @_;
    my $code = $self->implements( $name, required => 1 );
    return $code->( $self->parent(), @args );
}

sub has_lib {
    my ( $self ) = @_;
    return exists $self->{lib};
}

sub lib {
    my ( $self ) = @_;
    return $self->{lib};
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Macro::Code - Implement code as macros

=head1 SYNOPSIS

No user-serviceable parts inside.

=head1 DESCRIPTION

This class is private to the C<Astro-App-Satpass2> distribution, mostly
because the code interface has not been written.

=head1 METHODS

This class provides or overrides the following methods:

=head2 has_lib

This method returns true if the C<lib> attribute was specified when the
class was created.

=head2 init

This method treats the C<name> attribute as the name of a module to be
loaded (either with or without C<'Astro::App::Satpass2::Module::Code::'>
prepended). This module must be a subclass of C<Astro::App::Satpass2>.
The loaded module's symbol table is examined, and the C<implements>
attribute is populated with names of and references to any code that has
the C<Verb> attribute.

Note that this means the C<implements( $name )> method returns a
reference to the implementing code if C<$name> is actually implemented;
but users of this module should not rely on this behavior.

=head1 ATTRIBUTES

This class redefines or adds the following attributes of its superclass:

=over

=item lib

This is the name of a directory to be added to C<@INC> before loading
the Perl module that contains the macros. Tilde expansion will be done
on the value. The default is F<lib/> in the user's configuration
directory. If the value is C<undef>, nothing is added to C<@INC> before
the load.

The value of this attribute can be retrieved by the same-named method,
but since this returns C<undef> if this attribute was unspecified as
well as if it was explicitly specified as C<undef>, you should use the
C<has_lib()> method if the difference is important to your code.

=item name

This is the name of the Perl module containing the desired code macros.

=back


=head1 SEE ALSO

The superclass,
L<Astro::App::Satpass2::Macro|Astro::App::Satpass2::Macro>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
