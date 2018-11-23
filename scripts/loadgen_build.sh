#!/bin/bash
# expects to be run from MoonGen root

# exit on error
set -e
# log every command
set -x

LOADGEN=MoonGen

# build moongen
./build.sh
./setup-hugetlbfs.sh

echo 'all done'
