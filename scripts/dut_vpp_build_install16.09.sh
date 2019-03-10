# tested on debian stretch mini
# expects to be in the vpp repo root

# exit on error
set -e

apt-get update

# deps for some scripts/vpp-tests
apt-get -y install socat linux-tools

# driver for some 40G NICs
#apt-get -y install dpdk-igb-uio-dkms

## build vpp using a recent version to prepare for the older build
apt-get -y install make gcc sudo
UNATTENDED=y make install-dep
UNATTENDED=y make install-ext-deps
make build-release

# now build vpp using the old version
git checkout v16.09
apt-get -y install bison
rm -r build-root/install-vpp-native/
rm -r build-root/build-vpp-native
make build-release

# disable turbo boost preliminarily
echo 1 >   /sys/devices/system/cpu/intel_pstate/no_turbo

# set preliminary frequency
echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct
echo 100 > /sys/devices/system/cpu/intel_pstate/min_perf_pct

# Artifacts:
# ls build-root/*.deb

## install
# dpkg -i build-root/vpp-lib_*_amd64.deb
# dpkg -i build-root/vpp_*_amd64.deb
# dpkg -i build-root/vpp-plugins_*_amd64.deb


# running
# essential functionality (as dpdk) is implemented as plugins. You need the
# plugins.

# Network interfaces deadlock busy waiting during vpp start when there is
# insufficient memory for socket-mem!

## verify/check installation
# systemctl stop vpp
# systemctl disable vpp
# nvm this paragraph
#`vpp.service`
#`'linux-vdso.so.1': No such file or directory` is expected.
#``
#`vppctl show int` should work.
