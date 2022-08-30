#!/bin/bash
#########################################################################
#
# Build recipe for camillagui + camillagui-backend debian package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="camillagui_1.0.0-1moode4"

PKG_SOURCE_GIT="https://github.com/HEnquist/camillagui.git"
PKG_SOURCE_GIT_TAG="v1.0.0-rc5"

PKG_SOURCE_GIT_BACKEND="https://github.com/HEnquist/camillagui-backend.git"
PKG_SOURCE_GIT_TAG_BACKEND="v1.0.0-rc6"

# gui is a react app
rbl_check_build_dep npm
# For packign fpm is used, which is created with Ruby
rbl_check_fpm

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir
_rbl_cleanup_previous_build
_rbl_change_to_build_root

# ------------------------------------------------------------
# Custom part of the packing

echo "build root : $BUILD_ROOT_DIR"
# ---------------------------------------------------------------
# A. camillagui
# ---------------------------------------------------------------
git clone $PKG_SOURCE_GIT
cd camillagui
# git checkout -b $PKG_SOURCE_GIT_TAG origin/$PKG_SOURCE_GIT_TAG
git checkout -b $PKG_SOURCE_GIT_TAG $PKG_SOURCE_GIT_TAG
# add option to hide files tab on expert mode:
patch -p1 < $BASE_DIR/camillagui_hide_files.patch
# installing npm deps with npm ci failed, so use npm install instead
# npm ci
npm install
npm install react-scripts
# npx browserslist@latest --update-db
npm run-script build
cd ..

# ---------------------------------------------------------------
# B. camillagui-backend
# ---------------------------------------------------------------
git clone $PKG_SOURCE_GIT_BACKEND
cd camillagui-backend
# git checkout -b $PKG_SOURCE_GIT_TAG_BACKEND origin/$PKG_SOURCE_GIT_TAG_BACKEND
git checkout -b $PKG_SOURCE_GIT_TAG_BACKEND $PKG_SOURCE_GIT_TAG_BACKEND
# add option to hide files tab on expert mode:
patch -p1 < $BASE_DIR/camillagui_backend_hide_files.patch
cd ..

# ---------------------------------------------------------------
# C. packing
# ---------------------------------------------------------------

# Create the package
# setup a directory structure for the files which should end up in the deb file:
rm -rf package
mkdir -p package/opt/camillagui
mkdir -p package/etc/systemd/system

# copy the required files into the directory structure
cp -r camillagui/build camillagui-backend/backend camillagui-backend/config camillagui/LICENSE.txt camillagui-backend/main.py camillagui-backend/README.md package/opt/camillagui
cp $BASE_DIR/css-variables.css package/opt/camillagui/build
cp $BASE_DIR//camillagui.yml package/opt/camillagui/config
cp $BASE_DIR/gui-config.yml package/opt/camillagui/config
cp $BASE_DIR/camillagui.service package/etc/systemd/system

# build a deb files based on the directory structure
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
-a all \
--deb-priority optional \
--url https://github.com/HEnquist/camilladsp \
-m moodeaudio.org \
--description 'CamillaGUI is a web-based GUI for CamillaDSP.' \
--depends python3-camilladsp \
--depends python3-camilladsp-plot \
--depends python3-aiohttp \
--depends python3-websocket \
--depends python3-jsonschema \
--depends python3-numpy \
--pre-install $BASE_DIR/deb_preinstall.sh \
--before-remove $BASE_DIR/deb_beforeremove.sh \
--deb-no-default-config-files \
package/opt/camillagui/.=/opt/camillagui \
package/etc/=/etc/.

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: failure during fpm.${NORMAL}"
    exit 1
fi


# mv ${PKGNAME}_${FULL_VERSION}*.deb $BASE_DIR
#cd $BASE_DIR

#------------------------------------------------------------
rbl_move_to_dist

echo "done"


