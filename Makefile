#!/bin/bash

init-modules:
	git submodule update --init --remote vpp
	git submodule update --init MoonGen