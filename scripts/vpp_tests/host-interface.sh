#!/bin/bash
# has to be run from vpp-testing dir

set -x

ip link add name vpp1out type veth peer name vpp1host
ip link set dev vpp1out up
ip link set dev vpp1host up
ip addr add 10.10.1.1/24 dev vpp1host


echo "
create host-interface name vpp1out
set int state host-vpp1out up
set int up address host-vpp1out 10.10.1.2/24
" > /tmp/vpptesting_exec.vpp

echo "
unix {
	exec /tmp/vpptesting_exec.vpp
	cli-listen /tmp/vpptesting_cli
}
" > /tmp/vpptesting_startup.conf

./vpp/build-root/install-vpp-native/vpp/bin/vpp -c /tmp/vpptesting_startup.conf

echo "suggestion:"
echo "trace add af-packet-input 10"
echo "ping -c 1 10.10.1.2"
echo "Remember: This scipts probably needs root permissions to set up virtual interfaces on your host. "
