#
# --------------------------------------------------
# TEST scheduler specific subroutines
# --------------------------------------------------
#
use strict;
use warnings;

use BATCH;

package TEST;

our @ISA = qw{BATCH};

sub new {
	return bless  BATCH::new;
}

#
#  Monitor & log batch queues
#
sub monitor_queues {
	my ($self, $sleeptime) = @_;
	my ($nque, $nrun, $nrunpe, @fields, $txx0, $ty) = (0, 0, 0);

	sleep($sleeptime);
	open( QSTAT, "sim/tstat 2>/dev/null |");
	while (<QSTAT>) {
		@fields = split;
		if  ($fields[0] eq "Q" ) {
			++$nque;
		} elsif ($fields[0] eq "R") {
			++$nrun;
			$nrunpe += $fields[3];
		}
	}
	close(QSTAT);
	$main::espdone = !($nque || $nrun || $nrunpe);
	printf		 "%d  I  Runjobs: %d PEs: %d Queued: %d espdone: %d\n",
		time(), $nrun, $nrunpe, $nque, $main::espdone;
	printf main::LOG "%d  I  Runjobs: %d PEs: %d Queued: %d espdone: %d\n",
		time(), $nrun, $nrunpe, $nque, $main::espdone;
}

#
#  Fork and submit job
#
sub submit {

	my ($self, $job, $doit) = @_;
	my ($subcmd, $pid, $err) = ("sim/tsubmit " . $job);
	if (!defined($pid=fork())) {
		print "Cannot fork!\n";
		exit(1);
	} elsif (!$pid) {
		# child
		open STDERR, ">/dev/null" || die "cannot redirect stderr\n";
		if (!$doit) {
			print "  SUBMIT -> $subcmd \n";
			exit(0);
		} else {
			exec("$subcmd");
		}
	} else {
		# parent - waiting patiently
		$err = waitpid($pid, 0);
	}
}

sub create_jobs {
	my $self = shift;
	$self->initialize;

	my ($timer, $esphome, $espout)
		= ($self->timer, $self->esphome, $self->espout);
	foreach my $j (keys %{$self->jobdesc}) {
		my @jj = @{$self->jobdesc->{$j}};
		my $taskcount = $self->taskcount($jj[0]);
		my $secs = $jj[2];
		my $cline = $self->command("./","$secs");
		for (my $i=0; $i < $jj[1]; $i++) {
			my $joblabel = $self->joblabel($j,$taskcount,$i);
			print STDERR "creating $joblabel\n" if $self->verbose;
			open(NQS, "> $joblabel");
#
#  "here" template follows 
#  adapt to site batch queue system
#
			print NQS <<"EOF";
#\!/bin/sh
JOBLABEL=$joblabel
NPIPES=$taskcount
NSECS=$secs
OUTPUT=$espout/$joblabel.out
ESP=$esphome

echo `\$ESP/bin/epoch` " START   $joblabel   Seq_\${SEQNUM}" >> \$ESP/LOG
$timer	echo $cline
echo `\$ESP/bin/epoch` " FINISH  $joblabel   Seq_\${SEQNUM}" >> \$ESP/LOG

EOF
#
#  end "here" document
#
	       		close(NQS);
		}
	}
}

1;
