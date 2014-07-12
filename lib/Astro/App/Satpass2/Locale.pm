package Astro::App::Satpass2::Locale;

use 5.008;

use strict;
use warnings;

use Astro::App::Satpass2::Utils qw{ expand_tilde };
use Exporter qw{ import };
use I18N::LangTags ();
use I18N::LangTags::Detect ();

our $VERSION = '0.020_001';

our @EXPORT_OK = qw{ __localize __preferred };

my @lang;
my $locale;

{

    my %deref = (
	ARRAY	=> sub {
	    my ( $data, $inx ) = @_;
	    defined $inx
		and exists $data->[$inx]
		and return $data->[$inx];
	    no warnings qw{ exiting };
	    next SOURCE_LOOP;
	},
	HASH	=> sub {
	    my ( $data, $key ) = @_;
	    defined $key
		and exists $data->{$key}
		and return $data->{$key};
	    no warnings qw{ exiting };
	    next SOURCE_LOOP;
	},
	''		=> sub {
	    no warnings qw{ exiting };
	    next SOURCE_LOOP;
	},
    );

    sub __localize {
	my @extra = @_;
	$locale ||= _load();
	my $dflt = pop @extra;
	my @keys;
	while ( @extra && defined $extra[0] && ! ref $extra[0] ) {
	    push @keys, shift @extra;
	}
	@extra = grep { $_ } @extra;
	foreach my $lc ( @lang ) {
	    SOURCE_LOOP:
	    foreach my $source ( @{ $locale }, @extra ) {
		my $data = $source->{$lc}
		    or next;
		foreach my $key ( @keys ) {
		    my $code = $deref{ ref $data }
			or do {
			require Carp;
			Carp::confess(
			    'Programming error - Locale systen can ',
			    'not handle ', ref $data, ' as a container'
			);
		    };
		    $data = $code->( $data, $key );
		}
		return $data;
	    }
	}
	return $dflt;
    }

}

sub __preferred {
    $locale ||= _load();
    return wantarray ? @lang : $lang[0];
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

 use Astro::App::Satpass2::Locale qw{ __localize };
 
 say __localize( 'foo', 'bar', 'default text' );

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

=head2 __localize

 say __localize( foo => 'bar', 'default value' );

This subroutine is the interface used to localize values. The last
(rightmost) argument is the default, to be returned if no localization
can be found.  All leading (leftmost) arguments that are defined and are
not references are keys (or indices) used to traverse the locale data
structure. Any remaining arguments are either hash references (which
represent last-chance locale definitions) or ignored.

To extend the above example, assuming neither the system-wide or
locale-specific locale information defines the keys C<{fu}{bar}>,

 say __localize( foo => 'bar', {
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
 }, 'Greeble' );

will print C<'Gronkez!'> in a French locale, and C<'Gronk!'> in any
other locale (since the C<'C'> locale is always consulted). If
C<'Greeble'> is printed, it indicates that the locale system is buggy.

=head2 __preferred

 say __preferred()

This subroutine returns the user's preferred locale in scalar mode, or
all acceptable locales in descending order of preference in list mode.

=head1 SEE ALSO

L<Astro::App::Satpass2::FormatValue|Astro::App::Satpass2::FormatValue>

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
