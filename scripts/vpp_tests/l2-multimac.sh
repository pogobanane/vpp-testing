#!/bin/bash

# expects to be run from the ba-okelmann project root
# expects $3: mac count

# expects $1: INT_SRC; $2: INT_DST
source scripts/vpp_tests/functions.sh

bdid=1 # bridge-domain-id
bdcreators=( "create bridge-domain $bdid learn 0"
	"create bridge-domain $bdid learn 1"
	"create bridge-domain $bdid learn 0 mac-age 60"
	"create bridge-domain $bdid learn 1 mac-age 60"
	"create bridge-domain $bdid learn 0 uu-flood 0"
	"create bridge-domain $bdid learn 0 uu-flood 0 flood 0" )


exec="set int state $INT_SRC up
set int state $INT_DST up

${bdcreators[0]}

set int l2 bridge $INT_SRC $bdid
set int l2 bridge $INT_DST $bdid

l2fib add $MAC_SRC $bdid $INT_SRC
benchplugaddbd1 add count $3 mac $MAC_DST int $INT_DST
"

test_vpp_with "$config_1worker" "$exec"