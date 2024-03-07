#
# --------------------------------------------------
# Torque/PBS specific subroutines
# --------------------------------------------------
#
use strict;
use warnings;

use BATCH;

package SLURM;

our @ISA = qw{BATCH};

sub new {
	return bless  BATCH::new;
}

#  Number of processors busy
#
sub getrunning {
   my ($nrunpe, @fields);
    $nrunpe = 0;
    #my $line;
#    my $disco = `squeue -o %C`;
    open( LLS , "squeue-26 -o \'%C %N %t\' |grep R |sed \'s/a/a /g\' 2>/dev/null |");
#	open( LLS , "squeue-24 -o \'%C %N %t\' |grep R 2>/dev/null |");
   while ( <LLS> ) {
 #  while( defined( $line = <LLS> )){
   #my $line = $_;
#   	chomp($line);
#	print $line;
	$fields[0] = 0;
	$fields[1] = "";
	@fields = split " ", $_;
	#print"$fields[0],$fields[1]";
	if ($fields[1] eq "a") {
###CRAY count tasks, not nodes
	  $nrunpe += $fields[0];
	}
   }
    close(LLS);
    return $nrunpe;
}

#
#  Monitor & log batch queues
#
sub monitor_queues {
    my ($nque, $nrun, @fields, $nrunpe);
    my ($sleeptime, $txx0, $ty);
    
    sleep($_[1]);
    $nque = 0;
    $nrun = 0;
    open( QSTAT, "squeue-26  2>/dev/null |");
    while (<QSTAT>) {
	@fields = split " ", $_;
        if  ($fields[4] eq "PD" ) {
  	  ++$nque;
	} elsif ($fields[4] eq "R") {
	  ++$nrun;
	}
    }
    close(QSTAT);
    $nrunpe = getrunning();
    $main::espdone = !($nque || $nrun || $nrunpe);
    printf("%d  I  Runjobs: %d PEs: %d Queued: %d espdone: %d\n", time(), $nrun, $nrunpe, $nque, $main::espdone);
    printf main::LOG "%d  I  Runjobs: %d PEs: %d Queued: %d espdone: %d\n", time(), $nrun, $nrunpe, $nque, $main::espdone;
}

#
#  Fork and submit job
#
sub submit {
    my ($pid, $subcmd, $err, $doit);

    $subcmd = "sbatch-26 /home_nfs/georgioy/BENCHS/esp-2.2.1_10240/" . $_[1];
#    system("$subcmd");
#    $subcmd = $_[1];
    $doit   = $_[2];
    if (!defined($pid=fork())) {
	print "Cannot fork!\n";
	exit(1);
    } elsif (!$pid) {
	chdir("jobmix") || die "cannot chdir!\n";
	open STDERR, ">/dev/null" || die "cannot redirect stderr\n";
	if (!$doit) {
	    print "  SUBMIT -> $subcmd \n";
	} 
        else {	
	print "  SUBMIT -> $subcmd \n";

exec("$subcmd");
	    die "commande_qui_prend_du_temps non trouvée dan}";
       }
	exit(0);
   } else {
	$err = waitpid($pid, 0);
   }
}

sub create_jobs {
	my $self = shift;
	$self->initialize;

	my ($timer, $esphome, $espout, $packed)
		= ($self->timer, $self->esphome, $self->espout, $self->packed);
	foreach my $j (keys %{$self->jobdesc}) {
		my @jj = @{$self->jobdesc->{$j}};
		my $taskcount = $self->taskcount($jj[0]);
		my $cline = $self->command("\$ESP/","$jj[2]");
		my $wlimit = int($jj[2]*1.50);
		my $min = int($wlimit/60);
		my $sec = int($wlimit%60);
		for (my $i=0; $i < $jj[1]; $i++) {
			my $needed = $taskcount/$packed;
			my $nodes = "$taskcount";
			my $walltime = "$min:$sec";
			my $np=$taskcount;
			if ($taskcount == 2){ $np = 3} 
			if ($taskcount == 16){ $np = 17}
			my $joblabel = $self->joblabel($j,$taskcount,$i);
			print STDERR "creating $joblabel\n" if $self->verbose;
			open(NQS, "> $joblabel");
#
#  "here" template follows 
#  adapt to site batch queue system
#
print NQS <<"EOF";
#\!/bin/sh
#SBATCH -J $joblabel
#SBATCH -n $nodes
#SBATCH -t $walltime
#SBATCH -o /home_nfs/georgioy/BENCHS/esp-2.2.1_10240/logs/$joblabel.out

#HOSTFILE="/tmp/nodes.\$SLURM_JOB_ID"
ESP=/home_nfs/georgioy/BENCHS/esp-2.2.1_10240/
#srun-24 -l /bin/hostname | sort -n | awk '{print \$2}' > /tmp/nodes.\$SLURM_JOB_ID

echo `\$ESP/bin/epoch` " START  $joblabel   Seq_\${SEQNUM}" >> \$ESP/LOG
$timer mpirun -np $np -mca oob_tcp_if_include ib0 -mca coll_sync_priority  100 -mca coll_sync_barrier_before 200 -mca coll_hierarch_priority 0 -mca btl_openib_receive_queues P,65536,32,8,8,4 $cline
echo `\$ESP/bin/epoch` " FINISH $joblabel   Seq_\${SEQNUM}" >> \$ESP/LOG


#rm \$HOSTFILE

exit
EOF
#
#  end "here" document
#
	       		close(NQS);
		}
	}
}

1;
