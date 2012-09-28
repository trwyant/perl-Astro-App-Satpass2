package Astro::App::Satpass2::Format::Template::Provider;

use 5.008;

use strict;
use warnings;

use base qw{ Template::Provider };

use Template::Constants ();

our $VERSION = '0.008';

sub __satpass2_defined_templates {
    my ( $self ) = @_;
    return ( keys %{ $self->{ SATPASS2_TEMPLATE } } );
}

sub __satpass2_template {
    my ( $self, $name, @arg ) = @_;

    if ( @arg ) {
	$self->{ SATPASS2_TEMPLATE }{$name}{tplt} = $arg[0];
	( $self->{ SATPASS2_TEMPLATE }{$name}{mtime} ||= 0 )++;
	return $self;
    } else {
	not exists $self->{ SATPASS2_TEMPLATE }{$name}
	    and return;

	return wantarray ?
	    ( map { $self->{ SATPASS2_TEMPLATE }{$name}{$_} }
		qw{ tplt mtime } ) :
	    $self->{ SATPASS2_TEMPLATE }{$name}{tplt};
    }
}

sub fetch {
    my ( $self, $name ) = @_;

    ref $name
	and return wantarray ? ( undef,
	Template::Constants::STATUS_DECLINED ) : undef;

    my ( $data, $error ) = $self->_load( $name );

    $error
	or ( $data, $error ) = $self->_compile( $data );

    $error
	or $data = $data->{ data };

    return wantarray ? ( $data, $error ) : $data;
}

sub load {
    my ( $self, $name ) = @_;

    return $self->_template_content( $name );
}

sub _load {
    my ( $self, $name ) = @_;

    $self->debug( "_load( $name )" ) if $self->{ DEBUG };

    $self->_template_modified( $name )
	or return ( undef, Template::Constants::STATUS_DECLINED );

    my ( $text, $error, $mtime ) = $self->_template_content( $name );
    $error and return ( undef, $error );
    $self->{ UNICODE }
	and $text = $self->_decode_unicode( $text );
    return {
	name	=> $name,
	path	=> $name,
	text	=> $text,
	time	=> $mtime,
	load	=> time,
    };

}

sub _template_modified {
    my ( $self, $name ) = @_;
    return ( $self->__satpass2_template( $name ) )[1];
}

sub _template_content {
    my ( $self, $name ) = @_;
    my ( $tplt, $mtime ) = $self->__satpass2_template( $name );
    return wantarray ?
	( $tplt, ( defined $tplt ? Template::Constants::STATUS_OK :
		Template::Constants::STATUS_DECLINED ),
	    $mtime ) :
	$tplt;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Format::Template::Provider - Template provider.

=head1 SYNOPSIS

 No user serviceable parts inside.

=head1 DESCRIPTION

This class is C<private> to the
L<Astro::App::Satpass2|Astro::App::Satpass2> package. The interface may
change, or the whole package be revoked, without notice. The following
documentation is for the benefit of the author.

This class is a subclass of L<Template::Provider|Template::Provider>,
designed to provide template storage for
L<Astro::App::Satpass2::Format::Template|Astro::App::Satpass2::Format::Template>
and double as a template source for C<Template-Toolkit>.

B<Caveat:> The L<Template::Provider|Template::Provider> documentation
says that subclasses should provide a modification time of the template,
to drive the cache mechanism. This subclass does not actually provide a
time, but instead provides a positive integer that is incremented each
time the template is changed. This prevents problems if a template is
changed twice in the same second, but may have other consequences.

=head1 METHODS

This class supports no public methods. It does support the following
methods which are private to C<Astro::App::Satpass2>:

=head2 load

 my ( $data, $status ) = $obj->load( $name );

This is really an override of the
L<Template::Provider|Template::Provider> method of the same name. But
though it is named like a public method, this method is not documented
there, so it is documented here to keep
L<Test::Pod::Coverage|Test::Pod::Coverage> from complaining.

According to the in-code comments, it loads a template but does not
compile it, and returns (if successful) the template source.

=head2 __satpass2_defined_templates

 foreach ( sort $obj->__satpass2_defined_templates() ) {
     say;
 }

This method returns an unordered list of the names of all defined
templates.

=head2 __satpass2_template

 $obj->__satpass2_template( foo => 'bar' );
 
 my ( $tplt, $mtime ) = $obj->__stapass2_template( 'foo' );
 print "Template foo: $tplt, modified ", scalar localtime $mtime;

If called with a single argument, this method returns the named
template. In list context it returns not only the template but its
modification time. If the template does not exist, it simply returns,
yielding C<undef> in scalar context, and an empty list in list context.

If called with two arguments, this method sets the named template to the
given text, recording its modification time as the current time.

There is no mechanism to delete a template once defined, because I know
of no mechanism to delete it from the C<Template-Toolkit> cache.

=head1 SEE ALSO

L<Template::Provider|Template::Provider>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
