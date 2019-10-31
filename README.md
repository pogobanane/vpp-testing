# Git Submodules

Clone and check out all dev branches of all submodules using `./checkout-idp-dev.sh`.


# Scripts

`scripts/setup.sh` depends on `pos`, assumes nodes are allocated, resets them
and compiles required software on them. 

`scripts/start.sh` depends on `pos`, assumes setup.sh succeeded, sets the
.yaml config file and runs `dut_vpp_run.sh` on the DUT and `loadgen_run.sh` on
the loadgen node. 

`scripts/vpp_test/*.sh` are `pos` independent. They create exec and config
files for vpp and run it. A good starting point for tests on VMs is `host-interface.sh` (does not use dpdk though).  
Example klaipeda: `./scripts/vpp_tests/l2-bridging.sh TenGigabitEthernet2/0/0 TenGigabitEthernet2/0/1 0000:02:00.0 0000:02:00.1 1`

`moongen-scripts/*.lua` are used with MoonGen to test vpp.  
Example narva: `./MoonGen/build/MoonGen moongen-scripts/l2-throughput.lua 0 2`
