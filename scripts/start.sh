# expects to be run from the ba-okelmann project root

# hosts. The two experiment scripts demonstrate how to use all of the postools on the hosts.
# The experiment is to run one of the example MoonGen scripts

if test "$#" -ne 1; then
	echo "Usage: setup.sh dut"
	exit
fi

DUT=$1

# exit on error
set -e
# log every command
set -x

# run test

echo "load vars for vpp test"
pos allocations variables "$DUT" scripts/dut_test1.yaml

echo "run test..."
pos nodes cmd --infile scripts/dut_vpp_run.sh "$DUT"
echo "$DUT finished test"
wait
