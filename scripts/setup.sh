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
# set -e # dont do this. Otherwise you will not free the hosts. 
# log every command
set -x

# takes resolvable host as $1
function posping() {
	printf "%s" "waiting for $1 to come online"
	i=0
	while ! ping -c 1 -n -w 1 "$1" &> /dev/null
	do
		if [ $i -gt 800 ]; then
			echo "server didnt come online ERROR"
			exit 1
		fi
		printf "%c" "."
		sleep 2
		i=$(($i+1))
	done
	echo ""
	echo "server is online"
}

# allocate all hosts for ONE experiment
echo "allocate hosts"
pos allocations allocate "$DUT"
pos allocations allocate "$LOADGEN"

echo "set images to debian stretch"
pos nodes image "$DUT" debian-stretch
pos nodes image "$LOADGEN" debian-stretch

echo "load pos vars"
pos allocations variables "$DUT" scripts/dut_test1.yaml
pos allocations variables "$LOADGEN" scripts/dut_test1.yaml

echo "reboot experiment hosts..."
# run reset blocking in background and wait for processes to end before continuing
pos nodes reset "$DUT" &
pos nodes reset "$LOADGEN" &
#wait

# better wait (longer timeout)
posping "$DUT"
posping "$LOADGEN"

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
	ssh "$DUT" "cd ba-okelmann/vpp && ../scripts/dut_vpp_build_install.sh"
	echo "$DUT vpp installed"
} &
{
	ssh "$LOADGEN" "cd ba-okelmann/MoonGen && ../scripts/loadgen_build.sh"
	echo "$LOADGEN MoonGen installed"
} &
wait

echo "pos bootstraping"
pos nodes bootstrap $DUT
pos nodes bootstrap $LOADGEN

echo "run test..."
#pos nodes cmd --infile dut_vpp_run.sh "$DUT"
echo "$DUT finished test"
wait

echo "allocate hosts"
pos allocations free "$DUT"
pos allocations free "$LOADGEN"
