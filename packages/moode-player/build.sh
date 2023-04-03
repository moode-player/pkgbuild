#!/bin/bash
#########################################################################
#
# Script for building moode-player package
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

# Package version to Build
PKG="moode-player_8.3.1-1moode1~pre1"

# directory that holds distributable files (for example the last major releases radio-stations zip)
DIST_DIR="dist/binary"

# PKG_SOURCE_GIT="https://github.com/moode-player/moode.git"
# PKG_SOURCE_GIT_TAG="r760prod"

# For now git isn't used to get the source. During development it is much handier
# to use an already checked out and Gulp built version of moode.
# The enviroment var MOODE_DIR should be set to the location where the moode source repo.

# sync required npm modules for gulp build if if already exists
NPM_CI=0

# build web app with gulp, to speed up test build without change to frontend (or manual build) diable this
BUILD_APP=1

GULP_BIN="${MOODE_DIR}/node_modules/.bin/gulp"

# location where we build a fakeroot system with the moode file to be package into the package
PKG_ROOT_DIR="${BUILD_ROOT_DIR}/root"

# array listing directories that we need to create in the target rootdir of the build package
declare PKG_ROOT_DIR_SUBDIRS=(
    "/home"
    "/mnt/NAS"
    "/mnt/SDCARD"
    "/var/local/www/imagesw/radio-logos/thumbs"
    "/var/lib/mpd/music/RADIO"
    "/var/lib/cdsp"
    "/var/www"
)

# location for files that should overwrite existing files (not owned by moode-player)
NOT_OWNED_TEMP=${PKG_ROOT_DIR}/usr/share/moode-player

# similar array listing directories that we need to create in the target rootdir
# but this time containing system files that we want to override that are not "owned" by moode-player package
declare NOT_OWNED_TEMP_SUBDIRS=(
    "/var/lib/mpd/playlists"
)

# ----------------------------------------------------------------------------
# 1. Prepare package build dir and build deps

# Check build dependencies
# the web app is build with gulp
rbl_check_build_dep npm
# we need sqlite to create potential radio station patches
rbl_check_build_dep sqlite3
# For packaging, fpm is used, which is created with Ruby
rbl_check_fpm

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir

_rbl_cleanup_previous_build
_rbl_change_to_build_root

# init build root
rm -rf "${BUILD_ROOT_DIR}/root"
mkdir -p "${BUILD_ROOT_DIR}/root"

if [ -d "${MOODE_DIR}" ]
then
    echo "${YELLOW}Error: MOODE_DIR should point to a moode source dir${NORMAL}"
    exit 1
fi


if [ -z "${PKG_ROOT_DIR}" ]
then
    echo "${YELLOW}Error: PKG_ROOT_DIR is not set?${NORMAL}"
    exit 1
fi

# TODO: DANGER ZONE, Add some prelim checks to ensure $PKG is set and not empty
rm -rf ${PKG}*.deb
# ----------------------------------------------------------------------------
# 2. Buildweb app an deploy to test directory (prepared for copy)

cd "${MOODE_DIR}" || exit

#TODO: detect if node_modules is missing and if so do both steps
if [ ${NPM_CI} -gt 0 ]  || [ ! -d "${MOODE_DIR}/node_modules" ]
then
    npm ci
fi

if [[ ${BUILD_APP} -gt 0 ]]
then
    ${GULP_BIN} clean --all
    ${GULP_BIN} build
fi

${GULP_BIN} deploy --test

# ----------------------------------------------------------------------------
# 3. Collect installable files
#
# Collect files for the package in the $PKG_ROOT_DIR
# Some file cannot the directly owned by the package, because it is owned by
# an other package. In this case fles need to be copied after install and are temporaty located in $NOT_OWNED_TEMP.
#
# If it is really required to install an already owned file, the
# preinstall script of the pacakge should use `dpkg-divert`
#
# ----------------------------------------------------------------------------

# generate moode radio stations backup file (used for populating the station from the installer)

if ! sqlite3 "${BUILD_ROOT_DIR}/moode-sqlite3.db" < "${MOODE_DIR}/var/local/www/db/moode-sqlite3.db.sql"
then
    echo "${RED}Error: couldn't create temporary database!${NORMAL}"
    cd ..
    exit 1
fi

"${MOODE_DIR}/www/util/station_manager.py" --db "${BUILD_ROOT_DIR}/moode-sqlite3.db" --logopath "${MOODE_DIR}/var/local/www/imagesw/radio-logos" --scope moode --export "${BUILD_ROOT_DIR}/moode-stations-full_$PKGVERSION.zip"
if [ ! -f "${BASE_DIR}/${DIST_DIR}/moode-stations-full_${PKGMAJORVERSION}.0.0.zip" ]
then
    echo "${RED}Error: radio station base backup ${BASE_DIR}/${DIST_DIR}/moode-stations-full_${PKGMAJORVERSION}.0.0.zip not found!${NORMAL}"
    mkdir "${BASE_DIR}/${DIST_DIR}/" -p
    wget --no-verbose https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-full_${PKGMAJORVERSION}.0.0.zip -O "${BASE_DIR}/${DIST_DIR}/moode-stations-full_${PKGMAJORVERSION}.0.0.zip"
fi

"${MOODE_DIR}/www/util/station_manager.py" --db "${BUILD_ROOT_DIR}/moode-sqlite3.db" --logopath "${MOODE_DIR}/var/local/www/imagesw/radio-logos" --diff "${BUILD_ROOT_DIR}/moode-stations-update_${PKGVERSION}.zip" --scope moode "${BASE_DIR}/${DIST_DIR}/moode-stations-full_${PKGMAJORVERSION}.0.0.zip"
if [ ! -f "${BUILD_ROOT_DIR}/moode-stations-full_${PKGVERSION}.zip" ]
then
    echo "${RED}Error: radio station full file not generated!${NORMAL}"
    cd ..
    exit 1
fi
if [ ! -f "${BUILD_ROOT_DIR}/moode-stations-update_${PKGVERSION}.zip" ]
then
    echo "${RED}Error: radio station update file not generated!${NORMAL}"
    cd ..
    exit 1
fi

rm -f "${BUILD_ROOT_DIR}/moode-sqlite3.db" || true
# move it to the dist location
mv -f "${BUILD_ROOT_DIR}"/moode-stations-*_"${PKGVERSION}.zip"  "${BASE_DIR}/${DIST_DIR}/"

# Create empty directories needed later
mkdir -p "${NOT_OWNED_TEMP}"

# Create empty directories from our array on the root dir
for dir in "${PKG_ROOT_DIR_SUBDIRS[@]}"; do \
    echo "Creating directory: ${PKG_ROOT_DIR}${dir}"
    mkdir -p "${PKG_ROOT_DIR}${dir}"
done

# Create empty directories from our array on the not owned temp dir
for dir in "${NOT_OWNED_TEMP_SUBDIRS[@]}"; do \
    echo "Creating directory: ${NOT_OWNED_TEMP}${dir}"
    mkdir -p "${NOT_OWNED_TEMP}${dir}"
done


# rsync dist stuff from moode source to target build directory for packaging
rsync \
    --archive \
    --verbose \
    --relative \
    --prune-empty-dirs \
    --exclude={'*.sed*','*.overwrite*','*.ignore*','moode-sqlite3.db','radio-logos'} \
    boot/ \
    etc/ \
    lib/ \
    var/ \
    "${PKG_ROOT_DIR}" # target to sync to

rsync \
    --archive \
    --verbose \
    --relative \
    --prune-empty-dirs \
    --include={'*/','*.overwrite*'} \
    --exclude="*" \
    boot/ \
    etc/ \
    lib/ \
    var/ \
    "${NOT_OWNED_TEMP}"

rsync -av --exclude={'xinitrc.default','dircolors'} "home/" "${PKG_ROOT_DIR}/home/pi"

# copy over important single files
cp "${BASE_DIR}/moode-apt-mark.conf" "${PKG_ROOT_DIR}/etc/"
cp "${MOODE_DIR}/home/xinitrc.default" "${PKG_ROOT_DIR}/home/pi/.xinitrc"
cp "${MOODE_DIR}/home/dircolors" "${PKG_ROOT_DIR}/home/pi/.dircolors"
cp -r "${MOODE_DIR}/sdcard/Stereo Test/" "${PKG_ROOT_DIR}/mnt/SDCARD"

# /usr
rsync \
    --archive \
    --verbose \
    --relative \
    --prune-empty-dirs \
    --exclude={'mpd.conf','mpdasrc.default','install-wifi','html/index.html'} \
    usr/ \
    "${PKG_ROOT_DIR}"
    
rsync \
    --archive \
    --verbose \
    --relative \
    --prune-empty-dirs \
    --include={'*/','*.overwrite*'} \
    --exclude={'*','mpd.conf','mpdasrc.default','install-wifi','html/index.html'} \
    usr/ \
    "${NOT_OWNED_TEMP}"

cp "${BASE_DIR}/moode-apt-mark" "${PKG_ROOT_DIR}/usr/local/bin"

# Create curated always overwrite playlist for the radio stations
cp "${MOODE_DIR}/var/lib/mpd/playlists/Default Playlist.m3u" "${NOT_OWNED_TEMP}/var/lib/mpd/playlists/Curated Radio Stations.m3u"

# /var/lib/mpd
chmod 0777 "${PKG_ROOT_DIR}/var/lib/mpd/music/RADIO"

# /var/lib/cdsp/
chmod 0777 "${PKG_ROOT_DIR}/var/lib/cdsp"

# /var/www
cp -r "${MOODE_DIR}/build/dist/var/www/"* "${PKG_ROOT_DIR}/var/www/"

# In $NOT_OWNED_TEMP remove the ".overwrite" part from the files
function rename_files() {
    org_name=${1}
    new_name=$(echo "${org_name}" | sed -r 's/(.*)[.]overwrite(.*)/\1\2/')
    mv "${org_name}" "${new_name}"
}
export -f rename_files;
find "${NOT_OWNED_TEMP}" -name "*.overwrite*" -exec bash -c 'rename_files "{}"' \;

# echo "** Reset permissions"
chmod -R 0755  "${PKG_ROOT_DIR}/var/www"
chmod 0755  "${PKG_ROOT_DIR}/var/www/command/"*
chmod 0755  "${PKG_ROOT_DIR}/var/www/util/"*
chmod -R 0755  "${PKG_ROOT_DIR}/var/local/www"
chmod -R 0777  "${PKG_ROOT_DIR}/var/local/www/commandw/"*
chmod -R 0766  "${PKG_ROOT_DIR}/var/local/www/db"
chmod -R 0755  "${PKG_ROOT_DIR}/usr/local/bin"

# chmod -R ug-s /var/local/www
chmod -R 0755  "${PKG_ROOT_DIR}/usr/local/bin"

# ------------------------------------------------------------
# 5. Create the package
# Copy and fix version number is postinstall script
sed -e "s/^PKG_VERSION=.*/PKG_VERSION=\"${PKGVERSION}\"/" < "${BASE_DIR}/postinstall.sh" > "${BUILD_ROOT_DIR}/postinstall.sh"
#TODO: Critical look at the deps, remove unneeded.
#TODO: Add license and readme, improve description

# change back to our build dir for the actual package generation
cd "${BUILD_ROOT_DIR}" || exit

# Don't include packages as dependency, if those package depends on the used kernel (like drivers).
# Install those separate.
fpm -s dir -t deb -n "${PKGNAME}" -v "${PKGVERSION}" \
--license GPLv3 \
--category sound \
-S moode \
--iteration "${DEBVER}${DEBLOC}" \
-a all \
--deb-priority optional \
--url https://www.moode.org \
-m moodeaudio.org \
--description 'moOde audio player' \
--after-install "${BUILD_ROOT_DIR}/postinstall.sh" \
--before-remove "${BASE_DIR}/preremove.sh" \
--config-files usr/share/camilladsp/configs \
--config-files usr/share/camilladsp/coeffs \
--depends alsa-cdsp \
--depends alsacap \
--depends ashuffle \
--depends avahi-utils \
--depends bluez \
--depends bluez-alsa-utils \
--depends bluez-firmware \
--depends boss2-oled-p3 \
--depends bs2b-ladspa \
--depends camilladsp \
--depends camillagui \
--depends caps \
--depends chromium-browser \
--depends dnsmasq \
--depends dos2unix \
--depends exfat-fuse \
--depends expect \
--depends ffmpeg \
--depends flac \
--depends fonts-arphic-ukai \
--depends fonts-arphic-uming \
--depends fonts-ipafont-gothic \
--depends fonts-ipafont-mincho \
--depends fonts-unfonts-core \
--depends fonts-unfonts-core \
--depends haveged \
--depends hostapd \
--depends id3v2 \
--depends inotify-tools \
--depends libasound2-plugin-bluez \
--depends libasound2-plugin-equal \
--depends libatasmart4 \
--depends libbs2b0 \
--depends libconfuse-dev \
--depends libdbus-glib-1-2 \
--depends libdbus-glib-1-dev \
--depends libdevmapper-event1.02.1 \
--depends libgudev-1.0-0 \
--depends libmediainfo0v5 \
--depends libmms0 \
--depends libnss-winbind \
--depends librespot \
--depends libsgutils2-2 \
--depends libtool-bin \
--depends libzen0v5 \
--depends lsb-release \
--depends mediainfo \
--depends minidlna \
--depends mpc \
--depends mpd \
--depends mpd2cdspvolume \
--depends nfs-kernel-server \
--depends nginx \
--depends nmap \
--depends ntfs-3g \
--depends php-fpm \
--depends php-sqlite3 \
--depends php-yaml \
--depends php7.4-gd \
--depends pi-bluetooth \
--depends python3-dbus \
--depends python3-libupnpp \
--depends python3-musicpd \
--depends python3-pip \
--depends python3-rpi.gpio \
--depends python3-setuptools \
--depends rpi-update \
--depends runonce \
--depends samba \
--depends shairport-sync \
--depends shellinabox \
--depends smbclient \
--depends sox \
--depends sqlite3 \
--depends squashfs-tools \
--depends squeezelite \
--depends sysstat \
--depends telnet \
--depends triggerhappy \
--depends trx \
--depends udevil \
--depends udisks-glue \
--depends upmpdcli \
--depends winbind \
--depends xfsprogs \
--depends xinit \
--depends xorg \
--depends zip \
--config-files /var/lib/mpd/playlists \
root/boot/.=/boot \
root/var/.=/var \
root/home/.=/home \
root/mnt/.=/mnt \
root/usr/.=/usr \
root/lib/.=/lib \
root/etc/.=/etc

if [[ $? -gt 0 ]]
then
    echo "${RED}Error: failure during fpm.${NORMAL}"
    exit 1
fi

#------------------------------------------------------------
rbl_move_to_dist

echo "done"
