package Generator::Object;

=head1 NAME

Generator::Object - Generator objects for Perl using Coro

=head1 SYNOPSIS

 use strict; use warnings;
 use Generator::Object;

 my $gen = generator {
   my $x = 0;
   while (1) {
     $x += 2;
     $_->yield($x);
   }
 };

 print $gen->next; # 2
 print $gen->next; # 4

=head1 DESCRIPTION

L<Generator::Object> provides a class for creating Python-like generators for
Perl using C<Coro>. Calling the C<next> method will invoke the generator, while
inside the generator body, calling the C<yield> method on the object will
suspend the interpreter and return execution to the main thread. When C<next>
is called again the execution will return to the point of the C<yield> inside
the generator body. Arguments passed to C<yield> are returned from C<next>.
This pattern allows for long-running processes to return values, possibly
forever, with lazy evaluation.

For convenience the generator object is provided to the function body as C<$_>.
Further the context of the C<next> method call is provided via the C<wantarray>
object method. When/if the generator is exhausted, the C<next> method will
return C<undef> and the C<exhausted> method will return true. Any return value
from the body will then be available from the C<retval> method. After the
generator has reported that it is exhausted, another call to C<next> will
implicitly restart the generator. The generator may be restarted at any time
by using the C<restart> method. C<retval> will be empty after the generator
restarts.

The internals of the object are entirely off-limits and where possible they
have been hidden to prevent access. No subclass api is presented nor planned.
The use of C<Coro> internally shouldn't interfere with use of C<Coro>
externally.
 
=cut

use strict;
use warnings;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

use Coro ();

# class methods

sub import {
  my $class = shift;
  my $caller = caller;

  no strict 'refs';
  *{"${caller}::generator"} = sub (&) {
    my $sub = shift;
    return $class->new($sub);
  };

  # yield??
}
 
sub new {
  my $class = shift;
  my $sub = shift;
  return bless { sub => $sub }, $class;
}

# methods

sub exhausted { shift->{exhausted} }
 
sub next {
  my $self = shift;

  # protect some state values from leaking
  local $self->{orig} = $Coro::current;
  local $self->{wantarray} = wantarray;
  local $self->{yieldval};

  $self->restart if $self->exhausted;
 
  $self->{coro} = Coro->new(sub {
    local $_ = $self;
    $self->{retval} = [ $self->{sub}->() ];
    $self->{exhausted} = 1;
    $self->{orig}->schedule_to;
  }) unless $self->{coro};

  $self->{coro}->schedule_to;

  return 
    $self->{wantarray}
    ? @{ $self->{yieldval} }
    : $self->{yieldval}[0];
}

sub restart {
  my $self = shift;
  delete $self->{coro};
  delete $self->{exhausted};
  delete $self->{retval};
}

sub retval { 
  my $self = shift;
  return undef unless $self->{retval};
  return
    wantarray
    ? @{ $self->{retval} }
    : $self->{retval}[0];
}

sub wantarray { shift->{wantarray} }
 
sub yield {
  my $self = shift;
  die "Must not call yield outside the generator!\n"
    unless $self->{orig};

  $self->{yieldval} = [ @_ ];
  $self->{orig}->schedule_to;
}
 
1;

