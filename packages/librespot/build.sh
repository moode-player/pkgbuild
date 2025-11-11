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

PKG="librespot_0.7.1-1moode1"

PKG_SOURCE_GIT="https://github.com/librespot-org/librespot.git"
PKG_SOURCE_GIT_TAG="v0.8.0"

rbl_check_cargo
rbl_prepare_clone_from_git ${PKG_SOURCE_GIT} ${PKG_SOURCE_GIT_TAG}
rbl_create_git_archive ${PKG_SOURCE_GIT_TAG} ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

rbl_check_build_dep libasound2-dev

#Add to [package.metadata.deb] section of Cargo.toml:
sed -i "s/^priority = \"optional\"/priority = \"optional\"\nrevision = \"${DEBVER}${DEBLOC}\"/" Cargo.toml
if [[ $? -gt 0 ]]
then
    echo "${RED}Error: sed failed to set correct PKG VERSION!${NORMAL}"
    exit
fi

# rustup default stable-aarch64-unknown-linux-gnu
RUSTFLAGS='-Ccodegen-units=1' cargo-deb -- --features alsa-backend

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: cargo-deb failed during build${NORMAL}"
    exit
fi

mv target/debian/* ..
#------------------------------------------------------------
# post_build
rbl_move_to_dist

echo "done"
