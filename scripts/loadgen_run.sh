#!/bin/bash
# expects a dut_test*.yaml
# expects the ba-okelmann git to be checked out at ~/ba-okelmann
GITDIR="/root/ba-okelmann"
BINDIR="${GITDIR}/MoonGen/build"

cd "$GITDIR"

# exit on error
set -e
# log every command
set -x

echo $(pos_get_variable hostname)

# write back some information about the host that might be of interest for the
# evaluation
pos_set_variable host/kernel-name $(uname -s)
pos_set_variable host/kernel-release $(uname -r)
pos_set_variable host/kernel-version $(uname -v)
pos_set_variable host/os $(uname -o)
pos_set_variable host/machine $(uname -m)

# write back the hash of the exact git commit used for reference later
cd "$GITDIR"
pos_set_variable git/commit-hash $(git rev-parse --verify HEAD)
cd "$GITDIR/vpp"
pos_set_variable git/vpp-commit-hash $(git rev-parse --verify HEAD)
cd "$GITDIR"

# disable turbo boost
echo 1 >   /sys/devices/system/cpu/intel_pstate/no_turbo

# set frequency
echo $(pos_get_variable -r cpu-freq) > /sys/devices/system/cpu/intel_pstate/max_perf_pct
echo $(pos_get_variable -r cpu-freq) > /sys/devices/system/cpu/intel_pstate/min_perf_pct

echo 'Done setting up'
pos_sync
echo 'sync done'

# $1: jobname
function l2-throughput-lua () {
	echo "Starting test"

	# pos_run COMMMAND_ID -- COMMAND
	echo "waiting for vpp setup"
	pos_sync # vvp is set up

	echo "running loadgen"

	jobname=$1
	latencyfile="/tmp/$jobname.histogram.csv"
	throughputfile="/tmp/$jobname.throughput.csv"

	pos_run $jobname -- ${BINDIR}/MoonGen moongen-scripts/l2-throughput.lua 2 3 --lafile $latencyfile --thfile $throughputfile

	sleep 30

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $jobname

	echo "uploading csv files..."
	sleep 10 # wait until moongen did actually stop and write the files
	pos_upload $latencyfile
	pos_upload $throughputfile

	# wait for test done signal
	pos_sync # moongen test done
	echo "Stopped test"
}

for i in {0..5}
do
	l2-throughput-lua "l2_bridging_${i}_load"
done

l2-throughput-lua "l2_xconnect_load"

echo "all done"
