package Astro::App::Satpass2::Locale;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2::Utils qw{ expand_tilde };
use Exporter qw{ import };
use I18N::LangTags ();
use I18N::LangTags::Detect ();

our $VERSION = '0.020_001';

our @EXPORT_OK = qw{ __locale __preferred };

my @lang;
my $locale;

sub __locale {
    my ( $sect, $item, @extra ) = @_;
    @extra = grep { 'HASH' eq ref $_ } @extra;
    $locale ||= _load();
    foreach my $lc ( @lang ) {
	foreach my $source ( @{ $locale }, @extra ) {
	    my $data = $source->{$lc}
		or next;
	    $data = $data->{$sect}
		or next;
	    exists $data->{$item}
		or next;
	    return $data->{$item};
	}
    }
    return;
}

sub __preferred {
    $locale ||= _load();
    return $lang[0];
}

sub _load {

    # Pick up the languages from the environment
    @lang = I18N::LangTags::implicate_supers(
	I18N::LangTags::Detect::detect() );

    # Normalize the language names.
    foreach ( @lang ) {
	s/ ( [^_-]+ ) [_-] (.* ) /\L$1_\U$2/smx
	    or $_ = lc $_;
	'c' eq $_
	    and $_ = uc $_;
    }

    # Append the default locale name.
    grep { 'C' eq $_ } @lang
	or push @lang, 'C';

    # Accumulator for locale data.
    my @locales;

    # Put all the user's data in a hash.
    push @locales, {};
    foreach my $lc ( @lang ) {
	eval {	## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
	    defined( my $path = expand_tilde( "~~/locale/$lc.pm" ) )
		or return;
	    my $data;
	    $data = do $path
		and 'HASH' eq ref $data
		and $locales[-1]{$lc} = $data;
	};
    }

    # Put the system-wide data in a hash.
    push @locales, {};
    foreach my $lc ( @lang ) {
	my $mod_name = __PACKAGE__ . "::$lc";
	my $data;
	$data = eval "require $mod_name"
	    and 'HASH' eq ref $data
	    and $locales[-1]{$lc} = $data;
    }

    # Return a reference to the names of locales.
    return \@locales;
}

1;

__END__

=head1 NAME

Astro::App::Satpass2::Locale - Handle locale-dependant data.

=head1 SYNOPSIS

 use Astro::App::Satpass2::Locale qw{ __locale };
 
 say __locale( 'foo', 'bar' );

=head1 DESCRIPTION

This Perl module implements the locale system for
L<Astro::App::Satpass2|Astro::App::Satpass2>.

The locale data can be thought of as a two-level hash, with the first
level corresponding to the section of a Microsoft-style configuration
file and the second level to the items in the section.

The locale data are stored in C<.pm> files, which return the required
hash when they are loaded. These are named after the locale, in the form
F<lc_CC.pm> or F<lc.pm>, where the C<lc> is the language code (lower
case) and the C<CC> is a country code (upper case).

The files are considered in the following order:

=over

=item The user's F<lc_CC.pm>

=item The global F<lc_CC.pm>

=item The user's F<lc.pm>

=item The global F<lc.pm>

=item The user's F<C.pm>

=item The global F<C.pm>.

=back

The global files are installed as Perl modules, named
C<Astro::App::Satpass2::Locale::whatever>, and are loaded via
C<require()>. The user's files are stored
in the F<locale/> directory of the user's configuration, and are loaded
via C<do()>.

=head1 SUBROUTINES

This class supports the following exportable public subroutines:

=head2 __locale

 say __locale( 'foo', 'bar' );

This is the interface to the locale system. The arguments are the
section and item name, and the specified item is returned. If the
specified item is not found, nothing is returned.

Optional arguments after the second may also be passed. These are hash
references to extra locale data to be considered, keyed by locale code.
These will be considered only if the section and item can not be found
in user or global files.

To continue the above example:

 say __locale( 'foo', 'bar', {
     C => {
         foo => {
             bar => 'Gronk!',
         },
     },
     fr => {
         foo => {
             bar => 'Gronkez!',
         },
     },
 );

If section C<'foo'> and item C<'bar'> can not be found in either the
user's or global locale definitions, this will print C<'Gronkez!'> if
the user's locale is C<'fr'> (or C<'fr_FR'>, or ... ) and print
C<'Gronk!'> otherwise.

=head2 __preferred

 say __preferred()

This subroutine returns the user's preferred locale.

=head1 SEE ALSO

<<< replace or remove boilerplate >>>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
