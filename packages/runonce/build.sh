#!/bin/bash
#########################################################################
#
# Build recipe for a runonce after boot service
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

KERNEL_VER=$(rbl_get_current_kernel_version)

PKG="runonce_0.1.0-1"

rbl_check_fpm

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir
_rbl_cleanup_previous_build
_rbl_change_to_build_root
# dget $1
mkdir -p "$PKGNAME-$PKGVERSION"
_rbl_cd_source_dir

cd $BUILD_ROOT_DIR
#------------------------------------------------------------
# Custom part of the packing
mkdir -p $PKGDIR/usr/local/bin
cp $BASE_DIR/runonce $PKGDIR/usr/local/bin/
mkdir -p $PKGDIR/etc/runonce.d/ran
echo "test" > $PKGDIR/etc/runonce.d/test

# build the package
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category misc \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://github.com/moode-player/pkgbuild \
-m $DEBEMAIL \
--description "Service for running scritp once after boot. \
Place files to run once in /etc/runonce.d. \
The files are runned after systemd multi-user.target." \
--deb-systemd $BASE_DIR/run_once.service \
--deb-systemd-enable \
$PKGDIR/usr/=/usr/. \
$PKGDIR/etc/=/etc/.


#------------------------------------------------------------
rbl_move_to_dist

echo "done"