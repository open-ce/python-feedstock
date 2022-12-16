#!/usr/bin/env bash

set -ex
PYVER=$(${CONDA_PREFIX}/bin/python -c 'import sys; sys.stdout.write("{}.{}".format(sys.version_info[0], sys.version_info[1]))')

if [[ $ppc_arch == "p10" ]]
then
    if [[ -z "${GCC_11_HOME}" ]];
    then
        echo "Please set GCC_11_HOME to the install path of gcc-toolset-11"
        exit 1
    else
        CC=${GCC_11_HOME}/bin/gcc
        CXX=${GCC_11_HOME}/bin/g++
        GCC=$CC
        AR=${GCC_11_HOME}/bin/ar
        LD=${GCC_11_HOME}/bin/ld
        NM=${GCC_11_HOME}/bin/nm
        OBJCOPY=${GCC_11_HOME}/bin/objcopy
        OBJDUMP=${GCC_11_HOME}/bin/objdump
        RANLIB=${GCC_11_HOME}/bin/ranlib
        STRIP=${GCC_11_HOME}/bin/strip
	READELF=${GCC_11_HOME}/bin/readelf
#        export PATH=$GCC_11_HOME/bin:$PATH
    fi
fi

if [[ $(uname) == Darwin ]]; then
  # The macOS linker does not work like this. If you want a single archive to get linked in then you need to
  # identify it to the linker with the full path.
  # NATURE_STATIC=-Wl,-static
  # NATURE_SHARED=-Wl,-dynamic
  NATURE_STATIC=
  NATURE_SHARED=
  REPLACEMENT_STATIC=${CONDA_PREFIX}/lib/libpython${PYVER}.a
  RPATH=-Wl,-rpath,${CONDA_PREFIX}/lib
  DEFAULT_EXPECTED_NATURE=shared
else
  NATURE_STATIC=-Wl,-Bstatic
  NATURE_SHARED=-Wl,-Bdynamic
  REPLACEMENT_STATIC=-lpython${PYVER}
  RPATH=-Wl,-rpath,${CONDA_PREFIX}/lib
  DEFAULT_EXPECTED_NATURE=static
fi

ERRORS=no

declare -a NATURES=(shared)
if [[ ${PKG_NAME} == libpython-static ]]; then
  NATURES+=(static)
  NATURES+=(default)
fi

for NATURE in "${NATURES[@]}"; do

  LDFLAGS_ORIG=$(python3-config --ldflags --embed)
  re='^(.*)(-lpython[^ ]*)(.*)$'
  FIRST_LIBPATH=
  if [[ ${LDFLAGS_ORIG} =~ $re ]]; then
    if [[ ${NATURE} == static ]]; then
      LDFLAGS_NATURE="${BASH_REMATCH[1]} ${NATURE_STATIC} ${REPLACEMENT_STATIC} ${NATURE_SHARED} ${BASH_REMATCH[3]}"
      RPATH_NATURE=
    elif [[ ${NATURE} == shared ]]; then
      # Yes, force shared then back to the default, which is also shared.
      LDFLAGS_NATURE="${BASH_REMATCH[1]} ${NATURE_SHARED} ${BASH_REMATCH[2]} ${NATURE_SHARED} ${BASH_REMATCH[3]}"
      RPATH_NATURE=${RPATH}
      # We ensure -L${PREFIX}/lib comes before -L$PREFIX/lib/python3.8/config-3.8-x86_64-linux-gnu as that contains only a
      # static lib and since that dir would (otherwise) be searched first, on Linux, this shadows our dynamic library and
      # dynamic linking will not happen
      FIRST_LIBPATH=-L${PREFIX}/lib
    else
      LDFLAGS_NATURE=${LDFLAGS_ORIG}
      if [[ ${DEFAULT_EXPECTED_NATURE} == shared ]]; then
        RPATH_NATURE=${RPATH}
      else
        RPATH_NATURE=
      fi
    fi
  fi
  echo "INFO :: Testing embedded ${NATURE} python interpreter"
  echo "${CC} ${FIRST_LIBPATH} $(dirname ${BASH_SOURCE[0]})/a.c $(python3-config --cflags) ${LDFLAGS_NATURE} -o ${CONDA_PREFIX}/bin/embedded-python-${NATURE} ${RPATH_NATURE}"
  ${CC} ${FIRST_LIBPATH} $(dirname ${BASH_SOURCE[0]})/a.c $(python3-config --cflags) ${LDFLAGS_NATURE} -o ${CONDA_PREFIX}/bin/embedded-python-${NATURE} ${RPATH_NATURE}
  if ! [[ -f ${CONDA_PREFIX}/bin/embedded-python-${NATURE} ]]; then
    echo "ERROR :: Failed to build ${CONDA_PREFIX}/bin/embedded-python-${NATURE}"
    ERRORS=yes
    continue
  fi
  if ! ${CONDA_PREFIX}/bin/embedded-python-${NATURE}; then
    echo "ERROR :: Failed to run ${CONDA_PREFIX}/bin/embedded-python-${NATURE} failed"
    ERRORS=yes
  fi
  if [[ -n ${READELF} ]]; then
    ${READELF} -d ${CONDA_PREFIX}/bin/embedded-python-${NATURE} | rg libpython
    if [[ $? == 0 ]]; then
      TRUE_NATURE=shared
    else
      TRUE_NATURE=static
    fi
  elif [[ -n ${ORTOOL} ]]; then
    ${ORTOOL} -l ${CONDA_PREFIX}/bin/embedded-python-${NATURE} | rg libpython
    if [[ $? == 0 ]]; then
      TRUE_NATURE=shared
    else
      TRUE_NATURE=static
    fi
  fi
  EXPECTED_NATURE=${NATURE}
  if [[ ${EXPECTED_NATURE} == default ]]; then
    EXPECTED_NATURE=${DEFAULT_EXPECTED_NATURE}
  fi
  if [[ ${EXPECTED_NATURE} != ${TRUE_NATURE} ]]; then
    echo "ERROR :: Embedded python with ${EXPECTED_NATURE} (${NATURE}) nature is linked to ${TRUE_NATURE} python library"
    ERRORS=yes
  fi
done

if [[ ${ERRORS} == yes ]]; then
  echo "ERROR :: Please see 'python linked to' messages above."
  exit 1
else
  echo "INFO :: Python embedding tests passed OK"
  exit 0
fi
