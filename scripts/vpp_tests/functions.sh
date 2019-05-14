#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $1: INT_SRC; $2: INT_DST
# example: TenGigabitEthernet5/0/0
INT_SRC="$1"
INT_DST="$2"

# expects $3: INT_SRC_PCI; $4: INT_DST_PCI
# exmaple: 0000:05:00.0
INT_SRC_PCI=$3
INT_DST_PCI=$4

MAC_SRC="00:11:22:33:44:55"
MAC_DST="00:00:00:00:00:00"
INT_SRC_MAC="de:ad:be:ef:00:02"
INT_DST_MAC="de:ad:be:ef:00:04"

INT_SRC_IP="10.1.0.2/24" #ip of recieving interface with subnet like: "1.2.3.4/24"
INT_DST_IP="10.2.0.2/24"
INT_SRC_IP6="::1:0:0:0:2/64"
INT_DST_IP6="::2:0:0:0:2/64"

DST_IP="10.2.0.3" # ip of recieving device in the INT_DST_IP subnet
DST_IP6="::2:0:0:0:3"

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

config_singlethreaded="
unix {
	exec $VPP_EXEC
	cli-listen $VPP_CLI_LISTEN
}
dpdk {
	socket-mem 1024,1024
	dev $INT_SRC_PCI
	dev $INT_DST_PCI
}
"

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
	dev $INT_SRC_PCI {
		num-rx-queues 1
	}
	dev $INT_DST_PCI {
		num-rx-queues 1
	}
}
"

config_2worker="
unix {
	exec $VPP_EXEC
	cli-listen $VPP_CLI_LISTEN
}
cpu {
	main-core 1
	corelist-workers 4-5
}
dpdk {
	socket-mem 1024,1024
	dev $INT_SRC_PCI {
		num-rx-queues 2
	}
	dev $INT_DST_PCI {
		num-rx-queues 2
	}
}
"
