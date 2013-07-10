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
is $gen->retval, undef, 'retval cleared';
is $gen->exhausted, undef, 'exhausted cleared';


done_testing;

