#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $3: INT_SRC_PCI; $4: INT_DST_PCI
INT_SRC_PCI=$3
INT_DST_PCI=$4

# expects $1: INT_SRC; $2: INT_DST
source scripts/vpp_tests/functions.sh

exec="set int state $INT_SRC up
set int state $INT_DST up

set int ip address $INT_SRC $INT_SRC_IP
set int ip address $INT_DST $INT_DST_IP

set ip arp $INT_DST $DST_IP dead.beef.bab0
"

config_workers="
unix {
	exec $VPP_EXEC
	cli-listen $VPP_CLI_LISTEN
}
cpu {
	main-core 1
	corelist-workers 4-7
}
dpdk {
	socket-mem 1024,1024
	dev ${INT_SRC_PCI} {
		num-rx-queues 2
	}
	dev ${INT_DST_PCI} {
		num-rx-queues 2
	}
}
"

test_vpp_with "$config_workers" "$exec"