#!perl -T

use strict;
use warnings;

use Test::More tests => 7 + 6 + 3 + 1 + 6 + 1 + (($^V ge v5.10.0) ? 2 : 0) + 1;

use Scalar::Util qw/set_prototype/;
use Sub::Prototype::Util qw/wrap/;

eval { wrap undef };
like($@, qr/^No\s+subroutine/, 'recall undef croaks');
eval { wrap '' };
like($@, qr/^No\s+subroutine/, 'recall "" croaks');
eval { wrap \1 };
like($@, qr/^Unhandled\s+SCALAR/, 'recall scalarref croaks');
eval { wrap [ ] };
like($@, qr/^Unhandled\s+ARRAY/, 'recall arrayref croaks');
eval { wrap sub { } };
like($@, qr/^Unhandled\s+CODE/, 'recall coderef croaks');
eval { wrap { 'foo' => undef, 'bar' => undef } };
like($@, qr!exactly\s+one\s+key/value\s+pair!, 'recall hashref with 2 pairs croaks');
eval { wrap 'hlagh', qw/a b c/ };
like($@, qr/^Optional\s+arguments/, 'recall takes options in a key => value list');

my $push_exp = '{ CORE::push(@{$_[0]}, @_[1..$#_]) }';
my $push = wrap 'CORE::push';
is($push, 'sub ' . $push_exp, 'wrap push as a sub (default)');
$push = wrap 'CORE::push', sub => 1;
is($push, 'sub ' . $push_exp, 'wrap push as a sub');
$push = wrap 'CORE::push', sub => 0;
is($push, $push_exp, 'wrap push as a raw string');
$push = wrap 'CORE::push', compile => 1;
is(ref $push, 'CODE', 'wrap compiled push is a CODE reference');
my @a = qw/a b/;
my $ret = $push->(\@a, 7 .. 12);
is_deeply(\@a, [ qw/a b/, 7 .. 12 ], 'wrap compiled push works');
is($ret, 8, 'wrap compiled push returns the correct number of elements');

my $push2 = wrap { 'CORE::push' => '\@;$' }, compile => 1;
is(ref $push2, 'CODE', 'wrap compiled truncated push is a CODE reference');
@a = qw/x y z/;
$ret = $push2->(\@a, 3 .. 5);
is_deeply(\@a, [ qw/x y z/, 3 ], 'wrap compiled truncated push works');
is($ret, 4, 'wrap compiled truncated push returns the correct number of elements');

sub cb (\[$@]\[%&]&&);
my $cb = wrap 'main::cb', sub => 0, wrong_ref => 'die';
my $x = ', sub{&{$c[0]}}, sub{&{$c[1]}}) ';
is($cb,
   join('', q!{ my @c; push @c, $_[2]; push @c, $_[3]; !,
            q!my $r = ref($_[0]); !,
            q!if ($r eq 'SCALAR') { !,
             q!my $r = ref($_[1]); !,
             q!if ($r eq 'HASH') { !,
              q!main::cb(${$_[0]}, %{$_[1]}! . $x,
             q!} elsif ($r eq 'CODE') { !,
              q!main::cb(${$_[0]}, &{$_[1]}! . $x,
             q!} else { !,
              q!die !,
             q!} !,
            q!} elsif ($r eq 'ARRAY') { !,
             q!my $r = ref($_[1]); !,
             q!if ($r eq 'HASH') { !,
              q!main::cb(@{$_[0]}, %{$_[1]}! . $x,
             q!} elsif ($r eq 'CODE') { !,
              q!main::cb(@{$_[0]}, &{$_[1]}! . $x,
             q!} else { !,
              q!die !,
             q!} !,
            q!} else { !,
             q!die !,
            q!} }!),
    'callbacks');

sub myref { ref $_[0] };

sub cat (\[$@]\[$@]) {
 if (ref $_[0] eq 'SCALAR') {
  if (ref $_[1] eq 'SCALAR') {
   return ${$_[0]} . ${$_[1]};
  } elsif (ref $_[1] eq 'ARRAY') {
   return ${$_[0]}, @{$_[1]};
  }
 } elsif (ref $_[0] eq 'ARRAY') {
  if (ref $_[1] eq 'SCALAR') {
   return @{$_[0]}, ${$_[1]};
  } elsif (ref $_[1] eq 'ARRAY') {
   return @{$_[0]}, @{$_[1]};
  }
 }
}

SKIP: {
 skip 'perl 5.8.x is needed to test execution of \[$@] prototypes' => 6
   if $^V lt v5.8.0;

 my $cat = wrap 'main::cat', ref => 'main::myref', wrong_ref => 'die "hlagh"',
                             sub => 1, compile => 1;
 my @tests = (
  [ \'a',        \'b',        [ 'ab' ],        'scalar-scalar' ],
  [ \'c',        [ qw/d e/ ], [ qw/c d e/ ],   'scalar-array' ],
  [ [ qw/f g/ ], \'h',        [ qw/f g h/ ],   'array-scalar' ],
  [ [ qw/i j/ ], [ qw/k l/ ], [ qw/i j k l/ ], 'array-array' ]
 );
 for (@tests) {
  my $res = [ $cat->($_->[0], $_->[1]) ];
  is_deeply($res, $_->[2], 'cat ' . $_->[3]);
 }
 eval { $cat->({ foo => 1 }, [ 2 ] ) };
 like($@, qr/^hlagh\s+at/, 'wrong reference type 1');
 eval { $cat->(\1, sub { 2 } ) };
 like($@, qr/^hlagh\s+at/, 'wrong reference type 2');
}

sub noproto;
my $noproto_exp = '{ main::noproto(@_) }';
my $noproto = wrap 'main::noproto', sub => 0;
is($noproto, $noproto_exp, 'no prototype');

sub myit { my $ar = shift; push @$ar, @_; };
if ($^V ge v5.10.0) {
 set_prototype \&myit, '\@$_';
 my $it = wrap 'main::myit', compile => 1;
 my @a = qw/u v w/;
 local $_ = 7;
 $it->(\@a, 3, 4, 5);
 is_deeply(\@a, [ qw/u v w/, 3, 4 ], '_ with arguments');
 $it->(\@a, 6);
 is_deeply(\@a, [ qw/u v w/, 3, 4, 6, 7 ], '_ without arguments');
}

eval { wrap { 'main::dummy' => '\[@%]' }, ref => 'shift', compile => 1 };
like($@, qr/to\s+shift\s+must\s+be\s+array/, 'invalid eval code croaks');
