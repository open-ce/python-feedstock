cmake_minimum_required(VERSION 3.14)

option(PY_VER, "Python version to use")
# find_package(PythonInterp)
# find_library(PythonLibs)
FIND_PACKAGE(PythonLibs ${PY_VER} EXACT REQUIRED)
