#!/bin/bash
# expects to be run from MoonGen root

# exit on error
set -e
# log every command
set -x

LOADGEN=MoonGen

# build moongen
./build.sh
./setup-hugetlbfs.sh

# disable turbo boost preliminarily
echo 1 >   /sys/devices/system/cpu/intel_pstate/no_turbo

# set preliminary frequency
echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
echo 100 > /sys/devices/system/cpu/intel_pstate/min_perf_pct

echo 'all done'
