#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $3: INT_SRC_PCI; $4: INT_DST_PCI
INT_SRC_PCI=$3
INT_DST_PCI=$4

# expects $1: INT_SRC; $2: INT_DST
source scripts/vpp_tests/functions.sh

bdid=7 # bridge domain id
exec="set int state $INT_DST up

create bridge-domain $bdid learn 0 uu-flood 0 flood 0

create vxlan tunnel src 10.1.0.2 dst 10.2.0.2 vni $bdid instance $bdid

set int state $INT_SRC up

set int l2 bridge vxlan_tunnel$bdid $bdid
set int l2 bridge $INT_SRC $bdid bvi
set int mac address $INT_SRC $INT_SRC_MAC
set int ip address $INT_SRC 10.1.0.2/24

l2fib add $INT_SRC_MAC $bdid vxlan_tunnel$bdid
l2fib add $MAC_SRC $bdid $INT_SRC
l2fib add $MAC_DST $bdid $INT_DST
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