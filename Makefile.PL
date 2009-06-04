use 5.006;

use strict;
use warnings;
use ExtUtils::MakeMaker;

my $dist = 'Sub-Prototype-Util';

my %META = (
 configure_requires => {
  'ExtUtils::MakeMaker' => 0,
 },
 build_requires => {
  'ExtUtils::MakeMaker' => 0,
  'Scalar::Util'        => 0,
  'Test::More'          => 0,
 },
 resources => {
  bugtracker => "http://rt.cpan.org/NoAuth/ReportBug.html?Queue=$dist",
  homepage   => "http://search.cpan.org/dist/$dist/",
  license    => 'http://dev.perl.org/licenses/',
  repository => "http://git.profvince.com/?p=perl%2Fmodules%2F$dist.git",
 },
);

WriteMakefile(
    NAME             => 'Sub::Prototype::Util',
    AUTHOR           => 'Vincent Pit <perl@profvince.com>',
    LICENSE          => 'perl',
    VERSION_FROM     => 'lib/Sub/Prototype/Util.pm',
    ABSTRACT_FROM    => 'lib/Sub/Prototype/Util.pm',
    PL_FILES         => {},
    PREREQ_PM        => {
        'Carp'         => 0,
        'Exporter'     => 0,
        'Scalar::Util' => 0
    },
    MIN_PERL_VERSION => 5.006,
    META_MERGE       => \%META,
    dist             => {
        PREOP    => 'pod2text lib/Sub/Prototype/Util.pm > $(DISTVNAME)/README',
        COMPRESS => 'gzip -9f', SUFFIX => 'gz'
    },
    clean            => {
        FILES => "$dist-* *.gcov *.gcda *.gcno cover_db Debian_CPANTS.txt"
    }
);
