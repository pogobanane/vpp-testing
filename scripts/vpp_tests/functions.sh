#!/bin/bash

# expects to be run from the ba-okelmann project root

INT_SRC="TenGigabitEthernet5/0/0"
INT_DST="TenGigabitEthernet5/0/1"

MAC_SRC="00:11:22:33:44:55"
MAC_DST="00:11:22:33:44:56"

VPP_CLI_LISTEN="/tmp/vpptesting_cli"
VPP_CONF="/tmp/vpptesting_startup.conf"
VPP_EXEC="/tmp/vpptesting_exec.vpp"

# param1: vpp startup config
# param2: vpp startup exec script
# note that config has to run exec itself
function test_vpp_with () {
	echo "$1" > "$VPP_CONF"
	echo "$2" > "$VPP_EXEC"
	./vpp/build-root/install-vpp-native/vpp/bin/vpp -c $VPP_CONF
}

config_1worker="
unix {
	exec $VPP_EXEC
	cli-listen $VPP_CLI_LISTEN
}
cpu {
	main-core 1
	corelist-workers 2
}
dpdk {
	socket-mem 1024,1024
}
"