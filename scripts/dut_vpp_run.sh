#!/bin/bash
# expects a dut_test*.yaml
# expects the ba-okelmann git to be checked out at ~/ba-okelmann
GITDIR="/root/ba-okelmann"
# changing only this will probably not work
BINDIR="${GITDIR}/vpp/build-root/install-vpp_debug-native/vpp/bin"
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

# load driver
modprobe $(pos_get_variable -r vpp/driver)

# read vars
INT_SRC=`pos_get_variable -r vpp/int_src`
INT_DST=`pos_get_variable -r vpp/int_dst`
INT_SRC_PCI=`pos_get_variable -r vpp/int_src_pci`
INT_DST_PCI=`pos_get_variable -r vpp/int_dst_pci`

VPP_PNAME="vpp_main"

# set clean up vpp
function cleanup_vpp () {
	set +e # ingore the follwing 2 possible errors
	pkill $VPP_PNAME
	rm -f /dev/shm/db /dev/shm/global_vm /dev/shm/vpe-api
	set -e
}

# does this work?
# $1: basemac as hex number bigger 0x20 00 00 00 00 00
# $2: nr. of macs to add
function add_macs () {
	upper=$(($1+$2-1))
	for i in $(seq $1 $upper)
	do
		mac=`printf "%x" $i | sed 's/./&:/10;s/./&:/8;s/./&:/6;s/./&:/4;s/./&:/2'`
		addmac="l2fib add $mac 1 $INT_DST"
		echo "$addmac" | socat - UNIX-CONNECT:/tmp/vpptesting_cli
	done
}

# load some variables
# VPP_CONFIG=$(pos_get_variable vpp/config)

echo 'Done setting up'
pos_sync
echo 'sync done'

# this function is blocking!
# $1: filename for perf-stat.csv
# $2: filename for perf-record (without .csv or .data appendix)
# $3: time to collect (in sec).
function perf-collect () {
	# TODO: 
	# numastat
	# sudo perf stat -x, -o perfstat.out thunar
	hwevents="branch-instructions,\
branch-misses,\
cache-misses,\
ref-cycles,\
cpu-cycles"
	unused="
cache-references,\
instructions,\
idle-cycles-frontend"
	cacheevents="L1-dcache-load-misses,\
L1-dcache-loads,\
L1-dcache-prefetch-misses,\
LLC-loads,\
LLC-load-misses,\
LLC-prefetches,\
LLC-prefetch-misses,\
branch-load-misses,\
branch-loads"
	unused="L1-icache-load-misses,\
L1-dcache-store-misses,\
L1-dcache-stores,\
LLC-store-misses,\
LLC-stores,\
dTLB-load-misses,\
dTLB-loads,\
dTLB-store-misses,\
dTLB-stores"

	vpp_pid=`pgrep $VPP_PNAME`

	perf stat -x";" -e "$hwevents,$cacheevents" -o "$1" -t $vpp_pid sleep $3 &
	perf record -o "${2}.data" -t $vpp_pid sleep $3 &
	wait
	perf report -i "${2}.data" --field-separator=";" > ${2}.csv
}

# $1: filename for vpp output like vpp-stats
function vpp-collect () {
	echo "show err" | socat - UNIX-CONNECT:/tmp/vpptesting_cli | tail -n +1 > $1
}

# $1: jobname
# $2: command
# $3: additional args for command
function vpp-test () {
	jobname=$1
	perfstatfile="/tmp/$jobname.perfstat.csv"
	perfdataname="/tmp/$jobname.perfrecord" # without .csv appendix
	vppfile="/tmp/$jobname.vpp.out"

	echo "Starting bridging test $1"

	# pos_run COMMMAND_ID -- COMMAND
	cleanup_vpp
	# pos_sync
	pos_run $jobname -- $2 $INT_SRC $INT_DST $3
	pos_sync #s1 vpp is set up
	# pos_run l2_bridging_0_whiteboxing -- ${GITDIR}/scripts/vpp_tests/whiteboxinfo.sh 10

	pos_sync #s21: moogen should be generating load now
	
	perf-collect "$perfstatfile" "$perfdataname" 10

	pos_sync #s31: vpp side live data collection done
	pos_sync #s32: moongen is now terminating
	
	echo "collecting vpp info and upload files..."
	vpp-collect "$vppfile"
	pos_upload ${perfdataname}.csv
	pos_upload $perfstatfile
	pos_upload $vppfile

	# wait for test done signal
	pos_sync #s42: test end
	echo "Stopped test" # ~46s

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $1
}

# does 9 test runs!
# $1: jobname
# $2: cmd to run
# $3: arg for cmd
function vpp-find-sweetspot () {
	spjobname="$1"
	cmd="$2"
	cmdarg="$3"

	# # measure everything with low resolution
	# for s in {1..15}
	# do
	# 	i=$((s*400))
	# 	istr=`printf "%04i" $i`
	# 	vpp-test "${spjobname}_mbit$istr" "$cmd" "$cmdarg"
	# done

	# Try to find max_throughput
	vpp-test "${spjobname}_mbit9000" "$cmd" "$cmdarg"
	for i in {0..6}
	do
		istr=`printf "%04i" $i`
		vpp-test "${spjobname}_mbit${istr}hires" "$cmd" "$cmdarg"
	done

	# final test
	vpp-test "${spjobname}_mbit0000_final" "$cmd" "$cmdarg"
}

#### bridge config testing ####

# for i in {0..5}
# do
# 	vpp-find-sweetspot "l2_bridging_cnf${i}" "${GITDIR}/scripts/vpp_tests/l2-bridging.sh" "${i}"
# done

# vpp-find-sweetspot "l2_xconnect" "${GITDIR}/scripts/vpp_tests/l2-xconnect.sh"

#### multimac latency testing ####

# vppcmd="${GITDIR}/scripts/vpp_tests/l2-multimac.sh"
# for s in {1..40}
# do
# 	i=$((s*25000))
# 	istr=`printf "%08i" $i`
# 	vpp-find-sweetspot "l2_multimac_$istr" "$vppcmd" $i
# done
# vpp-find-sweetspot "l2_multimac_00000100" "$vppcmd" 100
# vpp-find-sweetspot "l2_multimac_00001000" "$vppcmd" 1000
# vpp-find-sweetspot "l2_multimac_00005000" "$vppcmd" 5000
# vpp-find-sweetspot "l2_multimac_00010000" "$vppcmd" 10000
# vpp-find-sweetspot "l2_multimac_00015000" "$vppcmd" 15000
# vpp-find-sweetspot "l2_multimac_00020000" "$vppcmd" 20000

#### multimac throughput testing ####

# 5 runs with 47 different l2fib sizes each = 235
# vppcmd="${GITDIR}/scripts/vpp_tests/l2-multimac.sh"
# for run in {0..14}
# do
# 	for s in {1..47}
# 	do
# 		i=`echo "1.4^$s" | bc`
# 		i=`printf "%.0f" $i`
# 		istr=`printf "%08i" $i`
# 		vpp-test "l2_throughmac_${istr}_$run" "$vppcmd" $i
# 	done
# done

#### l3 ip4 multicore testing ####

# vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-flows.sh"
# for run in {0..5}
# do
# 	max=8
# 	for s in $(seq 0 $max)
# 	do
# 		sstr=`printf "%02i" $s`
# 		j=$((1+$s))
# 		vpp-test "l3_multicore_${sstr}_$run" "$vppcmd" "${INT_SRC_PCI} ${INT_DST_PCI} $s 2-$j"
# 	done
# done

#### l3 ip6 multicore testing ####

vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip6-flows.sh"
for run in {0..0}
do
	max=8
	for s in $(seq 0 $max)
	do
		sstr=`printf "%02i" $s`
		j=$((1+$s))
		vpp-test "l3v6_multicore_${sstr}_$run" "$vppcmd" "${INT_SRC_PCI} ${INT_DST_PCI} $s 2-$j"
	done
done


#### l3 ip4 routing ####

# 5 runs with 47 different l2fib sizes each = 235
# vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-routing.sh"
# for run in {0..5}
# do
# 	for s in {1..37} # 47}
# 	do
# 		i=`echo "1.4^$s" | bc`
# 		i=`printf "%.0f" $i`
# 		istr=`printf "%08i" $i`
# 		vpp-test "l3_routes_${istr}_$run" "$vppcmd" "$INT_SRC_PCI $INT_DST_PCI 1 2 $i"
# 	done
# done

#### l3 ip6 routing ####

# 5 runs with 47 different l2fib sizes each = 235
vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip6-routing.sh"
for run in {0..0}
do
	for s in {1..37} # 47}
	do
		i=`echo "1.4^$s" | bc`
		i=`printf "%.0f" $i`
		istr=`printf "%08i" $i`
		vpp-test "l3v6_routes_${istr}_$run" "$vppcmd" "$INT_SRC_PCI $INT_DST_PCI 1 2 $i"
	done
done

#### l3 ip4 routing legacy: v16.09 ####

# 5 runs with 47 different l2fib sizes each = 235
# vppcmd="${GITDIR}/scripts/vpp_tests/l3-ip4-routinglegacy.sh"
# for run in {0..5}
# do
# 	for s in {1..50} # 47}
# 	do
# 		i=`echo "1.4^$s" | bc`
# 		i=`printf "%.0f" $i`
# 		istr=`printf "%08i" $i`
# 		vpp-test "l3_routes_${istr}_$run" "$vppcmd" "$INT_SRC_PCI $INT_DST_PCI 1 2 $i"
# 	done

# 	# 2^20
# 	i=`echo "2^20" | bc`
# 	i=`printf "%.0f" $i`
# 	istr=`printf "%08i" $i`
# 	vpp-test "l3_routes_${istr}_$run" "$vppcmd" "$INT_SRC_PCI $INT_DST_PCI 1 2 $i"

# 	# 2^24
# 	i=`echo "2^24" | bc`
# 	i=`printf "%.0f" $i`
# 	istr=`printf "%08i" $i`
# 	vpp-test "l3_routes_${istr}_$run" "$vppcmd" "$INT_SRC_PCI $INT_DST_PCI 1 2 $i"
# done

#### vxlan throughput ####

# vpp-test "vxlan_encap" "${GITDIR}/scripts/vpp_tests/vxlan-encapsulated.sh" "${INT_SRC_PCI} ${INT_DST_PCI}"

echo "all done"
