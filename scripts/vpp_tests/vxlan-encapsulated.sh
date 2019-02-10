#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $3: INT_SRC_PCI; $4: INT_DST_PCI
INT_SRC_PCI=$3
INT_DST_PCI=$4

# expects $1: INT_SRC; $2: INT_DST
source scripts/vpp_tests/functions.sh

bdid=7 # bridge domain id
VTEP_MAC="dead.beef.0070"
VTEP_IP="10.2.0.2"
exec="
set int mac address $INT_SRC $INT_SRC_MAC
set int mac address $INT_DST $INT_DST_MAC

set int state $INT_DST up
ip table add 7
set int ip table TenGigabitEthernet5/0/1 7
set int ip address TenGigabitEthernet5/0/1 10.1.0.2/24

create bridge-domain $bdid learn 0 uu-flood 0 flood 0
create loopback interface mac dead.beef.0010 instance $bdid
create vxlan tunnel src 10.1.0.2 dst $VTEP_IP vni $bdid instance $bdid encap-vrf-id $bdid decap-next l2

set int state loop$bdid up
set int state $INT_SRC up

set int l2 bridge $INT_SRC $bdid 0 
set int l2 bridge vxlan_tunnel$bdid $bdid 1
set int l2 bridge loop$bdid $bdid bvi 0

set ip arp ...

l2fib add dead.beef.0010 $bdid $loop$bdid
l2fib add $MAC_SRC $bdid $INT_SRC
l2fib add $MAC_DST $bdid vxlan_tunnel$bdid
l2fib add $VTEP_MAC $bdid $INT_DST

sh vlib graph vxlan4-encap
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