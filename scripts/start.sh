# expects to be run from the ba-okelmann project root

# hosts. The two experiment scripts demonstrate how to use all of the postools on the hosts.
# The experiment is to run one of the example MoonGen scripts

if test "$#" -ne 2; then
	echo "Usage: setup.sh dut loadgen"
	exit
fi

DUT=$1
LOADGEN=$2

# exit on error
set -e
# log every command
set -x

# run test

# allocate all hosts for ONE experiment
# echo "allocate hosts"
# pos allocations allocate "$DUT" "$LOADGEN"

echo "pos bootstraping"
pos nodes bootstrap $DUT
pos nodes bootstrap $LOADGEN

echo "load vars for vpp test"
pos allocations variables $DUT scripts/cesis-nida.yaml
pos allocations variables $LOADGEN scripts/cesis-nida.yaml

echo "run test..."
pos commands launch -n --infile scripts/dut_vpp_run.sh "$DUT"
pos commands launch --infile scripts/loadgen_run.sh "$LOADGEN"
echo "$DUT finished test"
wait

# echo "freeing nodes..."
# pos allocations free "$DUT"
# pos allocations free "$LOADGEN"