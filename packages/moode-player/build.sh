#!/bin/bash
#########################################################################
#
# Scripts for building moode packages
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="moode-player_8.0.0-1moode1pre5"

# PKG_SOURCE_GIT="https://github.com/moode-player/moode.git"
# PKG_SOURCE_GIT_TAG="r760prod"

# For now git isn't used to get the source. During development it is much handier
# to use an already checkout ( and gulp build version of moode )
# The enviroment var MOODE_DIR should be set to the location where the moode project source is.

# sync required npm modules for gulp build
NPM_CI=0
# build web app with gulp
BUILD_APP=0

GULP_BIN=$MOODE_DIR/node_modules/.bin/gulp

# ----------------------------------------------------------------------------
# 1. Prepare pacakge build dir and build deps

# the web app is build with gulp
rbl_check_build_dep npm
# For packign fpm is used, which is created with Ruby
rbl_check_fpm

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir

#_rbl_cleanup_previous_build
_rbl_change_to_build_root

# location where we build a fakeroot system with the moode file to be package into the package
PKG_ROOT_DIR="$BUILD_ROOT_DIR/root"


# init build root
rm -rf $BUILD_ROOT_DIR/root
mkdir -p $BUILD_ROOT_DIR/root

if [ -z "$MOODE_DIR" ]
then
    echo "${YELLOW}Error: MOODE_DIR is should point to a moode source dir${NORMAL}"
    exit 1
fi


if [ -z "$PKG_ROOT_DIR" ]
then
    echo "${YELLOW}Error: PKG_ROOT_DIR is not set?${NORMAL}"
    exit 1
fi

rm $PKG*.deb
# ----------------------------------------------------------------------------
# 2. Buildweb app an deploy to test directory (prepared for copy)

cd $MOODE_DIR

if [[ $NPM_CI -gt 0 ]]
then
    npm ci
fi

if [[ $BUILD_APP -gt 0 ]]
then
    $GULP_BIN clean --all
    $GULP_BIN build
fi
$GULP_BIN deploy --test

cd $BUILD_ROOT_DIR

# ----------------------------------------------------------------------------
# 3. Collect installable files
#
# Collect all file that can be directly writen into the filesystem on install
# This means that the file shouldn't be owned by another pacakge!
#
# If it is really required to install an already owned file, the
# preinstall script of the pacakge should use `dpkg-divert`
# ----------------------------------------------------------------------------
# Home dir
mkdir -p $PKG_ROOT_DIR/home/pi
rsync -av --exclude xinitrc.default --exclude dircolors $MOODE_DIR/home/ $PKG_ROOT_DIR/home/pi
cp $MOODE_DIR/home/xinitrc.default $PKG_ROOT_DIR/home/pi/.xinitrc
cp $MOODE_DIR/home/dircolors $PKG_ROOT_DIR/home/pi/.dircolors

# os header
mkdir -p $PKG_ROOT_DIR/etc/update-motd.d
cp $MOODE_DIR/etc/update-motd.d/* $PKG_ROOT_DIR/etc/update-motd.d/

# /var/wwww
mkdir -p $PKG_ROOT_DIR/var/www
cp -r $MOODE_DIR/build/distr/var/www/* $PKG_ROOT_DIR/var/www/

# /usr
rsync -av --exclude='rx' --exclude='tx' --exclude='alsacap' --exclude='lib' --exclude='radio_scripts' --exclude='html/index.html' $MOODE_DIR/usr/ $PKG_ROOT_DIR/usr

# /var
rsync -av --exclude='moode-sqlite3.db' --exclude='cdsp_extensions.json' $MOODE_DIR/var/ $PKG_ROOT_DIR/var

mkdir -p $PKG_ROOT_DIR/var/local/php

# Radio stations
# TODO: may just use the station manager to import the default moode stations (and then also remove the stations from the db by default)
mkdir -p $PKG_ROOT_DIR/var/lib/mpd/music/RADIO
mkdir -p $PKG_ROOT_DIR/var/lib/mpd/playlists
cp $MOODE_DIR/mpd/RADIO/* $PKG_ROOT_DIR/var/lib/mpd/music/RADIO
cp $MOODE_DIR/mpd/playlists/* $PKG_ROOT_DIR/var/lib/mpd/playlists

# mkdir -p $BUILD_ROOT_DIR/
echo "** Create mount points"
mkdir -p $PKG_ROOT_DIR/mnt/NAS
mkdir -p $PKG_ROOT_DIR/mnt/SDCARD
mkdir -p $PKG_ROOT_DIR/mnt/UPNP

echo "** Create misc files"
cp $MOODE_DIR/mpd/sticker.sql $PKG_ROOT_DIR/var/lib/mpd
cp -r "$MOODE_DIR/other/sdcard/Stereo Test/" $PKG_ROOT_DIR/mnt/SDCARD


# echo "** Reset permissions"
# #TODO: maybe set the rights before packed
chmod -R 0755  $PKG_ROOT_DIR/var/www
chmod 0755  $PKG_ROOT_DIR/var/www/command/*
chmod -R 0755  $PKG_ROOT_DIR/var/local/www
chmod -R 0777  $PKG_ROOT_DIR/var/local/www/commandw/*
chmod -R 0766  $PKG_ROOT_DIR/var/local/www/db
chmod -R 0755  $PKG_ROOT_DIR/usr/local/bin

# # chmod -R ug-s /var/local/www
chmod -R 0755  $PKG_ROOT_DIR/usr/local/bin

# exit
# ------------------------------------------------------------
# 4. Collect not directly installable files
NOT_INSTALLABLES="$PKG_ROOT_DIR/usr/share/moode-player"
mkdir -p $NOT_INSTALLABLES

# /boot
rsync -av $MOODE_DIR/boot/ $NOT_INSTALLABLES/boot

# /etc network
mkdir -p $NOT_INSTALLABLES/etc/network
mkdir -p $NOT_INSTALLABLES/etc/hostapd
cp $MOODE_DIR/network/interfaces.default $NOT_INSTALLABLES/etc/network/interfaces
cp $MOODE_DIR/network/dhcpcd.conf.default $NOT_INSTALLABLES/etc/dhcpcd.conf
cp $MOODE_DIR/network/hostapd.conf.default $NOT_INSTALLABLES/etc/hostapd/hostapd.conf

#TODO: find out which files can be directly installed (as copy to prevent no update due etc file)
# /etc
rsync -av $MOODE_DIR/etc/ $NOT_INSTALLABLES/etc

cp $MOODE_DIR/mpd/mpd.conf.default $NOT_INSTALLABLES/etc/mpd.conf

#TODO: check the service files and what to do with those
# /lib mainly service files
rsync -av $MOODE_DIR/lib/ $NOT_INSTALLABLES/lib

# ------------------------------------------------------------
# 5. Create the package

#TODO: Critical look at the deps, remove unneeded.
#TODO: Add license and readme, improve description

fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://www.moode.org \
-m moodeaudio.org \
--description 'moode audioplayer.' \
--after-install $BASE_DIR/postinstall.sh \
--depends rpi-update \
--depends php-fpm \
--depends nginx \
--depends sqlite3 \
--depends php-sqlite3 \
--depends php7.4-gd \
--depends bs2b-ladspa \
--depends libbs2b0 \
--depends libasound2-plugin-equal \
--depends telnet \
--depends sysstat \
--depends squashfs-tools \
--depends shellinabox \
--depends samba \
--depends smbclient \
--depends ntfs-3g \
--depends exfat-fuse \
--depends inotify-tools \
--depends ffmpeg \
--depends avahi-utils \
--depends python3-setuptools \
--depends libmediainfo0v5 \
--depends libmms0 \
--depends libzen0v5 \
--depends winbind \
--depends libnss-winbind \
--depends djmount \
--depends haveged \
--depends python3-pip \
--depends xfsprogs \
--depends triggerhappy \
--depends zip \
--depends id3v2 \
--depends dos2unix \
--depends php-yaml \
--depends sox \
--depends flac \
--depends nmap \
--depends libtool-bin \
--depends libatasmart4 \
--depends libdbus-glib-1-2 \
--depends libgudev-1.0-0 \
--depends libsgutils2-2 \
--depends libdevmapper-event1.02.1 \
--depends libconfuse-dev \
--depends libdbus-glib-1-dev \
--depends udevil \
--depends dnsmasq \
--depends hostapd \
--depends bluez-firmware \
--depends pi-bluetooth \
--depends alsa-cdsp \
--depends alsacap \
--depends bluez \
--depends bluez-alsa-utils \
--depends libasound2-plugin-bluez \
--depends python3-rpi.gpio \
--depends camilladsp \
--depends camillagui \
--depends caps \
--depends librespot \
--depends mediainfo \
--depends mpc \
--depends mpd \
--depends python3-libupnpp \
--depends shairport-sync \
--depends squeezelite \
--depends minidlna \
--depends trx \
--depends udisks-glue \
--depends upmpdcli \
--depends pcm1794a \
--depends aloop \
--depends ax88179 \
root/var/.=/var \
root/home/.=/home \
root/mnt/.=/mnt \
root/usr/.=/usr \
root/etc/.=/etc


if [[ $? -gt 0 ]]
then
    echo "${RED}Error: failure during fpm.${NORMAL}"
    exit 1
fi

#------------------------------------------------------------
rbl_move_to_dist

echo "done"


