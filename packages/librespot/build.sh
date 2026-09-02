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

PKG="librespot_0.8.0-1moode1"

PKG_SOURCE_GIT="https://github.com/librespot-org/librespot.git"
PKG_SOURCE_GIT_TAG="v0.8.0"

# Set before rbl_check_cargo so it also covers the cargo-deb install it may
# trigger, itself a build of some 200 crates.

# cargo defaults to one rustc per core; on a 4-core 512 MB Pi that stacks four
# and thrashes swap. Budget 512 MB per job, clamped to [1, nproc], so 2 GB and
# up keeps today's default. An explicit CARGO_BUILD_JOBS wins.
if [[ -z "$CARGO_BUILD_JOBS" ]]
then
    MEM_MB=`awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo`
    # +512 absorbs what MemTotal under-reports (CMA/GPU), so a 1 GB board
    # announcing ~905 MB still lands on 2 jobs
    CARGO_BUILD_JOBS=$(( (MEM_MB + 512) / 512 ))
    [[ $CARGO_BUILD_JOBS -lt 1 ]] && CARGO_BUILD_JOBS=1
    [[ $CARGO_BUILD_JOBS -gt `nproc` ]] && CARGO_BUILD_JOBS=`nproc`
    export CARGO_BUILD_JOBS
fi
echo "${YELLOW}building librespot with CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS} (RAM ${MEM_MB:-?}MB, `nproc` cores)${NORMAL}"

# A codegen thread can overflow its 8 MiB stack on librespot-protocol and take
# rustc down with SIGSEGV inside LLVM (aarch64). 16 MiB is what rustc's own
# diagnostic suggests, and it measured free on Pi 4 and Pi 5.
export RUST_MIN_STACK=${RUST_MIN_STACK:-16777216}

rbl_check_cargo
rbl_prepare_clone_from_git ${PKG_SOURCE_GIT} ${PKG_SOURCE_GIT_TAG}
rbl_create_git_archive ${PKG_SOURCE_GIT_TAG} ../${PKGNAME}_${PKGVERSION}.orig.tar.gz

# ------------------------------------------------------------
# Custom part of the packing

rbl_check_build_dep libasound2-dev
rbl_check_build_dep libssl-dev

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
