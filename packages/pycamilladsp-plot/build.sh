#!/bin/bash
#########################################################################
#
# Build recipe for pycamilladsp-plot debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="pycamilladsp-plot_1.0.2-1moode1"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp-plot.git"
PKG_SOURCE_GIT_TAG="v1.0.2"

rbl_check_build_dep dh-python
rbl_build_py_from_git

#------------------------------------------------------------
# Custom part of the packing


#-----------------------------------------------------------
echo "done"

