use strict;
use warnings;

use Test::More;
use Generator::Object;

my $gen = generator {
  $_->yield('yield');
  return ('done', 'and done');
};

is $gen->next, 'yield', 'yield';
is $gen->next, undef, 'yield (exhausted)';
is $gen->exhausted, 1, 'exhausted';
is scalar $gen->retval, 'done', 'return value (scalar context)';
is_deeply [ $gen->retval], ['done', 'and done'], 'return value (list context)';

is $gen->next, 'yield', 'restarted';
ok ! exists $gen->{retval}, 'retval is removed';
is $gen->retval, undef, 'retval reflects restart';
ok ! exists $gen->{exhausted}, 'exhausted is removed';
is $gen->exhausted, undef, 'exhausted reflects restart';


done_testing;

