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

# set frequency to max, even if DUT runs on lower freq
echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
echo 100 > /sys/devices/system/cpu/intel_pstate/min_perf_pct

# read vars
TX_DEV=`pos_get_variable -r moongen/tx`
RX_DEV=`pos_get_variable -r moongen/rx`

echo 'Done setting up'
pos_sync
echo 'sync done'

# $1: jobname
# $2: cmd and it's required arugments
function test-throughput () {
	echo "Starting test"

	echo "waiting for vpp setup"
	pos_sync #s1: vvp is set up

	echo "running loadgen"

	jobname=$1
	historyfile="/tmp/$jobname.histogram.csv"
	throughputfile="/tmp/$jobname.throughput.csv"
	latencyfile="/tmp/$jobname.latency.csv"
	lalifile="/tmp/$jobname.latencies.csv"

	# pos_run COMMMAND_ID -- COMMAND ARGS
	pos_run $jobname -- $2 --hifile $historyfile --thfile $throughputfile --lafile $latencyfile --lalifile $lalifile

	sleep 20
	pos_sync #s21: moogen should be generating load now
	pos_sync #s31: vpp side live data collection done

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $jobname

	pos_sync #s32: moongen is now terminating

	echo "uploading csv files..."
	sleep 10 # wait until moongen did actually stop and write the files
	if [ -f $lalifile ]; then # histfile does not exists when latfile is list of latencies per packet
		pos_upload $lalifile
	else
		pos_upload $historyfile
		pos_upload $latencyfile
	fi
	pos_upload $throughputfile
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
# $3: ip routes count
function l3-throughput-routes () {
	test-throughput "$1" "${BINDIR}/MoonGen moongen-scripts/l3-throughput.lua $TX_DEV $RX_DEV --rate $2 --routes $3 --ipDst \"10.3.0.0\""
}

# $1: jobname
# $2: rate in mbit/s
# $3: mac flows
function l2-throughput-complex () {
	test-throughput "$1" "${BINDIR}/MoonGen moongen-scripts/l2-throughput.lua $TX_DEV $RX_DEV --rate $2 --macs $3"
}

# $1: jobname
# $2: rate in mbit/s
# $3: packet size
function l2-throughput-conext () {
	test-throughput "$1" "${BINDIR}/MoonGen moongen-scripts/l2-throughput.lua $TX_DEV $RX_DEV --rate $2 --pktSize $3"
}

# $1: jobname
# $2: rate in mbit/s
function l2-throughput-rate () {
	l2-throughput-complex $1 $2 0
}

# $1: jobname
# $2: number of different macs to use
function l2-throughput-flows () {
	l2-throughput-complex $1 100000 $2
}

# $1: jobname
function l2-throughput () {
	l2-throughput-complex $1 100000 0
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

#### short and simple bridge test ####
function bridge_simple_test () {
	l2-throughput-complex "l2_bridgingSimple_cnf0_mbit9000" 9000 0
}

#### bridge config testing ####
function bridge_config_testing () {
	for i in {0..5}
	do
		l2-throughput-sweetspot "l2_bridging_cnf${i}" 0
	done

	l2-throughput-sweetspot "l2_xconnect" 0
}

#### multimac latency testing ####
function multimac_latency_testing () {
	for s in {1..40}
	do
		i=$((s*25000))
		istr=`printf "%08i" $i`
		l2-throughput-sweetspot "l2_multimac_$istr" $i
	done
	l2-throughput-sweetspot "l2_multimac_00000100" 100
	l2-throughput-sweetspot "l2_multimac_00001000" 1000
	l2-throughput-sweetspot "l2_multimac_00005000" 5000
	l2-throughput-sweetspot "l2_multimac_00010000" 10000
	l2-throughput-sweetspot "l2_multimac_00015000" 15000
	l2-throughput-sweetspot "l2_multimac_00020000" 20000
}

function multimac_latency_testing_hires () {
	for run in {0..5}
	do
		for s in {1..50}
		do
			i=$((s*200))
			istr=`printf "%06i" $i`
			l3-throughput-routes "l3_latroutes1_${istr}_${run}" $i 1
			l3-throughput-routes "l3_latroutes255k_${istr}_${run}" $i 255116
		done
	done
}

#### multimac throughput testing ####
function multimac_throughput_testing () {
	# 6 runs with 47 different l2fib sizes each = 282
	for run in {0..5}
	do
		for s in {1..47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			l2-throughput-complex "l2_throughmac_${istr}_$run" 100000 $i
		done
	done
}

# #### l3 ip4 multicore testing ####
function l3ip4_multicore_testing () {
	for run in {0..5}
	do
		max=6
		for s in $(seq 0 $max)
		do
			sstr=`printf "%02i" $s`
			l3-throughput-complex "l3_multicore_${sstr}_$run" 100000 $(($max*4))
		done
	done
}

# #### l3 ip6 multicore testing ####
function l3ip6_multicore_testing () {
	for run in {0..5}
	do
		max=6
		for s in $(seq 0 $max)
		do
			sstr=`printf "%02i" $s`
			test-throughput "l3v6_multicore_${sstr}_$run" "${BINDIR}/MoonGen moongen-scripts/l3v6-throughput.lua $TX_DEV $RX_DEV --rate 100000 --flows $(($max*4))"
		done
	done
}

# #### l3 ip4 routing ####
function l3ip4_routing_testing () {
	# 6 runs with 37 different l2fib sizes each = 222
	for run in {0..5}
	do
		for s in {1..37} # 47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			l3-throughput-routes "l3_routes_${istr}_$run" 100000 $i
		done
	done
}

# #### l3 ip6 routing ####
function l3ip6_routing_testing () {
	# 6 runs with 37 different l2fib sizes each = 222
	for run in {0..5}
	do
		for s in {1..37} # 47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			test-throughput "l3v6_routes_${istr}_$run" "${BINDIR}/MoonGen moongen-scripts/l3v6-throughput.lua $TX_DEV $RX_DEV --rate 100000 --routes $i --ipDst ::3:0:0:0:2"
		done
	done
}

#### l3 ip4 routing legacy: v16.09 ####
function l3ip4_routing_legacy () {
	6 runs with 50 different l3fib sizes each = 300
	for run in {0..5}
	do
		for s in {1..48} # 47}
		do
			i=`echo "1.4^$s" | bc`
			i=`printf "%.0f" $i`
			istr=`printf "%08i" $i`
			test-throughput "l3_routes_${istr}_$run" "${BINDIR}/MoonGen moongen-scripts/l3-throughput.lua $TX_DEV $RX_DEV --rate 100000 --routes $i --ipDst 10.3.0.0 --ethDst 00:1b:21:94:de:b4"
		done

		# 2^20
		i=`echo "2^20" | bc`
		i=`printf "%.0f" $i`
		istr=`printf "%08i" $i`
		test-throughput "l3_routes_${istr}_$run" "${BINDIR}/MoonGen moongen-scripts/l3-throughput.lua $TX_DEV $RX_DEV --rate 100000 --routes $i --ipDst 10.3.0.0 --ethDst 00:1b:21:94:de:b4"

		# 2^23
		i=`echo "2^23" | bc`
		i=`printf "%.0f" $i`
		istr=`printf "%08i" $i`
		test-throughput "l3_routes_${istr}_$run" "${BINDIR}/MoonGen moongen-scripts/l3-throughput.lua $TX_DEV $RX_DEV --rate 100000 --routes $i --ipDst 10.3.0.0 --ethDst 00:1b:21:94:de:b4"
	done
}

#### vxlan encap throughput ####
function vxlan_throughput_testing () {
	./MoonGen/build/MoonGen ./moongen-scripts/vxlan-throughput2.lua 2 3
}

#### conext experiments ####

# xconnect: 2*60 runs
function xconext_tests () {
	# test vpp max badge size 256
	# do 0 - 10G in 500th steps
	for throughput in {1..20}
	do
		t=`echo "$throughput * 500" | bc`
		t=`printf "%.0f" $t`
		tstr=`printf "%06i" $t`
		# do different packet sizes/mixes (64, 512, 1522)
		l2-throughput-conext "l2_xconnext_0256_0064_${tstr}" $t 60
		l2-throughput-conext "l2_xconnext_0256_0512_${tstr}" $t 508
		l2-throughput-conext "l2_xconnext_0256_1522_${tstr}" $t 1518
		# TODO l2-throughput-conext "l2_xconnext_0256_IMIX_${tstr}" $t IMIX
	done

	# test vpp max badge size 16
	# do 0 - 10G in 500th steps
	for throughput in {1..20}
	do
		t=`echo "$throughput * 500" | bc`
		t=`printf "%.0f" $t`
		tstr=`printf "%06i" $t`
		# do different packet sizes/mixes (64, 512, 1522)
		l2-throughput-conext "l2_xconnext_0016_0064_${tstr}" $t 60
		l2-throughput-conext "l2_xconnext_0016_0512_${tstr}" $t 508
		l2-throughput-conext "l2_xconnext_0016_1522_${tstr}" $t 1518
		# TODO l2-throughput-conext "l2_xconnext_0016_IMIX_${tstr}" $t IMIX
	done
}

#### run test functions ####

xconext_tests
#bridge_simple_test
# bridge_config_testing
# multimac_latency_testing
# multimac_latency_testing_hires
# multimac_throughput_testing
# l3ip4_multicore_testing
# l3ip6_multicore_testing
# l3ip4_routing_testing
# l3ip6_routing_testing
# l3ip4_routing_legacy
# vxlan_throughput_testing

echo "all done"
