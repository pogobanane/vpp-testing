#!/bin/bash

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

#
# install dut
#
GIT_REPO=$(pos_get_variable git/repo)

DUT=libmoon

echo "Cloning $GIT_REPO into $DUT"
git clone --recursive $GIT_REPO $DUT
cd $DUT
# checkout a particular branch or commit
git checkout $(pos_get_variable git/commit)

# write back the hash of the exact git commit used for reference later
pos_set_variable git/commit-hash $(git rev-parse --verify HEAD)

# build libmoon
./build.sh
./setup-hugetlbfs.sh

#
# install vpp
#
VPP_TESTING_GIT=$(pos_get_variable vpp_testing_git/repo)
VPP_TESTING_DIR=vpp_testing

echo "Cloning $VPP_TESTING_GIT into $VPP_TESTING_DIR"
#### TODO git clone --recursive

# disable turbo boost
echo 1 >   /sys/devices/system/cpu/intel_pstate/no_turbo

# set frequency
echo $(pos_get_variable cpu-freq) > /sys/devices/system/cpu/intel_pstate/max_perf_pct
echo $(pos_get_variable cpu-freq) > /sys/devices/system/cpu/intel_pstate/min_perf_pct

# util
calc_float() {
	echo $(echo "scale=2; $1" | bc)
}

calc_steps() {
	MIN=$(pos_get_variable min)
	MAX=$(pos_get_variable max)
	DELTA=$(pos_get_variable delta)

	# calculation of number of runs and values
	STEP=$MIN
	STEPS=$STEP
	while (( $(bc <<< "$STEP < $MAX ") )) ; do
		STEP=$(calc_float "$STEP + $DELTA")
		STEPS="$STEPS $STEP"
	done

	echo $STEPS
}

# load some variables
RUNTIME=$(pos_get_variable runtime)
PORT_TX=$(pos_get_variable port/tx)
PORT_RX=$(pos_get_variable port/rx)

# calculate the steps for this benchmark
STEPS=$(calc_steps)
echo $STEPS

echo 'Done setting up'
pos_sync
echo 'sync done'

for STEP in $STEPS; do
	pos_sync
	echo "Starting test $STEP"

	# run libmoon in background using pos_run
	# pos_run COMMMAND_ID -- COMMAND
	pos_run dut$STEP -- ./build/$DUT examples/l2-forward.lua \
		$PORT_TX $PORT_RX

	# wait for test done signal
	pos_sync
	echo "Stopped test $STEP"

	# kill the process started with pos_run
	# command/stdout/stderr are uploaded automatically
	pos_kill dut$STEP
done

echo 'all done'
