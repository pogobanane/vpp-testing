# tested on debian stretch mini
# expects to be in the vpp repo root

# exit on error
set -e

# deps for some scripts/vpp-tests
apt-get -y install socat linux-tools

# driver for some 40G NICs
apt-get -y install dpdk-igb-uio-dkms

## build vpp

#apt-get install git
#git clone https://gerrit.fd.io/r/vpp
apt-get -y install make gcc sudo
# dont do this maybe?  ./build-root/vagrant/build.sh
UNATTENDED=y make install-dep
UNATTENDED=y make install-ext-deps
# make release build and package for .deb
make build-release

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
