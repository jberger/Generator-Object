use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'Generator::Object',
  dist_author => 'Joel Berger',
  license => 'perl',
  requires => {
    'Coro' => 0,
  },
  configure_requires => {
    'Module::Build' => 0.38,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/Generator-Object",
      bugtracker => "http://github.com/jberger/Generator-Object/issues",
    },
    no_index => {
      file => [ 'README.pod' ],
    },
  },
);

$builder->create_build_script;

