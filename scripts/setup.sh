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

# allocate all hosts for ONE experiment
#echo "allocate hosts"
#pos allocations allocate "$DUT"

#echo "set images to debian stretch"
#pos nodes image "$DUT" debian-stretch

#echo "reboot experiment hosts..."
# run reset blocking in background and wait for processes to end before continuing
#{ pos nodes reset "$DUT"; echo "$DUT booted successfully"; } &
#wait

echo "transferring binaries to $DUT..."
rsync -r -l --delete ./ "$DUT":~/ba-okelmann/
echo "done"

# install vpp

echo "load vpp installation variables"
pos allocations variables "$DUT" dut_setup_variables.yaml

echo "install vpp..."
pos nodes cmd "$DUT" scripts/vpp_build_install.sh
echo "$DUT vpp installed"

# run test

echo "load vars for vpp test"
pos allocations variables "$DUT" dut_test1.yaml

echo "run test..."
#pos nodes cmd --infile dut_vpp_run.sh "$DUT"
echo "$DUT finished test"
wait
