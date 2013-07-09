package Generator::Object;

use strict;
use warnings;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

use Coro ();

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
 
sub next {
  my $self = shift;

  # protect some state values from leaking
  local $self->{yieldval};
  local $self->{orig} = $Coro::current;
 
  $self->{coro} = Coro->new(sub {
    local $_ = $self;
    $self->{sub}->();
  }) unless $self->{coro};

  $self->{coro}->schedule_to;

  return 
    wantarray
    ? @{ $self->{yieldval} }
    : $self->{yieldval}[0];
}
 
sub yield {
  my $self = shift;
  die "Must not call yield outside the generator!\n"
    unless $self->{orig};

  $self->{yieldval} = [ @_ ];
  $self->{orig}->schedule_to;
}
 
1;

