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

arch=$(echo "${kernelver}" |sed -r 's/.*-(.*)/\1/' )
HEADERS_DIR="/usr/src/linux-headers-${kernelver}"

vers=(${kernelver//./ })   # split kernel version into individual elements
major="${vers[0]}"
minor="${vers[1]}"
version="$major.$minor"    # recombine as needed
# subver=$(grep "SUBLEVEL =" /usr/src/linux-headers-${kernelver}/Makefile | tr -d " " | cut -d "=" -f 2)
subver=$(grep "SUBLEVEL =" $HEADERS_DIR/Makefile | tr -d " " | cut -d "=" -f 2)

KERNEL_ARCHIVE=$KERNEL_SOURCE_ARCHIVE
KERNEL_BASE_NAME=`basename $KERNEL_ARCHIVE .tar.xz`

echo "Extracting original source"
mkdir -p $1
cp -r $KERNEL_SOURCE_DIR/$1/* .

# The new module version should be increased to allow the new module to be
# installed during kernel upgrade
echo "Increase module version"
#sed -i 's/\(#define VERSION "0\.8\)/\1\.1/' btusb.c

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
