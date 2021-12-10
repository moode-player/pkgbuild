#!/bin/bash

. ../../scripts/rebuilder.lib.sh

PKG="pycamilladsp-plot_0.6.2-1moode1"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp-plot.git"
PKG_SOURCE_GIT_TAG="v0.6.2"

rbl_build_py_from_git

#------------------------------------------------------------
# Custom part of the packing


#-----------------------------------------------------------
echo "done"

