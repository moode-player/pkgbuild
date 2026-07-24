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

# Cap build parallelism to the board's RAM, not its core count. cargo
# defaults to one rustc per core (nproc); on low-RAM Pis (3A+/Zero 2 W =
# 4 cores / 512 MB) that stacks 4 rustc and thrashes swap. Budget 512 MB
# per parallel rustc, clamp to [1, nproc]: 512 MB -> 1 job, 1 GB -> 2,
# 2 GB and up -> 4. An explicit CARGO_BUILD_JOBS from the environment
# always wins.
if [[ -z "$CARGO_BUILD_JOBS" ]]
then
    MEM_MB=`awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo`
    # the +512 absorbs what MemTotal under-reports (CMA/GPU reserved), so
    # that a 1 GB board announcing ~905 MB still lands on 2 jobs.
    CARGO_BUILD_JOBS=$(( (MEM_MB + 512) / 512 ))
    [[ $CARGO_BUILD_JOBS -lt 1 ]] && CARGO_BUILD_JOBS=1
    [[ $CARGO_BUILD_JOBS -gt `nproc` ]] && CARGO_BUILD_JOBS=`nproc`
    export CARGO_BUILD_JOBS
fi
echo "${YELLOW}building librespot with CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS} (RAM ${MEM_MB:-?}MB, `nproc` cores)${NORMAL}"

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
