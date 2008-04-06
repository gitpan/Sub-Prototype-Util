#!perl -T

use strict;
use warnings;

use Test::More tests => 26;

use Sub::Prototype::Util qw/flatten/;

eval { flatten '\@', undef };
like($@, qr/^Got\s+undef/, 'flatten "\@", undef croaks');
eval { flatten '\@', 1 };
like($@, qr/^Got\s+a\s+plain\s+scalar/, 'flatten "\@", scalar croaks');
eval { flatten '\@', { foo => 1 } };
like($@, qr/^Unexpected\s+HASH\s+reference/, 'flatten "\@", hashref croaks');
eval { flatten '\@', \(\1) };
like($@, qr/^Unexpected\s+REF\s+reference/, 'flatten "\@", double ref croaks');

my $a = [ 1, 2, 3 ];
my $b = [ [ 1, 2 ], 3, { 4 => 5 }, undef, \6 ];
sub hlagh { return 'HLAGH' };
my @tests = (
 [ undef,      'undef prototype',            $a, $a ],
 [ '',         'empty prototype',            $a, [ ] ],
 [ '$',        'truncating to 1',            $a, [ 1 ] ],
 [ '$$',       'truncating to 2',            $a, [ 1, 2 ] ],
 [ '$;$',      'truncating to 1+1',          $a, [ 1, 2 ] ],
 [ '@',        'globbing with @',            $a, $a ],
 [ '@@',       'globbing with @@',           $a, $a ],
 [ '%',        'globbing with %',            $a, $a ],
 [ '%%',       'globbing with %%',           $a, $a ],
 [ '@%',       'globbing with @%',           $a, $a ],
 [ '%@',       'globbing with %@',           $a, $a ],
 [ '\@',       'arrayref and truncate to 1', $b, [ 1, 2 ] ],
 [ '\@$$',     'arrayref and truncate to 3', $b, [ 1, 2, 3, { 4 => 5 } ] ],
 [ '$$\%',     'hashref and truncate to 3',  $b, [ [ 1, 2 ], 3, 4, 5 ] ],
 [ '$$\%',     'hashref and truncate to 3',  $b, [ [ 1, 2 ], 3, 4, 5 ] ],
 [ '\@$\%$\$', 'all usual references',       $b, [ 1, 2, 3, 4, 5, undef, 6 ] ],
 [ '\*$',      'globref', [ \*main::STDOUT, 1 ], [ '*main::STDOUT', 1 ] ],
 [ '\&$',      'coderef', [ \&main::hlagh,  1 ], [ 'HLAGH',   1 ] ],
 [ '\[$@%]',   'class got scalarref',    [ \1 ], [ 1 ] ],
 [ '\[$@%]',   'class got arrayref',  [ [ 1 ] ], [ 1 ] ],
 [ '\[$@%]',   'class got hashref', [ { 1,2 } ], [ 1, 2 ] ]
);
my $l = [ '_', '$_', [ ] ];
$l->[3] = [ $l ];
push @tests, $l;

is_deeply( [ flatten($_->[0], @{$_->[2]}) ], $_->[3], $_->[1]) for @tests;
