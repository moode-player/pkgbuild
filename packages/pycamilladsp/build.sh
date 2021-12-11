#!/bin/bash
#########################################################################
#
# Build recipe for pycamilladsp debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh


PKG="pycamilladsp_0.6.0-1moode1"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp.git"
PKG_SOURCE_GIT_TAG="v0.6.0"

rbl_build_py_from_git

#------------------------------------------------------------
# Custom part of the packing


#-----------------------------------------------------------
echo "done"

