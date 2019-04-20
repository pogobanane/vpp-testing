# Git Submodules

Checkout Moongen. It's build.sh will take care of downloading submodules.

Check out vpp release v18.10 or VPPv18.10-benchplug (default) for l2fib
testing support.

# Scripts

`scripts/setup.sh` depends on `pos`, assumes nodes are allocated, resets them
and compiles required software on them. 

`scripts/start.sh` depends on `pos`, assumes setup.sh succeeded, sets the
.yaml config file and runs `dut_vpp_run.sh` on the DUT and `loadgen_run.sh` on
the loadgen node. 

`scripts/vpp_test/*.sh` are `pos` independent. They create exec and config
files for vpp and run it. 

`moongen-scripts/*.lua` are used with MoonGen to test vpp. 