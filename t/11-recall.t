#!perl -T

use strict;
use warnings;

use Test::More tests => 3 + 14 + (($^V ge v5.10.0) ? 4 : 0);

use Scalar::Util qw/set_prototype/;
use Sub::Prototype::Util qw/recall/;

eval { recall undef };
like($@, qr/^Wrong\s+subroutine/, 'recall undef croaks');
eval { recall '' };
like($@, qr/^Wrong\s+subroutine/, 'recall "" croaks');
eval { recall 'hlagh' };
like($@, qr/^Undefined\s+subroutine/, 'recall <unknown> croaks');

sub noproto { $_[1], $_[0] }
sub mytrunc ($;$) { $_[1], $_[0] }
sub mygrep1 (&@) { grep { $_[0]->() } @_[1 .. $#_] }
sub mygrep2 (\&@) { grep { $_[0]->() } @_[1 .. $#_] }
sub modify ($) { my $old = $_[0]; $_[0] = 5; $old }

my $t = [ 1, 2, 3, 4 ];
my $g = [ sub { $_ > 2 }, 1 .. 5 ];

my @tests = (
 [ 'main::noproto', 'no prototype', $t, $t, [ 2, 1 ] ],
 [ 'CORE::push', 'push', [ [ 1, 2 ], 3, 5 ], [ [ 1, 2, 3, 5 ], 3, 5 ], [ 4 ] ],
 [ 'main::mytrunc', 'truncate 1', [ 1 ], [ 1 ], [ undef, 1 ] ],
 [ 'main::mytrunc', 'truncate 2', $t, $t, [ 2, 1 ] ],
 [ 'main::mygrep1', 'grep1', $g, $g, [ 3 .. 5 ] ],
 [ 'main::mygrep2', 'grep2', $g, $g, [ 3 .. 5 ] ],
 [ 'main::modify', 'modify arguments', [ 1 ], [ 5 ], [ 1 ] ],
);

sub myit { push @{$_[0]->[2]}, 3; return 4 };
if ($^V ge v5.10.0) {
 set_prototype \&myit, '_';
 push @tests, [ 'main::myit', '_ with argument',
                [ [ 1, 2, [ ] ], 5 ],
                [ [ 1, 2, [ 3 ] ], 5 ],
                [ 4 ]
              ];
 push @tests, [ 'main::myit', '_ with no argument', [ ], [ 3 ], [ 4 ] ];
}

for (@tests) {
 my $r = [ recall $_->[0], @{$_->[2]} ];
 is_deeply($r, $_->[4], $_->[1] . ' return value');
 is_deeply($_->[2], $_->[3], $_->[1] . ' arguments modification');
}
