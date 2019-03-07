#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $3: INT_SRC_PCI; $4: INT_DST_PCI
INT_SRC_PCI=$3
INT_DST_PCI=$4

# expects $1: INT_SRC; $2: INT_DST
source scripts/vpp_tests/functions.sh

# expects $5: workers count
# expects $6 if $5 not 0: corelist range like "2-3,6-7"
# expects $7: route-count
workers=$5
corelist=$6
routes=$7

# set ip arp GigabitEthernet2/0/1 10.2.0.3 dead.beef.bab0 static
#ip route add 10.3.0.1/30 via 10.2.0.3 GigabitEthernet2/0/1
exec="set int state $INT_SRC up
set int state $INT_DST up

set int mac address $INT_SRC $INT_SRC_MAC
set int mac address $INT_DST $INT_DST_MAC

set int ip address $INT_SRC $INT_SRC_IP
set int ip address $INT_DST $INT_DST_IP

set ip arp $INT_DST 0.0.1.1 $MAC_DST static
set ip arp $INT_DST 0.0.1.2 $MAC_DST static
set ip arp $INT_DST 0.0.1.3 $MAC_DST static
set ip arp $INT_DST 0.0.1.4 $MAC_DST static
ip route add count $routes 0.0.2.0/24 via 0.0.1.1 $INT_DST
ip route add count $routes 64.0.2.0/24 via 0.0.1.2 $INT_DST
ip route add count $routes 128.0.2.0/24 via 0.0.1.3 $INT_DST
ip route add count $routes 192.0.2.0/24 via 0.0.1.4 $INT_DST
"

if [ $workers == 0 ]; then
	test_vpp_with "$config_singlethreaded" "$exec"
else
	config_multithreaded="
unix {
	exec $VPP_EXEC
	cli-listen $VPP_CLI_LISTEN
}
cpu {
	main-core 1
	corelist-workers ${corelist}
}
dpdk {
	socket-mem 1024,1024
	dev ${INT_SRC_PCI} {
		num-rx-queues ${workers}
	}
	dev ${INT_DST_PCI} {
		num-rx-queues ${workers}
	}
}
"
	test_vpp_with "$config_multithreaded" "$exec"
fi