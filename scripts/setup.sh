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

# allocate all hosts for ONE experiment
#echo "allocate hosts"
#pos allocations allocate "$DUT"

#echo "set images to debian stretch"
#pos nodes image "$DUT" debian-stretch

#echo "reboot experiment hosts..."
# run reset blocking in background and wait for processes to end before continuing
#{ pos nodes reset "$DUT"; echo "$DUT booted successfully"; } &
#wait

echo "transferring binaries to $DUT and $LOADGEN..."
{
	rsync -r -l --delete ./ "$DUT":~/ba-okelmann/ 
} &
{ 
	rsync -r -l --delete ./ "$LOADGEN":~/ba-okelmann/
} &
wait
echo "done"

# install vpp and moongen

echo "install vpp..."
{ 
	ssh "$DUT" "cd ba-okelmann/vpp && ../scripts/vpp_build_install.sh"
	echo "$DUT vpp installed"
} &
{
	ssh "$LOADGEN" "cd ba-okelmann/MoonGen && ../scripts/loadgen_build.sh"
	echo "$LOADGEN MoonGen installed"
} &
wait

# run test

echo "load vars for vpp test"
pos allocations variables "$DUT" scripts/dut_test1.yaml

echo "run test..."
#pos nodes cmd --infile dut_vpp_run.sh "$DUT"
echo "$DUT finished test"
wait
