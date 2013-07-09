use strict;
use warnings;

use Test::More;
use Generator::Object;

my $evens = generator {
  my $x = 0;
  while (1) {
    $x += 2;
    $_->yield($x);
  }
};

subtest 'Basic Usage (evens)' => sub {
  is $evens->next, 2, 'right result';
  is $evens->next, 4, 'right result';

  ok ! exists $evens->{yieldval}, 'yieldval does not leak';
  ok ! exists $evens->{orig}, 'orig does not leak';
};

my $alpha = generator {
  my @array = qw/a b c/;
  while (1) {
    $_->yield(@array);
    shift @array;
    my $temp = $array[-1];
    push @array, ++$temp;
  }
};

subtest 'Context (alpha)' => sub {
  is_deeply [$alpha->next], [qw/a b c/], 'right result (list)';
  is_deeply [$alpha->next], [qw/b c d/], 'right result (list)';

  is scalar $alpha->next, 'c', 'right result (scalar)';
};

subtest 'Interference' => sub {
  # when the two coroutines are both called, this will be more than 6
  # since the even coro was entered when alpha cedes
  is $evens->next, 6, 'right result (even)';
  is $alpha->next, 'd', 'right result (alpha)';
};

$evens->restart;
is $evens->next, 2, 'restart';

eval{ $evens->yield };
ok $@, 'yield outside generator dies';

done_testing;

