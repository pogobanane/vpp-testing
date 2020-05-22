#!/bin/bash
# expects to be run from ba-okelmann root with or without bootstrapped pos
# $1 path to dataset csv
# $2 path and prefix of output files

set -e

echo "Output prefix: trees"

./ranger/cpp_version/build/ranger ranger --treetype=3 --file=$1 --write --outprefix=$2 --depvarname="result"

if [ $(which pos_upload) ]; then
	pos_upload $2.forest
fi
