#!/bin/bash
#########################################################################
#
# Build recipe for pycamilladsp debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org distutils version
# (C) bitkeeper 2023 http://moodeaudio.org pyproject.toml version
# License: GPLv3
#
#########################################################################

# With version 2+ camilladsp use the pyproject.toml with hatchling build.
# This isn't by bdist_deb
# Also hatchling isn't available on bullseye as standard deb
# Which results in different build between those
. ../../scripts/rebuilder.lib.sh

# don't forget to change the debian/changelog on version bump!
PKG="pycamilladsp_2.0.0-1moode1"

PKG_SOURCE_GIT="https://github.com/HEnquist/pycamilladsp.git"
PKG_SOURCE_GIT_TAG="v2.0.0"
# If can be dropped when bullseye support is dropped
if [[ `lsb_release -c -s| grep bullseye` ]]
then
    # can't use rbl_build_py_from_git because we need to copy a file between prepare and build
    #rbl_build_py_from_git
    rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

    #rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

    #------------------------------------------------------------
    # Custom part of the packing
    #cp -raf ${BASE_DIR}/debian ./debian
    cp -f ${BASE_DIR}/setup.py .

    python setup.py --command-packages=stdeb.command sdist_dsc --debian-version $DEBVER$DEBLOC --with-python3=True --compat 10 bdist_deb
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: during python stdeb${NORMAL}"
        exit 1
    fi

    mv deb_dist/*$DEBVER$DEBLOC* ..
    mv deb_dist/*$PKGVERSION.orig* ..

    #-----------------------------------------------------------
    #rbl_build
    rbl_move_to_dist
else
    rbl_check_build_dep dh-python

    rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
    rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

    #------------------------------------------------------------
    # Custom part of the packing
    cp -raf ${BASE_DIR}/debian ./debian

    #-----------------------------------------------------------
    rbl_build
    echo "done"
fi