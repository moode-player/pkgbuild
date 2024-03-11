#!/bin/bash
#########################################################################
#
# Scripts for building moode packages
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

# kernelver is not set on kernel upgrade from apt, but DPKG_MAINTSCRIPT_PACKAGE
# contains the kernel image or header package upgraded

if [ -z "$kernelver" ] ; then
  echo "using DPKG_MAINTSCRIPT_PACKAGE instead of unset kernelver"
  kernelver=$( echo $DPKG_MAINTSCRIPT_PACKAGE | sed -r 's/linux-(headers|image)-//')
fi

# When no kernel headers are present, prep an kernel source
HEADERS_DIR="/usr/src/linux-headers-${kernelver}"
arch=$(echo "${kernelver}" |sed -r 's/.*-(.*)/\1/' )

# auto unpack tars in source dir
if [ $(find -name "*.tar" | wc -l) -gt 0 ]
then
  for i in `ls *.tar`
  do
    echo "Unpack $i"
    tar -xvf $i
  done
fi

# auto apply patches in source dir
if [ $(find -name "*.patch" | wc -l) -gt 0 ]
then
  patches=`ls *.patch`
  module_path="/$1/"
  parts=${module_path//[!\/]}
  depth=${#parts}
  echo $depth

  for i in `ls *.patch`
  do
    echo "Applying $i"
    patch -p$depth < $i
  done
fi
