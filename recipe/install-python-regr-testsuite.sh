#!/usr/bin/env bash

VER=${PKG_VERSION%.*}

pushd ${PREFIX}/lib/python${VER}
  mv ${SRC_DIR}/test.copied.by.install-python.sh/* test/
popd
