.PHONY: default-target prepare-offline-build init-modules init-moongen-modules download-vpp-ext-deps

absPath=`pwd`

default-target:
	echo "no build targets available"

prepare-offline-build: init-modules init-moongen-modules download-vpp-ext-deps

init-modules:
	git submodule update --init --remote vpp
	git submodule update --init MoonGen

# extracted git pulls from Moongen
init-moongen-modules:
	cd MoonGen
	git submodule update --init
	cd libmoon
	git submodule update --init --recursive
	cd "$absPath"

download-vpp-ext-deps:
	cd vpp
	apt-get -y install make gcc sudo
	UNATTENDED=y make install-dep
	UNATTENDED=y make install-ext-deps # this actually downloads for compiling important things to the vpp folder!
	cd "$absPath"