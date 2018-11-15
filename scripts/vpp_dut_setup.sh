# deprivated
apt-get install apt-transport-https
echo "deb [trusted=yes] https://nexus.fd.io/content/repositories/fd.io.ubuntu.xenial.main/ ./" > /etc/apt/sources.list.d/99fd.io.list
apt-get update
wget http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u9_amd64.deb
dpkg -i libssl1.0.0_1.0.1t-1+deb8u9_amd64.deb
#apt-get install libc6 libgcc1 libstdc++6
#apt-get download vpp-lib
#dpkg -i --ignore-depends=libssl1.0.0 vpp-lib_18.07.1-release_amd64.deb
apt-get install vpp-lib
apt-get install vpp
