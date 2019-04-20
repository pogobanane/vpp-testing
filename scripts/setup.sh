# expects to be run from the ba-okelmann project root

# hosts. The two experiment scripts demonstrate how to use all of the postools on the hosts.
# The experiment is to run one of the example MoonGen scripts

if [ "$#" -lt 2 ]; then
	echo "Usage: setup.sh dut loadgen"
	exit
fi

DUT=$1
LOADGEN=$2
VPPVERSION=$3 # can be empty or 16.09

# exit on error
set -e

# takes resolvable host as $1
# blocks and pings host until he responds
function posping() {
	set +x
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
	set -x
}

echo "set images to debian stretch"
pos nodes image "$DUT" debian-stretch
pos nodes image "$LOADGEN" debian-stretch

echo "reboot experiment hosts..."
# run reset blocking in background and wait for processes to end before continuing
pos nodes reset "$DUT" &
pos nodes reset "$LOADGEN" &
# `wait` may not be enough because reset's wait might time out before nodes
# are back online. 
# give nodes time to shut down for posping to work
sleep 30
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
	ssh "$DUT" "cd ba-okelmann/vpp && ../scripts/dut_vpp_build_install${VPPVERSION}.sh"
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
