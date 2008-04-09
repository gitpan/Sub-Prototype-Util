package Sub::Prototype::Util;

use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/reftype/;

=head1 NAME

Sub::Prototype::Util - Prototype-related utility routines.

=head1 VERSION

Version 0.04

=cut

use vars qw/$VERSION/;

$VERSION = '0.04';

=head1 SYNOPSIS

    use Sub::Prototype::Util qw/flatten recall/;

    my @a = qw/a b c/;
    my @args = ( \@a, 1, { d => 2 }, undef, 3 );

    my @flat = flatten '\@$;$', @args; # ('a', 'b', 'c', 1, { d => 2 })
    recall 'CORE::push', @args; # @a contains 'a', 'b', 'c', 1, { d => 2 }, undef, 3

=head1 DESCRIPTION

Prototypes are evil, but sometimes you just have to bear with them, especially when messing with core functions. This module provides several utilities aimed at facilitating "overloading" of prototyped functions.

They all handle C<5.10>'s C<_> prototype.

=head1 FUNCTIONS

=cut

my %sigils = qw/SCALAR $ ARRAY @ HASH % GLOB * CODE &/;

sub _check_ref {
 my ($a, $p) = @_;
 my $r;
 if (!defined $a || !defined($r = reftype $a)) { # not defined or plain scalar
  croak 'Got ' . ((defined $a) ? 'a plain scalar' : 'undef')
               . ' where a reference was expected';
 }
 croak 'Unexpected ' . $r . ' reference' unless exists $sigils{$r}
                                            and $p =~ /\Q$sigils{$r}\E/;
 return $r;
}

=head2 C<flatten $proto, @args>

Flattens the array C<@args> according to the prototype C<$proto>. When C<@args> is what C<@_> is after calling a subroutine with prototype C<$proto>, C<flatten> returns the list of what C<@_> would have been if there were no prototype.

=cut

sub flatten {
 my $proto = shift;
 return @_ unless defined $proto;
 my @args; 
 while ($proto =~ /(\\?)(\[[^\]]+\]|[^\];])/g) {
  my $p = $2;
  if ($1) {
   my $a = shift;
   my $r = _check_ref $a, $p;
   my %deref = (
    SCALAR => sub { push @args, $$a },
    ARRAY  => sub { push @args, @$a },
    HASH   => sub { push @args, %$a },
    GLOB   => sub { push @args, *$a },
    CODE   => sub { push @args, &$a }
   );
   $deref{$r}->();
  } elsif ($p =~ /[\@\%]/) {
   push @args, @_;
   last;
  } elsif ($p eq '_' && @_ == 0) {
   push @args, $_;
  } else {
   push @args, shift;
  }
 }
 return @args;
}

=head2 C<recall $name, @args>

Calls the function C<$name> with the prototyped argument list C<@args>. That is, C<@args> should be what C<@_> is when you define a subroutine with the same prototype as C<$name>. For example,

    my $a = [ ];
    recall 'CORE::push', $a, 1, 2, 3;

will call C<push @$a, 1, 2, 3> and so fill the arrayref C<$a> with C<1, 2, 3>. This is especially needed for core functions because you can't C<goto> into them.

=cut

sub recall {
 my $name = shift;
 croak 'Wrong subroutine name' unless $name;
 $name =~ s/^\s+//;
 $name =~ s/[\s\$\@\%\*\&;].*//;
 my $proto = prototype $name;
 my @args;
 my @cr;
 if (defined $proto) {
  my $i = 0;
  while ($proto =~ /(\\?)(\[[^\]]+\]|[^\];])/g) {
   my $p = $2;
   if ($1) {
    my $r = _check_ref $_[$i], $p;
    push @args, join '', $sigils{$r}, '{$_[', $i, ']}';
   } elsif ($p =~ /[\@\%]/) {
    push @args, join '', '@_[', $i, '..', (@_ - 1), ']';
    last;
   } elsif ($p =~ /\&/) {
    push @cr, $_[$i];
    push @args, 'sub{&{$cr[' . $#cr . ']}}';
   } elsif ($p eq '_' && $i >= @_) {
    push @args, '$_';
   } else {
    push @args, '$_[' . $i . ']';
   }
   ++$i; 
  }
 } else {
  @args = map '$_[' . $_ . ']', 0 .. @_ - 1;
 }
 my @ret = eval $name . '(' . join(',', @args) . ');';
 croak $@ if $@;
 return @ret;
}

=head1 EXPORT

The functions L</flatten> and L</recall> are only exported on request, either by providing their name or by the C<':funcs'> and C<':all'> tags.

=cut

use base qw/Exporter/;

use vars qw/@EXPORT @EXPORT_OK %EXPORT_TAGS/;

@EXPORT             = ();
%EXPORT_TAGS        = (
 'funcs' =>  [ qw/flatten recall/ ]
);
@EXPORT_OK          = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = [ @EXPORT_OK ];

=head1 DEPENDENCIES

L<Carp>, L<Exporter> (core modules since perl 5), L<Scalar::Util> (since 5.7.3).

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on #perl @ FreeNode (vincent or Prof_Vince).

=head1 BUGS

Please report any bugs or feature requests to C<bug-sub-prototype-util at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sub-Prototype-Util>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Sub::Prototype::Util

Tests code coverage report is available at L<http://www.profvince.com/perl/cover/Sub-Prototype-Util>.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Sub::Prototype::Util
