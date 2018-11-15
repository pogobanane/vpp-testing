# hosts. The two experiment scripts demonstrate how to use all of the postools on the hosts.
# The experiment is to run one of the example MoonGen scripts

if test "$#" -ne 1; then
	echo "Usage: setup.sh dut"
	exit
fi

DUT=$2

# allocate all hosts for ONE experiment
echo "allocate hosts"
pos allocations allocate "$DUT"

echo "load experiment variables"
pos allocations variables "$DUT" dut-variables.yaml

echo "set images to debian stretch"
pos nodes image "$DUT" debian-stretch

echo "reboot experiment hosts..."
# run reset blocking in background and wait for processes to end before continuing
{ pos nodes reset "$DUT"; echo "$DUT booted successfully"; } &
wait

echo "transferring binaries to $DUT..."
pos nodes push "$DUT" vpp.deb
pos nodes push "$DUT" vpp-lib.deb
pos nodes push "$DUT" vpp-plugins.deb
echo "done"

echo "deploy & run experiment scripts..."
{ pos nodes cmd --infile dut.sh "$DUT"; echo "$DUT userscript executed"; } &
wait
