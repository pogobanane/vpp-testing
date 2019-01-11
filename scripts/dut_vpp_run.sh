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

# read vars
INT_SRC=`pos_get_variable -r vpp/int_src`
INT_DST=`pos_get_variable -r vpp/int_dst`

VPP_PNAME="vpp_main"

# set clean up vpp
function cleanup_vpp () {
	set +e # ingore the follwing 2 possible errors
	pkill $VPP_PNAME
	rm -f /dev/shm/db /dev/shm/global_vm /dev/shm/vpe-api
	set -e
	modprobe uio_pci_generic
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
# $2: filename for perf-record.data
# $3: time to collect (in sec).
function perf-collect () {
	# TODO: 
	# numastat
	# sudo perf stat -x, -o perfstat.out thunar
	hwevents="branch-instructions,\
branch-misses,\
cache-misses,\
ref-cycles,\
cache-references"
	unused="cpu-cycles,\
instructions,\
idle-cycles-frontend"
	cacheevents="L1-dcache-load-misses,\
L1-dcache-loads,\
L1-dcache-store-misses,\
L1-dcache-stores,\
LLC-load-misses,\
LLC-loads,\
LLC-store-misses,\
LLC-stores,\
branch-load-misses,\
branch-loads"
	unused="L1-dcache-prefetch-misses,\
L1-icache-load-misses,\
dTLB-load-misses,\
dTLB-loads,\
dTLB-store-misses,\
dTLB-stores"

	vpp_pid=`pgrep $VPP_PNAME`

	perf stat -x";" -e "$hwevents,$cacheevents" -o "$1" -t $vpp_pid sleep $3 &
	perf record -o "$2" -t $vpp_pid sleep $3 &
	wait
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
	perfdatafile="/tmp/$jobname.perfrecord.data"
	vppfile="/tmp/$jobname.vpp.out"

	echo "Starting bridging test $1"

	# pos_run COMMMAND_ID -- COMMAND
	cleanup_vpp
	# pos_sync
	pos_run $jobname -- $2 $INT_SRC $INT_DST $3
	pos_sync #s1 vpp is set up
	# pos_run l2_bridging_0_whiteboxing -- ${GITDIR}/scripts/vpp_tests/whiteboxinfo.sh 10

	pos_sync #s21: moogen should be generating load now
	
	perf-collect "$perfstatfile" "$perfdatafile" 10

	pos_sync #s31: vpp side live data collection done
	pos_sync #s32: moongen is now terminating
	
	echo "collecting vpp info and upload files..."
	vpp-collect "$vppfile"
	pos_upload $perfdatafile
	pos_upload $perfstatfile
	pos_upload $vppfile

	# wait for test done signal
	pos_sync #s42: test end
	echo "Stopped test"

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $1
}

for i in {0..5}
do
	vpp-test "l2_bridging_cnf${i}" "${GITDIR}/scripts/vpp_tests/l2-bridging.sh" "${i}"
done

vpp-test "l2_xconnect_setup" "${GITDIR}/scripts/vpp_tests/l2-xconnect.sh"

vppcmd="${GITDIR}/scripts/vpp_tests/l2-bridging.sh"
vpp-test "l2_bridging_mbit5000" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4950" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4900" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4850" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4800" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4750" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4700" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4650" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4600" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4550" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4500" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4450" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4400" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4350" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4300" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4250" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4200" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4150" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4100" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4050" "$vppcmd" "0"
vpp-test "l2_bridging_mbit4000" "$vppcmd" "0"
vpp-test "l2_bridging_mbit2000" "$vppcmd" "0"
vpp-test "l2_bridging_mbit1000" "$vppcmd" "0"
vpp-test "l2_bridging_mbit0500" "$vppcmd" "0"

vppcmd="${GITDIR}/scripts/vpp_tests/l2-multimac.sh"
vpp-test "l2_multimac_100" "$vppcmd" 100
vpp-test "l2_multimac_1000" "$vppcmd" 1000
vpp-test "l2_multimac_10000" "$vppcmd" 10000
vpp-test "l2_multimac_100000" "$vppcmd" 100000
vpp-test "l2_multimac_1000000" "$vppcmd" 1000000
vpp-test "l2_multimac_10000000" "$vppcmd" 10000000

echo "all done"
