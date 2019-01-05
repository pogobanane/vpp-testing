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
# $2: rate in mbit/s
# $3: mac flows
function l2-throughput-complex () {
	echo "Starting test"

	# pos_run COMMMAND_ID -- COMMAND
	echo "waiting for vpp setup"
	pos_sync # vvp is set up

	echo "running loadgen"

	jobname=$1
	historyfilefile="/tmp/$jobname.histogram.csv"
	throughputfile="/tmp/$jobname.throughput.csv"
	latencyfile="/tmp/$jobname.latency.csv"


	pos_run $jobname -- ${BINDIR}/MoonGen moongen-scripts/l2-throughput.lua 2 3 --hifile $historyfile --thfile $throughputfile --lafile $latencyfile --rate $2 --macs $3

	sleep 30

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $jobname

	echo "uploading csv files..."
	sleep 10 # wait until moongen did actually stop and write the files
	pos_upload $historyfile
	pos_upload $throughputfile
	pos_upload $latencyfile

	# wait for test done signal
	pos_sync # moongen test done
	echo "Stopped test"
}

# $1: jobname
# $2: rate in mbit/s
function l2-throughput-rate () {
	l2-throughput-complex $1 $2 0
}

# $1: jobname
# $2: number of different macs to use
function l2-throughput-flows () {
	l2-throughput-complex $1 10000 $2
}

# $1: jobname
function l2-throughput () {
	l2-throughput-complex $1 10000 0
}


for i in {0..5}
do
	l2-throughput "l2_bridging_${i}_load"
done

l2-throughput "l2_xconnect_load"

l2-throughput-rate "l2_bridging_7000mbit" 7000
l2-throughput-rate "l2_bridging_6800mbit" 6800
l2-throughput-rate "l2_bridging_6600mbit" 6600
l2-throughput-rate "l2_bridging_6400mbit" 6400
l2-throughput-rate "l2_bridging_6000mbit" 6000
l2-throughput-rate "l2_bridging_5000mbit" 5000
l2-throughput-rate "l2_bridging_4000mbit" 4000
l2-throughput-rate "l2_bridging_2000mbit" 2000
l2-throughput-rate "l2_bridging_1000mbit" 1000
l2-throughput-rate "l2_bridging_0500mbit" 500

l2-throughput-flows "l2_multimac_100" 1000
l2-throughput-flows "l2_multimac_1000" 1000
l2-throughput-flows "l2_multimac_10000" 1000
l2-throughput-flows "l2_multimac_100000" 1000
l2-throughput-flows "l2_multimac_1000000" 1000
l2-throughput-flows "l2_multimac_10000000" 1000

echo "all done"
