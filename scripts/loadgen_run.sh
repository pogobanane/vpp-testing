#!/bin/bash
# expects a dut_test*.yaml
# expects the ba-okelmann git to be checked out at ~/ba-okelmann
GITDIR="/root/ba-okelmann"
BINDIR="${GITDIR}/MoonGen/build"

LAST_THROUGHPUT=0.0

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

TX_DEV=`pos_get_variable -r moongen/tx`
RX_DEV=`pos_get_variable -r moongen/rx`

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
	pos_sync #s1: vvp is set up

	echo "running loadgen"

	jobname=$1
	historyfile="/tmp/$jobname.histogram.csv"
	throughputfile="/tmp/$jobname.throughput.csv"
	latencyfile="/tmp/$jobname.latency.csv"


	pos_run $jobname -- ${BINDIR}/MoonGen moongen-scripts/l2-throughput.lua $TX_DEV $RX_DEV --hifile $historyfile --thfile $throughputfile --lafile $latencyfile --rate $2 --macs $3

	sleep 20
	pos_sync #s21: moogen should be generating load now
	pos_sync #s31: vpp side live data collection done

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $jobname

	pos_sync #s32: moongen is now terminating

	echo "uploading csv files..."
	sleep 10 # wait until moongen did actually stop and write the files
	pos_upload $historyfile
	pos_upload $throughputfile
	pos_upload $latencyfile
	LAST_THROUGHPUT=`cat $throughputfile | head -n 3 | tail -n 1 | awk -F "\"*,\"*" '{print $4}'`
	LAST_THROUGHPUT=`printf "%.0f" $LAST_THROUGHPUT` # float2int

	# wait for test done signal
	pos_sync #s42: test done
	echo "Stopped test" # ~46s
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
	l2-throughput "l2_bridging_cnf${i}"
done

l2-throughput "l2_xconnect_load"

# measure max TODO: higher?
l2-throughput-rate "l2_bridging_mbit5000" 5000
# measure around max with high resolution
base=$(($LAST_THROUGHPUT - 200))
for offset in {0..200}
do
	i=`printf "%04g" $((base+offset*2))`
	l2-throughput-rate "l2_bridging_mbit${i}hires" $i
done
# measure everything with low resolution
for s in {1..18}
do
	i=`printf "%04g" $((s*300))`
	l2-throughput-rate "l2_bridging_mbit$i" $i
done

l2-throughput-flows "l2_multimac_100" 1000
l2-throughput-flows "l2_multimac_1000" 1000
l2-throughput-flows "l2_multimac_10000" 1000
l2-throughput-flows "l2_multimac_100000" 1000
l2-throughput-flows "l2_multimac_1000000" 1000
l2-throughput-flows "l2_multimac_10000000" 1000

echo "all done"
