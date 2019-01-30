#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $1: INT_SRC; $2: INT_DST
source scripts/vpp_tests/functions.sh

exec="set int state $INT_SRC up
set int state $INT_DST up

set int ip address $INT_SRC $INT_SRC_IP
set int ip address $INT_DST $INT_DST_IP

set ip arp $INT_DST $DST_IP dead.beef.bab0
"

test_vpp_with "$config_1worker" "$exec"