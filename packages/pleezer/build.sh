#!/bin/bash
#########################################################################
#
# Build recipe for pleezer debian package
#
# (C) bitkeeper 2024 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="pleezer_0.3.0-1moode1"

PKG_SOURCE_GIT="https://github.com/roderickvd/pleezer.git"
PKG_SOURCE_GIT_TAG="v0.3.0"

rbl_check_cargo
rbl_prepare_clone_from_git ${PKG_SOURCE_GIT} ${PKG_SOURCE_GIT_TAG}
rbl_create_git_archive ${PKG_SOURCE_GIT_TAG} ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

# Add to [package.metadata.deb] section of Cargo.toml:
sed -i "s/^priority = \"optional\"/priority = \"optional\"\nrevision = \"${DEBVER}${DEBLOC}\"/" Cargo.toml
if [[ $? -gt 0 ]]
then
    echo "${RED}Error: sed failed to set correct PKG VERSION!${NORMAL}"
    exit
fi

RUSTFLAGS='-Ccodegen-units=1' cargo-deb --

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: cargo-deb failed during build${NORMAL}"
    exit
fi

mv target/debian/pleezer*.deb ..
/build/pleezer-0.2.0/target/debian/pleezer_0.2.0_arm64.deb
#------------------------------------------------------------
# post_build
rbl_move_to_dist

echo "done"
