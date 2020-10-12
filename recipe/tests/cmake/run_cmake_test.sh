#!/usr/bin/env bash

set +e

CMAKE_DBG="trace --debug-find --debug-output --debug-trycompile"
CMAKE_DBG=--debug-find
cmake -G"GNU Makefiles" -DPY_VER=${1} ${CMAKE_DBG} .
make
