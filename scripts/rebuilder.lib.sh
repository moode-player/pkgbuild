#!/bin/bash
#########################################################################
#
# Collection of helper functions for building debian packages
# for the moOde audio player.
#
# This isn't a standalone script but should be included in other scripts
#
# It expects that at least the following ENV settings are present:
# - DEBFULLNAME
# - DEBEMAIL
# Example
# export DEBFULLNAME=FooBar
# export DEBEMAIL=foobar@users.noreply.github.com
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

# Used as local version after the deb release number:
if [ -z "$DEBSUFFIX" ]
then
    DEBSUFFIX=moode
fi

# Used for coloured output
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
LIME_YELLOW=$(tput setaf 190)
YELLOW=$(tput setaf 3)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)


#  With Regexp below a package name with version can be decoded in several parts:

#  Supported version formats:
#  VER=caps_0.9.26-1~moode1
#  VER=caps_2:0.9.26-1~moode1
#  VER=caps_2:0.9.26-1moode1
#  VER=caps_0.9.26-1

#  Unsupported version formats:
#  VER=caps_0.9.26~moode1
#  VER=caps_0.9.26

REGEXP='^([A-Za-z].*)[_]([0-9]:?.*)-([0-9]{1,3}[.]?[0-9]?)(.*)?$'


# check some use conditions:
if [ "$0" = "$BASH_SOURCE" ]; then
    echo "Error: This script is not intended to be executed, but sourced instead!${NORMAL}"
    exit 1
fi

if [ -z "$DEBFULLNAME" ]
then
    echo "${RED}Error: missing env DEBFULLNAME for user name in changelog deb ${NORMAL}"
    exit 1
fi

if [ -z "$DEBEMAIL" ]
then
    echo "${RED}Error: missing env DEBEMAIL with email user for changelog in deb ${NORMAL}"
    exit 1
fi

BASE_DIR=`pwd`
BUILD_ROOT_DIR="$BASE_DIR/build"

DO_DEP_UPDATE=1

# make sure apt update is only done once during the build process
function apt_update {
    if [[ $DO_DEP_UPDATE -gt 0 ]]
    then
        sudo apt update
        DO_DEP_UPDATE=0
    fi
}

function rbl_check_build_dep {
    dpkg -l $1 > /dev/null 2>&1
    if [[ $? -gt 0 ]]
    then
        echo "${YELLOW} Package $1 : missing, installing it.${NORMAL}"
        apt_update
        sudo apt install -y $1
        if [[ $? -gt 0 ]]
        then
            echo "${RED} Error: problems installing package $1.${NORMAL}"
        fi
    fi
}

# install pre build requirements
function check_deb_tools {
    array=( libtool-bin build-essential fakeroot devscripts swig )
    for i in "${array[@]}"
    do
        rbl_check_build_dep $i
    done
}

function _rbl_decode_pkg_version {
    # _rbl_decode_pkg_version is always required, makes it a nice place to check if the debtools are present
    check_deb_tools

    PKGNAME=`echo $PKG | sed -r "s|$REGEXP|\1|"`
    PKGVERSION=`echo $PKG | sed -r "s|$REGEXP|\2|"`
    DEBVER=`echo $PKG| sed -r "s|$REGEXP|\3|"`
    DEBLOC=`echo $PKG | sed -r "s|$REGEXP|\4|"`

    FULL_VERSION="$PKGVERSION-$DEBVER$DEBLOC"
    PKGDIR="$PKGNAME-$PKGVERSION"
    echo $PKGNAME
    echo $PKGVERSION
    echo $DEBVER
    echo $DEBLOC

    # When the REGEXPR can not decode the pacakge string it passes on the full string
    # Detect this to indicate that the string can not be decoded
    if [ "$PKGNAME" == "$PKG" ]
    then
        echo "${RED}Error: could not decode part of the package $PKG${NORMAL}"
        exit 1
    fi

    # Double check if the following parts are empty or not
    # If so the rm and mv in the script becomes pretty dangerous
    if [[ -z $PKGNAME || -z $PKGVERSION ]];
    then
        echo "${RED}Error: package version is empty${NORMAL}"
        exit 1
    fi

    if [ -z $DEBLOC ];
    then
        #echo "${YELLOW}Warning: no deblocpackage version is empty${NORMAL}"
        DEBLOC="${DEBSUFFIX}1"
    fi

}

 function _rbl_check_curr_is_package_dir {
    CURRENTDIR=`basename "$PWD"`
    if [ "$CURRENTDIR" != "$PKGNAME" ];
    then
        echo "${RED}Error: script should be executed from a valid package dir ($PKGNAME)${NORMAL}"
        exit 1
    fi
}

function _rbl_cleanup_previous_build {
    # if [ -d "$PKGNAME-$PKGVERSION" ]
    # then
    #     rm -rf $PKGNAME-$PKGVERSION
    # fi
    if [ -d "$BUILD_ROOT_DIR" ]
    then
        rm -rf $BUILD_ROOT_DIR
    fi

    rm -f $PKG-rebuild.log
}

function _download_source_package {
    apt-src install $PKGNAME=$FULL_VERSION
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: downloading source${NORMAL}"
        exit 1
    fi
}

function _rbl_change_to_build_root {
    mkdir -p $BUILD_ROOT_DIR
    cd $BUILD_ROOT_DIR
}

function _rbl_cd_source_dir {
    cd $PKGDIR
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: project build directory $PKGDIR not found${NORMAL}"
        exit 1
    fi
}

function _rbl_check_build_deps {
    # if build deps aren't present, install it and clean up leftovers
    dpkg-checkbuilddeps
    if [[ $? -gt 0 ]]
    then
        #mk-build-deps --install --root sudo --remove
        # old version -y isn't support; will required manual confirmation
        mk-build-deps --install --root sudo --remove
        if [[ $? -gt 0 ]]
        then
            echo "${RED}Error: automatic install of dependencies not succesfull${NORMAL}"
            exit 1

        fi

        rm -f *build-deps_$PKGVERSION-*$DEBLOC_armhf.*
    fi
}

function _build_deb {
    # build package
    dpkg-buildpackage -us -uc
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during dpkg-buildpackage${NORMAL}"
        cd ..
        exit 1
    fi
    cd ..
}

function rbl_move_to_dist {
    # copy output to dist dir
    mkdir -p $BASE_DIR/dist/source
    mkdir -p $BASE_DIR/dist/binary
    mv -f $BUILD_ROOT_DIR/*$PKGVERSION*.orig.* $BASE_DIR/dist/source
    mv -f $BUILD_ROOT_DIR/*$PKGVERSION*$DEBLOC*.dsc $BASE_DIR/dist/source
    mv -f $BUILD_ROOT_DIR/*$PKGVERSION*$DEBLOC.debian.* $BASE_DIR/dist/source
    mv $BUILD_ROOT_DIR/*$PKGVERSION-$DEBVER$DEBLOC* $BASE_DIR/dist/binary
}

function _rebuild {
    echo "rebuilding $PKG"

    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
    _rbl_change_to_build_root
    _download_source_package
    _rbl_cd_source_dir
    _rbl_check_build_deps
    _build_deb
    rbl_move_to_dist
}

function rbl_check_cargo {
    export RUSTUP_UNPACK_RAM=94371840; export RUSTUP_IO_THREADS=1
    export PATH=$PATH:/home/pi/.cargo/bin

    # Install cargo + rust tools
    CARGO_VER=`cargo --version`
    if [[ $? -gt 0 ]]
    then
        echo "${YELLOW}cargo: not installed, installing it${NORMAL}"
        export RUSTUP_UNPACK_RAM=94371840; export RUSTUP_IO_THREADS=1
        echo "Choose option 1 when asked !"
        read "(press key to continue)"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source $HOME/.cargo/env
    else
        echo "${GREEN}cargo: already installed${NORMAL}"
    fi

    CARGO_DEB_VER=`cargo-deb --version`
    if [[ $? -gt 0 ]]
    then
        echo "${YELLOW}cargo-deb: not installed, installing it.${NORMAL}"
        cargo install cargo-deb
    else
        echo "${GREEN}cargo-deb: already installed${NORMAL}"
    fi
}

function rbl_check_fpm {
    # fpm is a Ruby application
    rbl_check_build_dep ruby-full
    FPM_VER=`fpm --version`
    if [[ $? -gt 0 ]]
    then
        sudo gem install --no-document fpm
        if [[ $? -gt 0 ]]
        then
            echo "${RED}Error: failure during installation of fpm.${NORMAL}"
            exit 1
        fi
    fi
}

function rbl_set_initial_version_changelog {
    sed -i "s/$1 (.*)/$1 ($2)/" debian/changelog
    sed -i "s/* Initial release (Closes: #nnnn)  <nnnn is the bug number of your ITP>/* Initial release/" debian/changelog
}

#--------------------------------------------------------------------------------------

function rbl_rebuild_from_source_package {
    _rebuild | tee rebuild.log
    mv rebuild.log $PKG-rebuild.log
    echo "Log of rebuild can be found at $PKG-rebuild.log"
}

function rbl_prepare_from_dsc_url {
    PKG=`basename $1 .dsc`
    echo "building $PKG"
    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
    _rbl_change_to_build_root
    _rbl_change_to_build_root
    dget $1
    _rbl_cd_source_dir
}

function rbl_prepare_from_git_with_deb_repo {
    echo "building $PKG with $PKG_SOURCE_GIT:$PKG_SOURCE_GIT_TAG as source"
    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
    _rbl_change_to_build_root

    git clone $PKG_SOURCE_GIT $PKGDIR

    _rbl_cd_source_dir
    git checkout -b $PKG_SOURCE_GIT_TAG $PKG_SOURCE_GIT_TAG
    git archive  --format=tar.gz --output ../${PKGNAME}_${PKGVERSION}.orig.tar.gz $PKG_SOURCE_GIT_TAG
}

function rbl_prepare_clone_from_git {
    _PKG_SOURCE_GIT=$1
    _PKG_SOURCE_GIT_TAG=$2
    echo "prepare $PKG with git clone $_PKG_SOURCE_GIT:$_PKG_SOURCE_GIT_TAG as source"
    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
    _rbl_change_to_build_root

    git clone $_PKG_SOURCE_GIT $PKGDIR
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during git clone from $_PKG_SOURCE_GIT ${NORMAL}"
        exit 1
    fi

    _rbl_cd_source_dir
    if [[ -n "$_PKG_SOURCE_GIT_TAG" ]]
    then
        git checkout -b $_PKG_SOURCE_GIT_TAG $_PKG_SOURCE_GIT_TAG
    fi
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during git checkout from $_PKG_SOURCE_GIT_TAG ${NORMAL}"
        exit 1
    fi
}

function rbl_build_py_from_git {
    echo "prepare $PKG with git clone $PKG_SOURCE_GIT:$PKG_SOURCE_GIT_TAG as source"

    python -c "import stdeb"
    if [[ $? -gt 0 ]]
    then
        echo "${YELLOW}python stdeb: not installed, installing it${NORMAL}"
        #sudo pip3 install stdeb
        apt_update
        sudo apt install -y python3-stdeb
    fi

    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
    _rbl_change_to_build_root

    git clone $PKG_SOURCE_GIT $PKGDIR
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during git clone from $PKG_SOURCE_GIT ${NORMAL}"
        exit 1
    fi

    _rbl_cd_source_dir
    git checkout -b $PKG_SOURCE_GIT_TAG $PKG_SOURCE_GIT_TAG
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during git checkout from $PKG_SOURCE_GIT_TAG ${NORMAL}"
        exit 1
    fi


    python setup.py --command-packages=stdeb.command sdist_dsc --debian-version $DEBVER$DEBLOC --with-python3=True --compat 10 bdist_deb
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: during python stdeb${NORMAL}"
        exit 1
    fi

    mv deb_dist/*$DEBVER$DEBLOC* ..
    mv deb_dist/*$PKGVERSION.orig* ..
    # cd ..
    rbl_move_to_dist
}

function rbl_grab_debian_archive {
    DEB_ARCHIVE_NAME=`basename $1`
    wget -O ../$DEB_ARCHIVE_NAME $1
    tar -x -f ../$DEB_ARCHIVE_NAME
    rm ../$DEB_ARCHIVE_NAME
}

function rbl_build {
    _rbl_check_build_deps
    _build_deb
    rbl_move_to_dist
}