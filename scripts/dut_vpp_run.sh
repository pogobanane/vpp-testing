#!/bin/bash
# expects a dut_test*.yaml
# expects the ba-okelmann git to be checked out at ~/ba-okelmann
GITDIR="/root/ba-okelmann"
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

# set clean up vpp
rm -f /dev/shm/db /dev/shm/global_vm /dev/shm/vpe-api
modprobe uio_pci_generic

# load some variables
# VPP_CONFIG=$(pos_get_variable vpp/config)

echo 'Done setting up'
pos_sync
echo 'sync done'

echo "Starting test"

# run libmoon in background using pos_run
# pos_run COMMMAND_ID -- COMMAND
# pos_run vpp-cleanup -- ${GITDIR}/scripts/vpp_tests/cleanup.sh
# pos_sync
pos_run l2_bridging_0_setup -- ${GITDIR}/scripts/vpp_tests/l2-bridging.sh 0
pos_sync
# pos_run l2_bridging_0_whiteboxing -- ${GITDIR}/scripts/vpp_tests/whiteboxinfo.sh 10

# pos r

# wait for test done signal
pos_sync
echo "Stopped test"

# kill the process started with pos_run
# command/stdout/stderr are uploaded automatically
pos_kill l2_bridging_0_setup

echo "all done"
