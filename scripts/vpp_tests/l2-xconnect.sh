#!/bin/bash

# expects to be run from the ba-okelmann project root

# expects $1: INT_SRC; $2: INT_DST
# expects $3: INT_SRC_PCI; $4: INT_DST_PCI
source scripts/vpp_tests/functions.sh

exec="set int state $INT_SRC up
set int state $INT_DST up

set int l2 xconnect $INT_SRC $INT_DST
set int l2 xconnect $INT_DST $INT_SRC
"

test_vpp_with "$config_1worker" "$exec"