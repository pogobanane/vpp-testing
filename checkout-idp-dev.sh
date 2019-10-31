#!/bin/bash

set -e

git checkout idp

git submodule update --init

cd MoonGen
git submodule update --init
cd libmoon
git submodule update --init --recursive
cd ../..

cd vpp
git checkout ai
cd ..

cd ranger
git checkout master

echo "You are now on branch vpp-testing/idp with all submodules checked out on their development branch."
