
use strict;
use warnings;

 BEGIN { require 5.010; } 

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'POE-Component-Client-MPD',
  NAME      => 'POE::Component::Client::MPD',
  AUTHOR    => "Jerome\ Quelin",
  ABSTRACT  => "full\-blown\ poe\-aware\ mpd\ client\ library",
  VERSION   => '1.093320',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "MooseX::Has::Sugar" => '0',
    "MooseX::Types::Moose" => '0',
    "FindBin" => '0',
    "Sub::Exporter" => '0',
    "Moose::Util::TypeConstraints" => '0',
    "POE::Component::Client::TCP" => '0',
    "Audio::MPD::Common::Item" => '0',
    "Audio::MPD::Common::Stats" => '0',
    "Audio::MPD::Common::Status" => '0',
    "File::Find" => '0',
    "Moose" => '0.92',
    "MooseX::SemiAffordanceAccessor" => '0',
    "MooseX::POE" => '0',
    "English" => '0',
    "Readonly" => '0',
    "Carp" => '0',
    "Test::More" => '0',
    "POE" => '0',
  },
  test => {TESTS => 't/*.t'}
);

