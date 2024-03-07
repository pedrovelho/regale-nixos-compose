#
# abstract base class for all the batch types
#
package RandomESP;

use strict;
use warnings;

my ($defrandseed, $prefix, $defmax) = (142, 3476221, 1000000);

=head1 new( [$random_seed [, $max_interval]] )

Returns a pseudo-random integer in the interval [0, $max_interval) .

 my $rn = new RandomESP(142, 1000000);

where the values shown are the defaults.

If you want to have two objects that are tracking the same sequence
of pseudo-random integers, then define the second object (at any time)
with:

 my $rm = new RandomESP($rn->current(),$rn->max());

Each call pairs of calls to $rn and $rm will produce the identically
same results, but they are two independent objects.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my ($rs,$max) = @_;
	$rs = $defrandseed	if ! defined $rs;
	$max = $defmax		if ! defined $max;
	return bless  {
		randseed	=> $rs,
		this		=> $rs,
		max		=> $max,
		verbose		=> 0,
	};
}

# accessors

sub verbose {
	my $self = shift;
	@_	? $self->{'verbose'} = shift
		: $self->{'verbose'};
}
sub randomseed {
	my $self = shift;
	@_	? $self->{'randomseed'} = shift
		: $self->{'randomseed'};
}

sub max {
	my $self = shift;
	@_	? $self->{'max'} = shift
		: $self->{'max'};
}

sub AUTOLOAD {
}

sub next {
	my $this = shift;
	my ($tmp1, $tmp2, $tmp0);
	$tmp0 = $this->{'this'} * $prefix + 1;
	$tmp1 = int ($tmp0/$this->{'max'});
	$tmp2 = $tmp1 * $this->{'max'};
	$this->{'this'} = $tmp0 - $tmp2;
	return $this->{'this'};
}

sub current {
	my $this = shift;
	return $this->{'this'};
}

1;

