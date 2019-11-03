#!/bin/bash
# expects to be run in the ranger dir

set -e

cd cpp_version
mkdir build
cd build
cmake ..
make