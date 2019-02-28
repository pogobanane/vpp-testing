#!/bin/bash
# expects a dut_test*.yaml
# expects the ba-okelmann git to be checked out at ~/ba-okelmann
GITDIR="/root/ba-okelmann"
BINDIR="${GITDIR}/MoonGen/build"

LAST_THROUGHPUT=0.0 # as int

LAST_LATENCY=0 # 75th quartile of latency in ns as int

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
# $2: cmd and it's required arugments
function test-throughput () {
	echo "Starting test"

	# pos_run COMMMAND_ID -- COMMAND
	echo "waiting for vpp setup"
	pos_sync #s1: vvp is set up

	echo "running loadgen"

	jobname=$1
	historyfile="/tmp/$jobname.histogram.csv"
	throughputfile="/tmp/$jobname.throughput.csv"
	latencyfile="/tmp/$jobname.latency.csv"


	pos_run $jobname -- $2 --hifile $historyfile --thfile $throughputfile --lafile $latencyfile

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
	LAST_LATENCY=`cat $latencyfile | head -n 2 | tail -n 1 | awk -F "\"*,\"*" '{print $6}'`
	LAST_LATENCY=`printf "%.0f" $LAST_LATENCY` # float2int


	# wait for test done signal
	pos_sync #s42: test done
	echo "Stopped test" # ~46s
}

# $1: jobname
# $2: rate in mbit/s
# $3: ip flows
function l3-throughput-complex () {
	test-throughput "$1" "${BINDIR}/MoonGen moongen-scripts/l3-throughput.lua $TX_DEV $RX_DEV --rate $2 --flows $3"
}

# $1: jobname
# $2: rate in mbit/s
# $3: mac flows
function l2-throughput-complex () {
	test-throughput "$1" "${BINDIR}/MoonGen moongen-scripts/l2-throughput.lua $TX_DEV $RX_DEV --rate $2 --macs $3"
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

# does 9 test runs!
# finds the sweet spot with lowest latency and highest throughput
# $1: jobname
# $2: number of different macs to use
function l2-throughput-sweetspot () {
	spjobname=$1
	macs=$2

	# # measure everything with low resolution
	# for s in {1..15}
	# do
	# 	i=$((s*400))
	# 	istr=`printf "%04i" $i`
	# 	l2-throughput-complex "${spjobname}_mbit$istr" $i $macs
	# done

	# Try to find max_throughput
	max_throughput=0
	# fill LAST_THROUGHPUT (this is without framing so < 10Gbit. Therefore 9000 is sufficient for 10G links)
	l2-throughput-complex "${spjobname}_mbit9000" 9000 $macs
	base=$(($LAST_THROUGHPUT - 200))
	for offset in {0..6}
	do
		i=$((base+offset*50))
		istr=`printf "%04i" $i`
		# hi resolution testing around LAST_THROUGHPUT
		l2-throughput-complex "${spjobname}_mbit${istr}hires" $i $macs
		if [ $LAST_LATENCY -ge 325000 ]
		then
			# $i is too much throughput
			if [ $max_throughput -eq 0 ]
			then
				# set only if no max was found yet
				max_throughput=$((i-50))
			fi
		fi
	done

	# final test
	istr=`printf "%04i" $max_throughput`
	l2-throughput-complex "${spjobname}_mbit${istr}_final" $max_throughput $macs
}

#### bridge config testing ####

# for i in {0..5}
# do
# 	l2-throughput-sweetspot "l2_bridging_cnf${i}" 0
# done

# l2-throughput-sweetspot "l2_xconnect" 0

#### multimac latency testing ####

# for s in {1..40}
# do
# 	i=$((s*25000))
# 	istr=`printf "%08i" $i`
# 	l2-throughput-sweetspot "l2_multimac_$istr" $i
# done
# l2-throughput-sweetspot "l2_multimac_00000100" 100
# l2-throughput-sweetspot "l2_multimac_00001000" 1000
# l2-throughput-sweetspot "l2_multimac_00005000" 5000
# l2-throughput-sweetspot "l2_multimac_00010000" 10000
# l2-throughput-sweetspot "l2_multimac_00015000" 15000
# l2-throughput-sweetspot "l2_multimac_00020000" 20000

#### multimac throughput testing ####

# 5 runs with 47 different l2fib sizes each = 235
# for run in {0..14}
# do
# 	for s in {1..47}
# 	do
# 		i=`echo "1.4^$s" | bc`
# 		i=`printf "%.0f" $i`
# 		istr=`printf "%08i" $i`
# 		l2-throughput-complex "l2_throughmac_${istr}_$run" 9000 $i
# 	done
# done

#### l3 ip multicore testing ####

# 5 runs with 47 different l2fib sizes each = 235
for run in {0..5}
do
	max=6
	for s in {0..$max}
	do
		sstr=`printf "%02i" $s`
		l3-throughput-complex "l3_multicore_${sstr}_$run" 9000 $(($max*4))
	done
done


#### vxlan throughput ####

# l2-throughput oh shit l3 and vxlan testing is missing
# ./MoonGen/build/MoonGen ./moongen-scripts/vxlan-throughput.lua 2 3 0 0

echo "all done"
