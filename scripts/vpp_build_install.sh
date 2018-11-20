# tested on debian stretch mini
# expects to be in the vpp repo root

## build vpp

#apt-get install git
#git clone https://gerrit.fd.io/r/vpp
apt-get -y install make gcc sudo
./build-root/vagrant/build.sh
make install-dep
make install-ext-deps
# make release build and package for .deb
make pkg-deb

# Artifacts:
# ls build-root/*.deb

## install
dpkg -i "build-root/vpp-lib_19.01-rc0~249-gb4d30534_amd64.deb"
dpkg -i "build-root/vpp_19.01-rc0~249-gb4d30534_amd64.deb"
dpkg -i "build-root/vpp-plugins_19.01-rc0~249-gb4d30534_amd64.deb"


# running
# essential functionality (as dpdk) is implemented as plugins. You need the
# plugins.

# Network interfaces deadlock busy waiting during vpp start when there is
# insufficient memory for socket-mem!

## verify/check installation
# nvm this paragraph
#`vpp.service`
#`'linux-vdso.so.1': No such file or directory` is expected.
#``
#`vppctl show int` should work.
