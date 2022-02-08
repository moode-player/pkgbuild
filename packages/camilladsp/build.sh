#!/bin/bash

. ../../scripts/rebuilder.lib.sh

PKG="camilladsp_0.6.3-1moode2"

PKG_SOURCE_GIT="https://github.com/HEnquist/camilladsp.git"
PKG_SOURCE_GIT_TAG="v0.6.3"

rbl_check_cargo
rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG
rbl_create_git_archive $PKG_SOURCE_GIT_TAG $BUILD_ROOT_DIR/${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

# Install deps
rbl_check_build_dep libasound2-dev

# Set install location to /usr/local/bin
patch -p1 < $BASE_DIR/camilladsp_cargo-deb.patch

# Add to [package.metadata.deb] section of Cargo.toml:
echo "" >> Cargo.toml
echo "revision=\"$DEBVER$DEBLOC\"" >> Cargo.toml
# echo "" >> Cargo.toml

# Build it for arch with neon support
rustup default stable-armv7-unknown-linux-gnueabihf
RUSTFLAGS='-C target-feature=+neon -C target-cpu=native' cargo-deb -- --no-default-features --features alsa-backend --features websocket
if [[ $? -gt 0 ]]
then
    echo "${RED}Error: cargo-deb failed during build"
    exit
fi

mv target/debian/* $BUILD_ROOT_DIR
#------------------------------------------------------------

rbl_move_to_dist

echo "done"

