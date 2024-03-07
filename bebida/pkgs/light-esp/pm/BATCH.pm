#
# abstract base class for all the batch types
#
package BATCH;

sub new {
	return bless  {
		verbose	=> 0,
		run	=> 'bin/pchksum -v -u 5000 -t ',
		count	=> 0,
		list	=> [],
	};
}

# accessors
BEGIN {
	my @fields =
	qw{list esphome scratch espout packed syssize timer jobdesc};
	# construct read-only accessor functions - no need for AUTOLOAD
	foreach my $f (@fields) {
		my $code = "package ".__PACKAGE__.";\n"
.qq{sub $f {
	my \$self = shift;
	\$self->{'$f'};
}
};
	eval $code;
	}
}

sub verbose {
	my $self = shift;
	@_	? $self->{'verbose'} = shift
		: $self->{'verbose'};
}
sub run {
	my $self = shift;
	@_	? $self->{'run'} = shift
		: $self->{'run'};
}
sub count {
	my $self = shift;
	@_	? $self->{'count'} = shift
		: $self->{'count'};
}
sub command {
	my $self = shift;
	my ($pre,$post) = @_;
	"$pre".$self->run()."$post";
}
sub count_incr {
	my $self = shift;
	my $incr = shift;
	$incr = 1	if ! defined $incr;
	$self->{'count'} += $incr;
}
sub list_append {
	my $self = shift;
	push @{$self->{'list'}}, @_;
}
sub joblabel {
	my ($self,$jobletter, $taskcount, $number) = @_;
	sprintf("%s_%04d_%03d",$jobletter,$taskcount,$number);
}
sub taskcount {
	my ($self, $fraction) = @_;
	my $taskcount = &round($fraction * $self->syssize);
}

sub AUTOLOAD {
}

sub round {
	my ($num) = shift;
	return int( ($num + 0.500) );
}

sub initialize {
	my $self = shift;
# these really ought to be passed via the command line ...
	@{$self}{qw(esphome scratch espout packed syssize timer jobdesc)}
		= ($main::ESPHOME, $main::ESPSCRATCH, $main::espout,
		   $main::packed, $main::syssize,$main::timer,\%main::jobdesc);

	foreach my $j (keys %{$self->jobdesc}) {
		my @jj = @{$self->jobdesc->{$j}};
		my $taskcount = $self->taskcount($jj[0]);
		for (my $i = 0; $i < $jj[1]; $i++) {
			$self->count_incr;
			$self->list_append($self->joblabel($j,$taskcount,$i));
		}
	}
}

sub list_jobs {
	my $self = shift;
	$self->initialize;
	return	if ! $self->verbose;
	foreach my $j (@{$self->list}) {
		print STDERR "listing $j\n";
	}
}

sub remove_jobs {
	my $self = shift;
	$self->initialize;

	foreach my $j (@{$self->list}) {
		my $return = unlink "$j";
		print STDERR "removing $j\n"	if $return && $self->verbose;
	}
}

# needed by mkjobmix
sub create_jobs {
	my $self = shift;
	$self->initialize;
	my ($esphome,$scratch,$espout,$packed,$syssize,$timer,%jobdesc)
	= @{$self}{qw(esphome scratch espout packed syssize timer jobdesc)};

	die "Your batch class must provide the create_job method!";
}

# needed by runesp
sub submit {
	my ($self, $job, $doit) = @_;
	die "Your batch class must provide the submit method!";
}
sub monitor_queues {
	my ($self, $sleeptime) = @_;
	die "Your batch class must provide the monitor_queues method!";
}

1;

