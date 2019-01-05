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
INT_SRC=`pos_get_variable -r vpp/int_scr`
INT_DST=`pos_get_variable -r vpp/int_dst`

# set clean up vpp
function cleanup_vpp () {
	pkill vpp_main
	rm -f /dev/shm/db /dev/shm/global_vm /dev/shm/vpe-api
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

# $1: jobname
# $2: command
# $3: additional args for command
function moon-gen () {
	echo "Starting bridging test $1"

	# pos_run COMMMAND_ID -- COMMAND
	cleanup_vpp
	# pos_sync
	pos_run $1 -- $2 $INT_SRC $INT_DST $3
	pos_sync # vpp is set up
	# pos_run l2_bridging_0_whiteboxing -- ${GITDIR}/scripts/vpp_tests/whiteboxinfo.sh 10

	# moongen is now running tests

	# wait for test done signal
	pos_sync # moongen test done
	echo "Stopped test"

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill $1
}

for i in {0..5}
do
	moon-gen "l2_bridging_${i}_setup" "${GITDIR}/scripts/vpp_tests/l2-bridging.sh" "${i}"
done

moon-gen "l2_xconnect_setup" "${GITDIR}/scripts/vpp_tests/l2-xconnect.sh"

vppcmd="${GITDIR}/scripts/vpp_tests/l2-bridging.sh"
moon-gen "l2_bridging_6800mbit" "$vppcmd" "0"
moon-gen "l2_bridging_7000mbit" "$vppcmd" "0"
moon-gen "l2_bridging_6600mbit" "$vppcmd" "0"
moon-gen "l2_bridging_6400mbit" "$vppcmd" "0"
moon-gen "l2_bridging_6000mbit" "$vppcmd" "0"
moon-gen "l2_bridging_5000mbit" "$vppcmd" "0"
moon-gen "l2_bridging_4000mbit" "$vppcmd" "0"
moon-gen "l2_bridging_2000mbit" "$vppcmd" "0"
moon-gen "l2_bridging_1000mbit" "$vppcmd" "0"
moon-gen "l2_bridging_0500mbit" "$vppcmd" "0"

vppcmd="${GITDIR}/scripts/vpp_tests/l2-multimac.sh"
moon-gen "l2_multimac_100" 100
moon-gen "l2_multimac_1000" 1000
moon-gen "l2_multimac_10000" 10000
moon-gen "l2_multimac_100000" 100000
moon-gen "l2_multimac_1000000" 1000000

echo "all done"
