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

uname -m | grep "64" > /dev/null
if [[ $? -eq 0 ]]
then
    ARCH64=1
else
    ARCH64=0
fi
PKGBUILD_ROOT=`realpath $( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/..`


BASE_DIR=`pwd`
BUILD_ROOT_DIR="$BASE_DIR/build"

DO_DEP_UPDATE=1

CS_DISTRO="trixie"
# make sure apt update is only done once during the build process
function apt_update {
    if [[ $DO_DEP_UPDATE -gt 0 ]]
    then
        if [[ ! -f "/etc/apt/sources.list.d/moodeaudio-m8y.list" ]]
        then
            curl -1sLf 'https://dl.cloudsmith.io/public/moodeaudio/m8y/setup.deb.sh' | sudo -E distro=raspbian codename=$CS_DISTRO bash
        fi
        sudo apt update
        DO_DEP_UPDATE=0
    fi
}

function rbl_check_build_dep {
    dpkg -s $1 2>&1 | grep Status | grep "installed" > /dev/null 2>&1
    if [[ ! $? -eq 0 ]]
    then
        echo "${YELLOW} Package $1 : missing, installing it.${NORMAL}"
        apt_update
        sudo apt install -y $1
        if [[ $? -gt 0 ]]
        then
            echo "${RED} Error: problems installing package $1.${NORMAL}"
            exit 1
        fi
    fi
}

function rbl_check_build_dep_with_version {
    dpkg-query --showformat='${Version}' --show $1 2>&1 | grep $2 > /dev/null 2>&1
    if [[ ! $? -eq 0 ]]
    then
        echo "${YELLOW} Package $1=$2 : missing, installing it.${NORMAL}"
        apt_update
        sudo apt install -y $1=$2
        if [[ $? -gt 0 ]]
        then
            echo "${RED} Error: problems installing package $1=$2.${NORMAL}"
            exit 1
        fi
    fi
}

# install pre build requirements
function check_deb_tools {
    array=( libtool-bin build-essential fakeroot devscripts swig dh-make pv python3-pip )
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

    # echo $PKGNAME
    # echo $PKGVERSION
    # echo $DEBVER
    # echo $DEBLOC

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

    if [ -z $DEBLOC ]
    then
        #echo "${YELLOW}Warning: no deblocpackage version is empty${NORMAL}"

        if [ -z $DEBSUFFIXVERSION ]
        then
            DEBSUFFIXVERSION="1"
        fi
        DEBLOC="${DEBSUFFIX}${DEBSUFFIXVERSION}"
    fi

    # echo $DEBLOC
    FULL_VERSION="$PKGVERSION-$DEBVER$DEBLOC"
    PKGDIR="$PKGNAME-$PKGVERSION"
    # echo $FULL_VERSION
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
    # DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc
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
    mv -f $BUILD_ROOT_DIR/*$PKGVERSION*.orig.* $BASE_DIR/dist/source > /dev/null 2>&1
    mv -f $BUILD_ROOT_DIR/*$PKGVERSION*$DEBLOC*.dsc $BASE_DIR/dist/source > /dev/null 2>&1
    mv -f $BUILD_ROOT_DIR/*$PKGVERSION*$DEBLOC.debian.* $BASE_DIR/dist/source > /dev/null 2>&1
    mv $BUILD_ROOT_DIR/*$PKGVERSION-$DEBVER$DEBLOC* $BASE_DIR/dist/binary > /dev/null 2>&1
    mv $BUILD_ROOT_DIR/$PKGNAME-$PKGVERSION/*$PKGVERSION-$DEBVER$DEBLOC* $BASE_DIR/dist/binary > /dev/null 2>&1
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

    RUSTC_MIN_VERSION="1.85"
    #RUST_CHAIN="nightly"
    # until 1.61 is available on stable switch to nightly
    RUST_CHAIN="stable"
    # Install cargo + rust tools
    CARGO_VER=`cargo --version > /dev/null 2>&1`


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

    RUSTC_VER=`rustc --version | sed -r "s/rustc[ ]([0-9]+[.][0-9]+[.][0-9]+).*/\1/"`

    dpkg --compare-versions $RUSTC_VER ge $RUSTC_MIN_VERSION
    if [ $? -gt 0 ]
    then
        echo "${YELLOW}rust version = $RUSTC_VER , needs update ${NORMAL}"
        # as long as 1.61 isn't stable switch to nightly build
        echo "${YELLOW}rustup: updating ... ${NORMAL}"
        rustup default $RUST_CHAIN
        #rustup default stable
        rustup update
    else
        echo "${GREEN}rust version = $RUSTC_VER${NORMAL}"
    fi
    rustup default $RUST_CHAIN

    CARGO_DEB_VER=`cargo-deb --version > /dev/null 2>&1`
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
    if [ -z "$PKG" ]
    then
        PKG=`basename $1 .dsc`
    fi
    echo "building $PKG"
    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
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

# Clone git repo and checkout to provided tag
# Arguments:
# 1 - git repo url to clone
# 2 - git tag to checkout
function rbl_prepare_clone_from_git {
    _PKG_SOURCE_GIT=$1
    _PKG_SOURCE_GIT_TAG=$2
    echo "prepare $PKG with git clone $_PKG_SOURCE_GIT:$_PKG_SOURCE_GIT_TAG as source"
    _rbl_decode_pkg_version
    _rbl_check_curr_is_package_dir
    _rbl_cleanup_previous_build
    _rbl_change_to_build_root

    git clone --branch $_PKG_SOURCE_GIT_TAG $_PKG_SOURCE_GIT $PKGDIR
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during git clone from ${_PKG_SOURCE_GIT} : ${_PKG_SOURCE_GIT_TAG} ${NORMAL}"
        exit 1
    fi

    _rbl_cd_source_dir
}

# Creae archive from git gag
# Arguments:
# 1 - git tag
# 2 - archive file name
function rbl_create_git_archive {
    _PKG_SOURCE_GIT_TAG=$1
    _PKG_ARCHIVE_FILE=$2
    if [ -z "$_PKG_SOURCE_GIT_TAG" ]
    then
        echo "${RED}Error: git tag is empty${NORMAL}"
        exit 1
    fi
    if [ -z "$_PKG_ARCHIVE_FILE" ]
    then
        echo "${RED}Error: git archive filename is empty${NORMAL}"
        exit 1
    fi

    if [[ -n "$_PKG_ARCHIVE_FILE" ]]
    then
        git archive  --format=tar.gz --output $_PKG_ARCHIVE_FILE $_PKG_SOURCE_GIT_TAG
    fi
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: error during git archive from $_PKG_SOURCE_GIT_TAG to $_PKG_ARCHIVE_FILE ${NORMAL}"
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

# Check if correct kernel source deb is installed.
# If not it will install it and if it can't install it it will abort
function rbl_get_kernel_source {
    local _KERNEL_VER_FULL=$(rbl_get_current_kernel_full_version)
    local KERNEL_PACKAGE=linux-image-$_KERNEL_VER_FULL
    local KERNEL_SOURCE=linux-source

    KERNEL_PKG_VERSION=`dpkg-query --showformat='${Version}' --show $KERNEL_PACKAGE`
    echo "kernel package        : ${KERNEL_PACKAGE}"
    echo "kernel package version: ${KERNEL_PKG_VERSION}"
    echo "kernel source package : ${KERNEL_SOURCE}"

    KERNEL_DOWNLOAD_LOCATION="$PKGBUILD_ROOT/tmp"

    KERNEL_SOURCE_VERSION=$(echo $KERNEL_PKG_VERSION | sed -r "s/[0-9]:([0-9][.][0-9]{1,2}{1,2}).*/\1/")
    KERNEL_SOURCE_DIR=$PKGBUILD_ROOT/tmp/linux-source-$KERNEL_SOURCE_VERSION
    echo "kernel source version : ${KERNEL_SOURCE_VERSION}"
    export KERNEL_SOURCE_DIR=$KERNEL_SOURCE_DIR # for using with other scripts
    export KERNEL_VERSION_PKG_SMALL=$(echo $KERNEL_PKG_VERSION | sed -r "s/[0-9]:([0-9][.][0-9]{1,2}[.][0-9]{1,3})[-].*/\1/")
    echo "kernel source dir : ${KERNEL_SOURCE_DIR}"
    # If needed dowload source package and patch it
    if [ -d "${KERNEL_SOURCE_DIR}" ]
    then
        echo "${GREEN} Kernel source is already present ${NORMAL}"
    else
        CURR_DIR=`pwd`
        echo "${YELLOW} Kernel source not present, downloading it ${NORMAL}"

        # Download the source package

        mkdir -p $KERNEL_DOWNLOAD_LOCATION
        cd $KERNEL_DOWNLOAD_LOCATION
        KERNEL_SOURCE_FILE=/usr/src/linux-source-$KERNEL_SOURCE_VERSION.tar.xz
        if [ -f $KERNEL_SOURCE_FILE ]
        then
            echo "${GREEN} Linux source archive  present '${KERNEL_SOURCE}' ${NORMAL}"
        else
            echo "${YELLOW} Linux source archive not present '${KERNEL_SOURCE}' ${NORMAL}"
            sudo apt-get install -y $KERNEL_SOURCE=$KERNEL_PKG_VERSION
            if [[ $? -gt 0 ]]
            then
                echo "${RED} Problems downloading kernel source package '${KERNEL_PACKAGE}' ${NORMAL}"
                cd $CURR_DIR
            fi

        fi
        echo "${YELLOW} Extract '${KERNEL_SOURCE_FILE}' to '${KERNEL_DOWNLOAD_LOCATION}' ${NORMAL}"
        pv $KERNEL_SOURCE_FILE | tar -xJ

        cd $CURR_DIR
    fi




    # KERNEL_SOURCE_ARCHIVE=/usr/src/linux-source-${_KERNEL_VER_SHORT}.tar.xz

    # export KERNEL_SOURCE_ARCHIVE=$KERNEL_SOURCE_ARCHIVE # for using with other scripts
    # if [ -f "$KERNEL_SOURCE_ARCHIVE" ]
    # then
    #     echo "${GREEN} Kernel source archive is present${NORMAL}"
    # else
    #     echo "${RED} Kernel source archive not present, abort${NORMAL}"
    #     exit 1
    # fi
}

# Check if correct kernel headers deb is installed.
# If not it will install it and if it can't install it it will abort
function rbl_check_kernel_headers {
    local _KERNEL_VER_FULL=$(rbl_get_current_kernel_full_version)
    KERNEL_PKG_VERSION=`dpkg-query --showformat='${Version}' --show linux-image-$_KERNEL_VER_FULL`
    export KERNEL_VERSION_PKG_SMALL=$(echo $KERNEL_PKG_VERSION | sed -r "s/[0-9]:([0-9][.][0-9]{1,2}[.][0-9]{1,3})[-].*/\1/")

    echo "Current kernel is linux-image-${_KERNEL_VER_FULL} = ${KERNEL_PKG_VERSION}"

    rbl_check_build_dep_with_version linux-headers-$_KERNEL_VER_FULL $KERNEL_PKG_VERSION

    ls -d /usr/src/linux-headers-$_KERNEL_VER_FULL* 2>&1 | grep "No such file or directory" > /dev/null
    if [ $? -eq 0 ]
    then
        echo "${RED}Warning: No kernel headers found at the expected location, abort${NORMAL}"
        exit 1
    else
        echo "${GREEN} Kernel headers are present!${NORMAL}"
        MODULE_BUILD_USE_HEADERS=1
        MODULE_BUILD_USE_SOURCE=0
    fi
}

function rbl_build {
    _rbl_check_build_deps
    _build_deb
    rbl_move_to_dist
}

# escape string (including) filepaths for sed substituion
function rbl_escaped_for_sed {
    local _escaped=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<< "$1" )
    echo "$_escaped"
}

# returns the current running kernel version as in "1.2.3"
function rbl_get_current_kernel_version {
    local _kernel_ver=$(uname -r | sed -r "s/([0-9.]*)[-].*/\1/")
    echo "$_kernel_ver"
}

function rbl_get_current_kernel_full_version {
    local _kernel_ver=$(uname -r )
    echo "$_kernel_ver"
}
# copies an patch while replacing the maintainer to the current env vars DEBFULLNAME and DEBEMAIL
function rbl_fix_control_patch_maintainer () {
    if [ -z "$1" ] || [ -z "$2" ]
    then
        echo "${RED}Error: missing source and or  destination ${NORMAL}"
        exit 1
    fi
    src=$1
    dest=$2
    cat $src | sed "s/Maintainer: .*/Maintainer: ${DEBFULLNAME} <${DEBEMAIL}>/" > $dest
}

# patch which abort in case of problems
function rbl_patch() {
    patch -p1 < $1
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: failure during rbl_patch!${NORMAL}"
        exit 1
    fi
}
# -------------------------------------------------------------------------
# dkms helper funcions
# -------------------------------------------------------------------------

# copy template $1 to destination $2, while replacing some vars in the template file
function rbl_dkms_apply_template {
    local from=$1
    local to=$2
    local mod_name=`basename $MODULE .ko`
    local dkms_ver=`basename $DKMS_MODULE`
    repl=$(rbl_escaped_for_sed "$MODULE_PATH")

    sed $from \
    -e "s/[%]KERNEL_VER[%]/$KERNEL_VER/" \
    -e "s/[%]ARCHS[%]/${ARCHS[*]}/" \
    -e "s/[%]PKG_NAME[%]/$PKGNAME/" \
    -e "s/[%]MODULE_PATH[%]/$repl/" \
    -e "s/[%]MODULE[%]/$MODULE/" \
    -e "s/[%]MODULE_NAME[%]/$mod_name/" \
    -e "s/[%]MODULE_VER[%]/$dkms_ver/" \
    > $to
    if [[ $? -gt 0 ]]
    then
        echo "${RED}Error: failure during rbl_dkms_apply_template!${NORMAL}"
        exit 1
    fi
}

# copy the specified moudle from dkms build to fakeroot for fpm
function rbl_dkms_grab_modules {
        for i in "${ARCHS[@]}"
    do
        echo "Grab $i"
        mkdir -p $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/
        echo "install -m644 $BUILD_ROOT_DIR/$DKMS_MODULE/$KERNEL_VER-$i/aarch64/module/$MODULE* $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/"
        install -m644 $BUILD_ROOT_DIR/$DKMS_MODULE/$KERNEL_VER-$i/aarch64/module/$MODULE* $BUILD_ROOT_DIR/lib/modules/$KERNEL_VER-$i/updates/dkms/
        if [[ $? -gt 0 ]]
        then
            echo "${RED}Error: failure during rbl_dkms_grab_modules!${NORMAL}"
            exit 1
        fi
    done
}

# prepare an in tree or out tree module build with dkms
function rbl_dkms_prepare {
    local mode="$1"
    if [ -z "$mode" ] || ( [ "$mode" != "intree" ] && [ "$mode" != "outtree" ] )
    then
        echo "Error: rbl_dkms_prepare is missing mode argument: should be set to \"intree\" or \"outtree\"!${NORMAL}"
        exit 1
    fi

    #TODO: improve it by using the ARCHS (contains list of architecture to build) instead the 64bit test flag
    # if [ $ARCH64 -eq 1 ]
    # then
    DKMS_KERNEL_STRING="-k $KERNEL_VER-rpi-v8 -k $KERNEL_VER-rpi-2712"
    # else
    #     DKMS_KERNEL_STRING="-k $KERNEL_VER-v7l+ -k $KERNEL_VER-v7+"
    # fi

    # $FULL_VERSION is already set this is sign that another build step prep the build tree (like rbl_prepare_clone_from_git)
    # In that case we skip the prep steps
    if [ -z "$FULL_VERSION" ]
    then
        rbl_check_fpm
        _rbl_decode_pkg_version
        _rbl_check_curr_is_package_dir
        _rbl_cleanup_previous_build
    fi

    _rbl_change_to_build_root
    rbl_check_build_dep dkms

    rbl_check_kernel_headers
    # for intree modules builds the kernel source (not only the headers is required), but if no headers are present the source is also required
    if [ "$mode" = "intree" ]
    then
        # this will download the kernel source if needed and set the ENV KERNEL_SOURCE_ARCHIVE to the location of the tarball
        # if already present the cached source will be used
        rbl_get_kernel_source

        echo "dkms build prepared at: $BUILD_ROOT_DIR/source/$SRC_DIR"
        mkdir -p $BUILD_ROOT_DIR/source/$SRC_DIR

        # create dkms source project files:
        cp $PKGBUILD_ROOT/scripts/templates/deb_dkms/prepkernel.sh $BUILD_ROOT_DIR/source/$SRC_DIR/
        cp $PKGBUILD_ROOT/scripts/templates/deb_dkms/dkms-patchmodule.intree.sh $BUILD_ROOT_DIR/source/$SRC_DIR/dkms-patchmodule.sh
        chmod +x $BUILD_ROOT_DIR/source/$SRC_DIR/*.sh
        rbl_dkms_apply_template $PKGBUILD_ROOT/scripts/templates/deb_dkms/dkms.conf $BUILD_ROOT_DIR/source/$SRC_DIR/dkms.conf

        # if patched or tar files are needed for the dkms project
        cp $BASE_DIR/*.patch $BUILD_ROOT_DIR/source/$SRC_DIR/ > /dev/null 2>&1
        cp $BASE_DIR/*.tar $BUILD_ROOT_DIR/source/$SRC_DIR/ > /dev/null 2>&1
    fi
}
