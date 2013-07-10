package Generator::Object;

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

