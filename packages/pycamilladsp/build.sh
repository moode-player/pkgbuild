#!/bin/bash

. ../../scripts/rebuilder.lib.sh


PKG="pycamilladsp_0.6.0-1~moode1"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp.git"
PKG_SOURCE_GIT_TAG="v0.6.0"

rbl_build_py_from_git

#------------------------------------------------------------
# Custom part of the packing


#-----------------------------------------------------------
echo "done"

