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

tmp=/tmp/$USER
mkdir -p $tmp

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

# 6min per run
# 100*6 = 600min = 10h
for s in {1..101}
do
	i=`printf "%.0f" $s`
	istr=`printf "%08i" $i`

	echo "==> iteration $i"

	echo "test and evaluate each row from dataset..."
	ssh $DUT "echo -n \"$istr\" > /tmp/pos_commands_param_1" # pass param for pos command
	pos commands launch -n --infile scripts/dut_vpp_run.sh "$DUT"
		# loadgen
		# load scenario
		# ranger record input and output - no actually record input (ipcdump) and use forest to calculate output
		# save files with rows "id: in and output"

	ssh $LOADGEN "echo -n \"$istr\" > /tmp/pos_commands_param_1" # pass param for pos command
	pos commands launch --infile scripts/loadgen_run.sh "$LOADGEN"
	echo "$DUT finished test"

	wait

	# read results
	posroot="/srv/testbed/results/okelmann/default"
	last=$(ls "$posroot" | tail -n1)
	# run reward function on results and create new dataset to $last
	python3 scripts/training/training_set_refine.py $posroot/$last $DUT $LOADGEN --outfile "$tmp/trainingset_refined_$istr.csv" --iteration "$istr" | tee -a $tmp/refinement_$istr.log
	scp "$tmp/refinement_$istr.log" "$DUT:/tmp/"
	ssh $DUT "pos_upload /tmp/refinement_$istr.log"

	# cp new dataset to $DUT
	scp "$tmp/trainingset_refined_$istr.csv" "$DUT:/tmp/"
	ssh $DUT "pos_upload /tmp/trainingset_refined_$istr.csv"
	# train with dataset and pos_upload it
	ssh $DUT "cd ba-okelmann && scripts/training/ranger_train.sh /tmp/trainingset_refined_$istr.csv /tmp/forest_$istr"

	# apply model
	ssh $DUT "cp /tmp/forest_$istr.forest ~/ba-okelmann/data2.forest"

	# repeat
done

