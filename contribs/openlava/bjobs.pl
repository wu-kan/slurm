#! /usr/bin/perl -w
###############################################################################
#
# bjobs - displays and filters information about jobs in familar
#         openlava format.
#
#
###############################################################################
#  Copyright (C) 2015 SchedMD LLC.
#  Written by Danny Auble <da@schedmd.com>.
#
#  This file is part of SLURM, a resource management program.
#  For details, see <http://slurm.schedmd.com/>.
#  Please also read the included file: DISCLAIMER.
#
#  SLURM is free software; you can redistribute it and/or modify it under
#  the terms of the GNU General Public License as published by the Free
#  Software Foundation; either version 2 of the License, or (at your option)
#  any later version.
#
#  In addition, as a special exception, the copyright holders give permission
#  to link the code of portions of this program with the OpenSSL library under
#  certain conditions as described in each individual source file, and
#  distribute linked combinations including the two. You must obey the GNU
#  General Public License in all respects for all of the code used other than
#  OpenSSL. If you modify file(s) with this exception, you may extend this
#  exception to your version of the file(s), but you are not obligated to do
#  so. If you do not wish to do so, delete this exception statement from your
#  version.  If you delete this exception statement from all source files in
#  the program, then also delete it here.
#
#  SLURM is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#  details.
#
#  You should have received a copy of the GNU General Public License along
#  with SLURM; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA.
#
###############################################################################

#use strict;
use FindBin;
use Getopt::Long 2.24 qw(:config no_ignore_case);
use lib "${FindBin::Bin}/../lib/perl";
use autouse 'Pod::Usage' => qw(pod2usage);
use Slurm ':all';
use Slurmdb ':all'; # needed for getting the correct cluster dims
use Switch;

################################################################################
# $humanReadableTime = hr_time($epochTime)
# Converts an epoch time into a human readable time
################################################################################
sub _job_state_str
{

	my ($state) = @_;

	if(!defined($state)) {
		return 'UNKN';
	}

	switch($state) {
		case [JOB_COMPLETE,
		      JOB_CANCELLED,
		      JOB_TIMEOUT,
		      JOB_FAILED]    { return 'COMP' }
		case [JOB_RUNNING]   { return 'RUN' }
		case [JOB_PENDING]   { return 'PEND' }
		case [JOB_SUSPENDED] { return 'SUSP' }
		else                 { return 'UNKN' }   # Unknown
	}
	return 'U';
}

sub _hr_time
{
	my ($epoch_time) = @_;

	if ($epoch_time == INFINITE) {
		return "Infinite";
	}

	my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
		localtime $epoch_time;

	return sprintf("%s  %d %d:%d", $abbr[$mon], $mday, $hour, $min);
}

sub _shrink_char
{
	my ($str, $max_len) = @_;

	$$str = '*' . substr($$str, -($max_len - 1))
		if length($$str) > $max_len;
}

sub _print_job_brief
{
	my ($job, $line_num) = @_;

	if (!$line_num) {
		printf("%-7s %-7s %-5s %-10s %-11s %-11s %-10s %s",
		       "JOBID", "USER", "STAT", "QUEUE",  "FROM_HOST",
		       "EXEC_HOST", "JOB_NAME", "SUBMIT_TIME");
	}

	_shrink_char(\$job->{'user_name'}, 7);
	_shrink_char(\$job->{'partition'}, 10);
	_shrink_char(\$job->{'alloc_node'}, 11);
	_shrink_char(\$job->{'nodes'}, 11);
	_shrink_char(\$job->{'name'}, 10);

	printf("\n%-7.7s %-7.7s %-5.5s %-10.10s %-11.11s %-11.11s %-10s %-12.12s",
	       $job->{'job_id'}, $job->{'user_name'},
	       _job_state_str($job->{'job_state'}),
	       $job->{'partition'}, $job->{'alloc_node'}, $job->{'nodes'},
	       $job->{'name'}, _hr_time($job->{'submit_time'}));
}

# Parse Command Line Arguments
my ($help,
    $man);

GetOptions(
        'h' => \$help,
        'man'    => \$man,
	) or pod2usage(2);


# Display usage if necessary
pod2usage(0) if $help;
if ($man)
{
        if ($< == 0)    # Cannot invoke perldoc as root
        {
		my $id = eval { getpwnam("nobody") };
		$id = eval { getpwnam("nouser") } unless defined $id;
		$id = -2                          unless defined $id;
		$<  = $id;
        }
        $> = $<;                         # Disengage setuid
        $ENV{PATH} = "/bin:/usr/bin";    # Untaint PATH
        delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
        if ($0 =~ /^([-\/\w\.]+)$/) { $0 = $1; }    # Untaint $0
        else { die "Illegal characters were found in \$0 ($0)\n"; }
        pod2usage(-exitstatus => 0, -verbose => 2);
}

# Use sole remaining argument as job_ids
my @job_ids;
if (@ARGV) {
        @job_ids = @ARGV;
}

my $job_flags = SHOW_ALL | SHOW_DETAIL;
my $resp = Slurm->load_jobs(0, $job_flags);
if(!$resp) {
	die "Problem loading jobs.\n";
}

my $line = 0;
foreach my $job (@{$resp->{job_array}}) {
	my $state = $job->{'job_state'};

	$job->{'name'} = "Allocation" if !$job->{'name'};
	$job->{'user_name'} = getpwuid($job->{'user_id'});

	# Filter jobs according to options and arguments
	if (@job_ids) {
		next unless grep /^$job->{'job_id'}/, @job_ids;
	}

	_print_job_brief($job, $line++);
}

exit 0;

##############################################################################

__END__

=head1 NAME

B<bjobs> - displays and filters information about jobs in familar openlava format.

=head1 SYNOPSIS

B<bjobs> I<job_id>...

=head1 DESCRIPTION

The B<bjobs> displays and filters information about jobs in familar openlava format.

=head1 OPTIONS

=over 4

=item B<-h | --help>

brief help message

=item B<--man>

full documentation

=back

=head1 EXIT STATUS

On success, B<bjobs> will exit with a value of zero. On failure, B<bkill> will exit with a value greater than zero.

=cut

