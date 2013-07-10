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
The use of L<Coro> internally shouldn't interfere with use of L<Coro>
externally.
 
=cut

use strict;
use warnings;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

use Coro ();

=head1 EXPORTS

=head2 generator

 my $gen = generator { ...; $_->yield };

Convenience function for creating instances of L<Generator::Object>. Takes a
block (subref) which is the body of the generator. Returns an instance of
L<Generator::Object>.

=cut

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

=head1 CONSTRUCTOR

=head2 new

 my $gen = Generator::Object->new(sub{...; $_->yield});

Takes a subref which is the body of the generator. Returns an instance of
L<Generator::Object>.

=cut
 
sub new {
  my $class = shift;
  my $sub = shift;
  return bless { sub => $sub }, $class;
}

=head1 METHODS

=head2 exhausted

 while (1) {
   next if defined $gen->next;
   print "Done\n" if $gen->exhausted;
 }

When the generator is exhausted the C<next> method will return C<undef>.
However, since C<next> might legitimately return C<undef>, this method is
provided to check that the generator has indeed been exhausted.

Note that if C<next> is called on an exhausted generator, it is restarted, and
thus C<exhausted> will again return a false value.

=cut

sub exhausted { shift->{exhausted} }

=head2 next

 my $first  = $gen->next;
 my $second = $gen->next;

This method iterates the generator until C<yield> is called or the body is
returned from. It returns any value passed to C<yield>, in list context all
arguments are returned, in scalar context the first argument is returned. This
emulates returning a list. The context of the C<next> call is available from
the C<wantarray> method for more manual control.

When the generator is exhausted, that is to say, when the body function
returns, C<next> returns C<undef>. Check C<exhausted> to differentiate between
exhaustion and a yielded C<undef>. Any values returned from the body are
available via the C<retval> method, again list return is emulated and the
C<wantarray> method (of the final C<next> call) can be checked when returning.

=cut
 
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

=head2 restart

 my $gen = generator { my $x = 1; $_->yield($x++) while 1 };
 my $first = $gen->next;
 $gen->restart;
 $first == $gen->next; # true

=cut

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

