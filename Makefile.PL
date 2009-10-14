
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'POE-Component-Client-MPD',
  NAME      => 'POE::Component::Client::MPD',
  AUTHOR    => 'Jerome\ Quelin',
  ABSTRACT  => 'full\-blown\ poe\-aware\ mpd\ client\ library',
  VERSION   => '0.9.4',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "base" => '0',
    "English" => '0',
    "FindBin" => '0',
    "Readonly" => '0',
    "Carp" => '0',
    "POE::Component::Client::TCP" => '0',
    "Test::More" => '0',
    "perl" => '5.010',
    "Audio::MPD::Common::Item" => '0',
    "Audio::MPD::Common::Status" => '0',
    "Audio::MPD::Common::Stats" => '0',
    "File::Find" => '0',
    "POE" => '0',
  },
  test => {TESTS => 't/*.t'}
);

