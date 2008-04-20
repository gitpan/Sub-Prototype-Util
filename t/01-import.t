#!perl -T

use strict;
use warnings;

use Test::More tests => 3;

require Sub::Prototype::Util;

for (qw/flatten recall wrap/) {
 eval { Sub::Prototype::Util->import($_) };
 ok(!$@, 'import ' . $_);
}
