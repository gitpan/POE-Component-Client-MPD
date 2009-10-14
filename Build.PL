
use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name   => 'POE::Component::Client::MPD',
  license       => 'perl',
  dist_abstract => "full\-blown\ poe\-aware\ mpd\ client\ library",
  dist_name     => "POE\-Component\-Client\-MPD",
  dist_author   => [
"Jerome\ Quelin",
  ],
  requires      => {
    "base" => '0',
    "English" => '0',
    "FindBin" => '0',
    "ExtUtils::MakeMaker" => '0',
    "Readonly" => '0',
    "Carp" => '0',
    "POE::Component::Client::TCP" => '0',
    "perl" => '5.010',
    "Test::More" => '0',
    "Audio::MPD::Common::Item" => '0',
    "Audio::MPD::Common::Status" => '0',
    "Audio::MPD::Common::Stats" => '0',
    "File::Find" => '0',
    "POE" => '0',
  },
  script_files => [ qw() ],
);

$build->create_build_script;
