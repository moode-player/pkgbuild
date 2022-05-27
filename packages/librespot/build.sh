#!/bin/bash
#########################################################################
#
# Build recipe for librespot debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="librespot_0.4.1-1moode1"

PKG_SOURCE_GIT="https://github.com/librespot-org/librespot.git"
PKG_SOURCE_GIT_TAG="v0.4.1"

rbl_check_cargo
rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

rbl_check_build_dep libasound2-dev

#Add to [package.metadata.deb] section of Cargo.toml:
echo "revision=\"$DEBVER$DEBLOC\"" >> Cargo.toml

# Build it for V6 and higher arch (else it doesn't runs on the P2 and less)
if [ $ARCH64 -eq 1 ]
then
    # rustup default stable-aarch64-unknown-linux-gnu
    RUSTFLAGS='-Ccodegen-units=1' cargo-deb -- --features alsa-backend
else
    # rustup default stable-arm-unknown-linux-gnueabihf
    RUSTFLAGS='-Ccodegen-units=1 -Ctarget-feature=+v6,+vfp2' cargo-deb -- --features alsa-backend
    # rustup default stable-armv7-unknown-linux-gnueabihf
fi

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: cargo-deb failed during build"
    exit
fi

mv target/debian/* ..
#------------------------------------------------------------
# post_build
rbl_move_to_dist

echo "done"

