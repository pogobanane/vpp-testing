#!/bin/bash
# expects to be run from the ba-okelmann project root on a management host

if test "$#" -ne 2; then
	echo "Usage: training.sh dut loadgen"
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

# create bootstrap dataset.csv (random?)
# scp dataset.csv $DUT
scp ~/data2.forest ${DUT}:~/ba-okelmann/

echo "test and evaluate each row from dataset..."
pos commands launch -n --infile scripts/dut_vpp_run.sh "$DUT"
	# loadgen
	# load scenario
	# ranger record input and output - no actually record input (ipcdump) and use forest to calculate output
	# save files with rows "id: in and output"

pos commands launch --infile scripts/loadgen_run.sh "$LOADGEN"
echo "$DUT finished test"

wait

# read results
last=$(ls /srv/testbed/results/okelmann/default | tail -n1)
# run reward function on results and create new dataset to $last
python3 scripts/training/training_set_refine.py $last $DUT $LOADGEN --outfile "trainingset_refined1.csv"


# cp new dataset to $DUT
scp "trainingset_refined1.csv" "$DUT:/tmp/trainingset_refined.csv"
# train with dataset
pos commands launch -b -i scripts/training/ranger_train.sh /tmp/trainingset.csv /tmp/forest1.forest

# apply model
ssh $DUT cp /tmp/forest1.forest ~/ba-okelmann/

# repeat

