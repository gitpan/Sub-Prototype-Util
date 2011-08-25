package Sub::Prototype::Util;

use 5.006;

use strict;
use warnings;

use Carp         qw<croak>;
use Scalar::Util qw<reftype>;

=head1 NAME

Sub::Prototype::Util - Prototype-related utility routines.

=head1 VERSION

Version 0.10

=cut

use vars qw<$VERSION>;

$VERSION = '0.10';

=head1 SYNOPSIS

    use Sub::Prototype::Util qw<flatten wrap recall>;

    my @a = qw<a b c>;
    my @args = ( \@a, 1, { d => 2 }, undef, 3 );

    my @flat = flatten '\@$;$', @args; # ('a', 'b', 'c', 1, { d => 2 })
    recall 'CORE::push', @args; # @a contains 'a', 'b', 'c', 1, { d => 2 }, undef, 3
    my $splice = wrap 'CORE::splice';
    my @b = $splice->(\@a, 4, 2); # @a is now ('a', 'b', 'c', 1, 3) and @b is ({ d => 2 }, undef)

=head1 DESCRIPTION

Prototypes are evil, but sometimes you just have to bear with them, especially when messing with core functions.
This module provides several utilities aimed at facilitating "overloading" of prototyped functions.

They all handle C<5.10>'s C<_> prototype.

=head1 FUNCTIONS

=cut

my %sigils   = qw<SCALAR $ ARRAY @ HASH % GLOB * CODE &>;
my %reftypes = reverse %sigils;

sub _check_ref {
 my ($arg, $sigil) = @_;

 my $reftype;
 if (not defined $arg or not defined($reftype = reftype $arg)) {
  # not defined or plain scalar
  my $that = (defined $arg) ? 'a plain scalar' : 'undef';
  croak "Got $that where a reference was expected";
 }

 croak "Unexpected $reftype reference" unless exists $sigils{$reftype}
                                          and $sigil =~ /\Q$sigils{$reftype}\E/;

 $reftype;
}

sub _clean_msg {
 my ($msg) = @_;

 $msg =~ s/(?:\s+called)?\s+at\s+.*$//s;

 $msg;
}

=head2 C<flatten $proto, @args>

Flattens the array C<@args> according to the prototype C<$proto>.
When C<@args> is what C<@_> is after calling a subroutine with prototype C<$proto>, C<flatten> returns the list of what C<@_> would have been if there were no prototype.
It croaks if the arguments can't possibly match the required prototype, e.g. when a reference type is wrong or when not enough elements were provided.

=cut

sub flatten {
 my $proto = shift;

 return @_ unless defined $proto;

 my @args;
 while ($proto =~ /(\\?)(\[[^\]]+\]|[^\];])/g) {
  my $sigil = $2;

  if ($1) {
   my $arg     = shift;
   my $reftype = _check_ref $arg, $sigil;

   push @args, $reftype eq 'SCALAR'
               ? $$arg
               : ($reftype eq 'ARRAY'
                  ? @$arg
                  : ($reftype eq 'HASH'
                     ? %$arg
                     : ($reftype eq 'GLOB'
                        ? *$arg
                        : &$arg # _check_ref ensures this must be a code ref
                       )
                    )
                 );

  } elsif ($sigil =~ /[\@\%]/) {
   push @args, @_;
   last;
  } else {
   croak 'Not enough arguments to match this prototype' unless @_;
   push @args, shift;
  }
 }

 return @args;
}

=head2 C<wrap $name, %opts>

Generates a wrapper that calls the function C<$name> with a prototyped argument list.
That is, the wrapper's arguments should be what C<@_> is when you define a subroutine with the same prototype as C<$name>.

    my $a = [ 0 .. 2 ];
    my $push = wrap 'CORE::push';
    $push->($a, 3, 4); # returns 3 + 2 = 5 and $a now contains 0 .. 4

You can force the use of a specific prototype.
In this case, C<$name> must be a hash reference that holds exactly one key / value pair, the key being the function name and the value the prototpye that should be used to call it.

    my $push = wrap { 'CORE::push' => '\@$' }; # only pushes 1 arg

Others arguments are seen as key / value pairs that are meant to tune the code generated by L</wrap>.
Valid keys are :

=over 4

=item C<< ref => $func >>

Specifies the function used in the generated code to test the reference type of scalars.
Defaults to C<'ref'>.
You may also want to use L<Scalar::Util/reftype>.

=item C<< wrong_ref => $code >>

The code executed when a reference of incorrect type is encountered.
The result of this snippet is also the result of the generated code, hence it defaults to C<'undef'>.
It's a good place to C<croak> or C<die> too.

=item C<< sub => $bool >>

Encloses the code into a C<sub { }> block.
Default is true.

=item C<< compile => $bool >>

Makes L</wrap> compile the code generated and return the resulting code reference.
Be careful that in this case C<ref> must be a fully qualified function name.
Defaults to true, but turned off when C<sub> is false.

=back

For example, this allows you to recall into C<CORE::grep> and C<CORE::map> by using the C<\&@> prototype :

    my $grep = wrap { 'CORE::grep' => '\&@' };
    sub mygrep (&@) { $grep->(@_) } # the prototypes are intentionally different

=cut

sub _wrap {
 my ($name, $proto, $i, $args, $coderefs, $opts) = @_;

 while ($proto =~ s/(\\?)(\[[^\]]+\]|[^\];])//) {
  my ($ref, $sigil) = ($1, $2);
  $sigil = $1 if $sigil =~ /^\[([^\]]+)\]/;

  my $cur = "\$_[$i]";

  if ($ref) {
   if (length $sigil > 1) {
    my $code     = "my \$r = $opts->{ref}($cur); ";
    my @branches = map {
     my $subcall = _wrap(
      $name, $proto, ($i + 1), $args . "$_\{$cur}, ", $coderefs, $opts
     );
     "if (\$r eq '$reftypes{$_}') { $subcall }";
    } split //, $sigil;
    $code .= join ' els', @branches, "e { $opts->{wrong_ref} }";
    return $code;
   } else {
    $args .= "$sigil\{$cur}, ";
   }
  } elsif ($sigil =~ /[\@\%]/) {
   $args .= '@_[' . $i . '..$#_]';
  } elsif ($sigil =~ /\&/) {
   my %h = do { my $c; map { $_ => $c++ } @$coderefs };
   my $j;
   if (exists $h{$i}) {
    $j = int $h{$i};
   } else {
    push @$coderefs, $i;
    $j = $#{$coderefs};
   }
   $args .= "sub{&{\$c[$j]}}, ";
  } elsif ($sigil eq '_') {
   $args .= "((\@_ > $i) ? $cur : \$_), ";
  } else {
   $args .= "$cur, ";
  }
 } continue {
  ++$i;
 }

 $args =~ s/,\s*$//;

 return "$name($args)";
}

sub _check_name {
 my ($name) = @_;
 croak 'No subroutine specified' unless $name;

 my $proto;
 my $r = ref $name;
 if (!$r) {
  $proto = prototype $name;
 } elsif ($r eq 'HASH') {
  croak 'Forced prototype hash reference must contain exactly one key/value pair' unless keys %$name == 1;
  ($name, $proto) = %$name;
 } else {
  croak 'Unhandled ' . $r . ' reference as first argument';
 }

 $name =~ s/^\s+//;
 $name =~ s/[\s\$\@\%\*\&;].*//;

 return $name, $proto;
}

sub wrap {
 my ($name, $proto) = _check_name shift;
 croak 'Optional arguments must be passed as key => value pairs' if @_ % 2;
 my %opts = @_;

 $opts{ref}     ||= 'ref';
 $opts{sub}       = 1       unless defined $opts{sub};
 $opts{compile}   = 1       if     not defined $opts{compile} and $opts{sub};
 $opts{wrong_ref} = 'undef' unless defined $opts{wrong_ref};

 my @coderefs;
 my $call;
 if (defined $proto) {
  $call = _wrap $name, $proto, 0, '', \@coderefs, \%opts;
 } else {
  $call = _wrap $name, '', 0, '@_';
 }

 if (@coderefs) {
  my $decls = @coderefs > 1 ? 'my @c = @_[' . join(', ', @coderefs) . ']; '
                            : 'my @c = ($_[' . $coderefs[0] . ']); ';
  $call = $decls . $call;
 }

 $call = "{ $call }";
 $call = "sub $call" if $opts{sub};

 if ($opts{compile}) {
  my $err;
  {
   local $@;
   $call = eval $call;
   $err  = $@;
  }
  croak _clean_msg $err if $err;
 }

 return $call;
}

=head2 C<recall $name, @args>

Calls the function C<$name> with the prototyped argument list C<@args>.
That is, C<@args> should be what C<@_> is when you call a subroutine with C<$name> as prototype.
You can still force the prototype by passing C<< { $name => $proto } >> as the first argument.

    my $a = [ ];
    recall { 'CORE::push' => '\@$' }, $a, 1, 2, 3; # $a just contains 1

It's implemented in terms of L</wrap>, and hence calls C<eval> at each run.
If you plan to recall several times, consider using L</wrap> instead.

=cut

sub recall;

BEGIN {
 my $safe_wrap = sub {
  my $name = shift;

  my ($wrap, $err);
  {
   local $@;
   $wrap = eval { wrap $name };
   $err  = $@;
  }

  $wrap, $err;
 };

 if ("$]" == 5.008) {
  # goto tends to crash a lot on perl 5.8.0
  *recall = sub {
   my ($wrap, $err) = $safe_wrap->(shift);
   croak _clean_msg $err if $err;
   $wrap->(@_)
  }
 } else {
  *recall = sub {
   my ($wrap, $err) = $safe_wrap->(shift);
   croak _clean_msg $err if $err;
   goto $wrap;
  }
 }
}

=head1 EXPORT

The functions L</flatten>, L</wrap> and L</recall> are only exported on request, either by providing their name or by the C<':funcs'> and C<':all'> tags.

=cut

use base qw<Exporter>;

use vars qw<@EXPORT @EXPORT_OK %EXPORT_TAGS>;

@EXPORT             = ();
%EXPORT_TAGS        = (
 'funcs' =>  [ qw<flatten wrap recall> ]
);
@EXPORT_OK          = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = [ @EXPORT_OK ];

=head1 DEPENDENCIES

L<Carp>, L<Exporter> (core modules since perl 5), L<Scalar::Util> (since 5.7.3).

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-sub-prototype-util at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sub-Prototype-Util>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Sub::Prototype::Util

Tests code coverage report is available at L<http://www.profvince.com/perl/cover/Sub-Prototype-Util>.

=head1 COPYRIGHT & LICENSE

Copyright 2008,2009,2010,2011 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Sub::Prototype::Util
