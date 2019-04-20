# checking out submodulesbe verbose; must

checkout Moongen. It's build.sh will take care of downloading submodules.

ceck out vpp release v18.10-rc2

git submodule update --init

# Scripts

`scripts/setup.sh` depends on `pos`, assumes nodes are allocated, resets them and compiles required software on them. 

`scripts/start.sh` depends on `pos`, assumes setup.sh succeeded, sets the .yaml config file and runs `dut_vpp_run.sh` on the DUT and `loadgen_run.sh` on the loadgen node. 
