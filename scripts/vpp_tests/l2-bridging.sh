#!/bin/bash

# expects to be run from the ba-okelmann project root
# expects $1: bdcreators[$1]

source scripts/vpp_tests/functions.sh

bdid=1 # bridge-domain-id
bdcrators=( "create bridge-domain $bdid learn 0"
	"create bridge-domain $bdid learn 1"
	"create bridge-domain $bdid learn 0 mac-age 60"
	"create bridge-domain $bdid learn 1 mac-age 60"
	"create bridge-domain $bdid learn 0 uu-flood 0"
	"create bridge-domain $bdid learn 0 uu-flood 0 flood 0" )


exec="set int state $INT_SRC up
set int state $INT_DST up

${bdcreators[$1]}

set int l2 bridge $INT_SRC $bdid
set int l2 bridge $INT_DST $bdid

l2fib add $MAC_SRC $bdid $INT_SRC
l2fib add $MAC_DST $bdid $INT_DST
"

test_vpp_with "$config_1worker" "$exec"