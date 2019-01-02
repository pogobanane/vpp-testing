#!/bin/bash

# expects to be run from the ba-okelmann project root

source scripts/vpp_tests/function.sh

exec="set int state $INT_SRC up
set int state $INT_DST up

set int l2 xconnect $INT_SRC $INT_DST
set int l2 xconnect $INT_DST $INT_SRC
"

test_vpp_with "$config_1worker" "$exec"