# expects to be run from the ba-okelmann project root

if test "$#" -ne 2; then
	echo "Usage: setup.sh dut loadgen"
	exit
fi

DUT=$1
LOADGEN=$2

# exit on error
set -e

# run test

echo "pos bootstraping"
pos nodes bootstrap $DUT
pos nodes bootstrap $LOADGEN

echo "load vars for vpp test"
pos allocations variables $DUT scripts/klaipeda-narva.yaml
pos allocations variables $LOADGEN scripts/klaipeda-narva.yaml

echo "run test..."
pos commands launch -n --infile scripts/dut_vpp_run.sh "$DUT"
pos commands launch --infile scripts/loadgen_run.sh "$LOADGEN"
echo "$DUT finished test"
wait