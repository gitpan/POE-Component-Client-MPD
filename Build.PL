
use strict;
use warnings;

use Module::Build 0.3601;

my %module_build_args = (
                       'dist_abstract' => 'full-blown poe-aware mpd client library',
                       'dist_author' => [
                                          'Jerome Quelin'
                                        ],
                       'dist_name' => 'POE-Component-Client-MPD',
                       'script_files' => [],
                       'module_name' => 'POE::Component::Client::MPD',
                       'requires' => {
                                       'MooseX::Has::Sugar' => 0,
                                       'MooseX::Types::Moose' => 0,
                                       'FindBin' => 0,
                                       'Sub::Exporter' => 0,
                                       'Moose::Util::TypeConstraints' => 0,
                                       'POE::Component::Client::TCP' => 0,
                                       'Audio::MPD::Common::Item' => 0,
                                       'Audio::MPD::Common::Stats' => 0,
                                       'Audio::MPD::Common::Status' => 0,
                                       'File::Find' => 0,
                                       'Moose' => '0.92',
                                       'MooseX::SemiAffordanceAccessor' => 0,
                                       'MooseX::POE' => 0,
                                       'English' => 0,
                                       'Readonly' => 0,
                                       'Carp' => 0,
                                       'perl' => '5.010',
                                       'Test::More' => 0,
                                       'Test::Corpus::Audio::MPD' => '1.092920',
                                       'File::Temp' => 0,
                                       'POE' => 0
                                     },
                       'license' => 'perl'
                     );


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
