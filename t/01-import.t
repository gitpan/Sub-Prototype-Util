#!perl -T

use strict;
use warnings;

use Test::More tests => 2;

require Sub::Prototype::Util;

for (qw/flatten recall/) {
 eval { Sub::Prototype::Util->import($_) };
 ok(!$@, 'import ' . $_);
}
