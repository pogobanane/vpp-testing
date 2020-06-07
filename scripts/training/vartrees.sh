#!/bin/bash

set -e

root=$(dirname $0)/../..

function foo() {
	inputs=$1
	istr=$(printf "%03i" $inputs)
	echo "###"
	echo "### $istr"
	echo "###"
	$root/scripts/training/training_set_bootstrap.py $root/training_test/2019-12-05_11-09-22_533375 \
		-t treesize${istr}_trainingset.csv -a treesize${istr}_validationset.csv \
		-n 100 -r -i ${inputs}
	echo "Training forest."
	$root/ranger/cpp_version/build/ranger ranger --treetype=3 \
		--file="treesize${istr}_trainingset.csv" --write \
		--outprefix="treesize${istr}" --depvarname="result"
	echo "Validating forest."
	$root/ranger/cpp_version/build/ranger ranger --treetype=3 \
		--file=treesize${istr}_validationset.csv --outprefix=treesize${istr} \
		--depvarname="result" --predict="treesize${istr}.forest"
}

for inputs in {2..15}
do	
	foo $inputs
done
for inputs in {17..31}
do	
	foo $inputs
done

for inputs in {33..63}
do	
	foo $inputs
done

for inputs in {65..127}
do	
	foo $inputs
done

for inputs in {129..255}
do	
	foo $inputs
done

