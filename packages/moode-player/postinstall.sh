#!/bin/bash
################################################################################
#
# Script for post processing afer moode-player package installation
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
################################################################################

ACTION=$1
VERSION=$2

# Version number is updated via sed upstream in build.sh
PKG_VERSION="x.x.x"

# SQL database path and PHP version
SQLDB=/var/local/www/db/moode-sqlite3.db
PHP_VER="8.4"
# Files marked as 'overwrite' in the source tree are stored here
SRC=/usr/share/moode-player

################################################################################
# Import radio stations
# TODO: Support mode [full|update], required when 1st update needs to be created
################################################################################
function import_stations() {
    mode=$1
    url=$2
    #url="https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-full_$PKG_VERSION.zip"
    if [ -z "$MOODE_STATIONS_URL" ]
    then
        MOODE_STATIONS_URL="$url"
    fi

    TMP_STATIONS_BACKUP="/tmp/"`basename $url`

    if [ -f $MOODE_STATIONS_URL ]
    then
        cp $MOODE_STATIONS_URL $TMP_STATIONS_BACKUP
    else
        #wget --no-verbose -O $TMP_STATIONS_BACKUP $MOODE_STATIONS_URL || true
        wget -q -O $TMP_STATIONS_BACKUP $MOODE_STATIONS_URL || true
    fi

    if [ -f $TMP_STATIONS_BACKUP ]
    then
        if [ "$mode" = "full" ]
        then
            /var/www/util/station_manager.py --scope moode --how clear --import $TMP_STATIONS_BACKUP > /dev/null
        else
            /var/www/util/station_manager.py --import --scope moode --how merge $TMP_STATIONS_BACKUP > /dev/null
        fi

        rm -f $TMP_STATIONS_BACKUP
    else
        echo "Couldn't import stations file from $MOODE_STATIONS_URL"
    fi
}

################################################################################
# No prior install exists
################################################################################
function on_install() {
    echo "Moode-player package postinstall started"

    # --------------------------------------------------------------------------
    # Initial configuration
    # --------------------------------------------------------------------------
    echo "** Basic optimizations"
    systemctl enable rpcbind > /dev/null 2>&1
    systemctl set-default multi-user.target > /dev/null 2>&1
    systemctl stop apt-daily.timer > /dev/null 2>&1
    systemctl disable apt-daily.timer > /dev/null 2>&1
    systemctl mask apt-daily.timer > /dev/null 2>&1
    systemctl stop apt-daily-upgrade.timer > /dev/null 2>&1
    systemctl disable apt-daily-upgrade.timer > /dev/null 2>&1
    systemctl mask apt-daily-upgrade.timer > /dev/null 2>&1
    systemctl daemon-reload > /dev/null 2>&1
    sed -i "s/^CONF_SWAPSIZE.*/CONF_SWAPSIZE=200/" /etc/dphys-swapfile

    echo "** Disable systemd services managed by moOde"
    # These services are started on-demand or by moOde worker daemon (worker.php)
    disable_services=(
        bluetooth \
        bluealsa \
        bluealsa-aplay \
        bt-agent \
        hciuart \
        minidlna \
        mpd \
        mpd.service \
        mpd.socket \
        mpd2cdspvolume \
        nfs-server \
        nmbd.service \
        nqptp \
        phpsessionclean.service \
        phpsessionclean.timer \
        shellinabox \
        shairport-sync \
        smbd.service \
        squeezelite \
        triggerhappy \
        udisks2 \
        upmpdcli)

    for service in "${disable_services[@]}"
    do
        systemctl stop "${service}" > /dev/null 2>&1
        systemctl disable "${service}" > /dev/null 2>&1
    done

    echo "** Set permissions for systemd files"
    chmod 0644 \
    /etc/systemd/system/bluealsa-aplay@.service \
    /etc/systemd/system/bt-agent.service \
    /etc/systemd/system/plexamp.service \
    /etc/udev/rules.d/10-a2dp-autoconnect.rules \
    /lib/systemd/system/rotenc.service \
    /lib/systemd/system/shellinabox.service \
    /lib/systemd/system/squeezelite.service \
    /lib/systemd/system/localdisplay.service \
    /lib/systemd/system/tmp.mount
    #/etc/systemd/system/bluealsa.service \ We get file not found, very odd

    echo "Set permissions for etc files"
    chmod 0644 \
    /etc/bluealsaaplay.conf \
    /etc/nftables.conf \
    /etc/squeezelite.conf
    #/etc/machine-info \ We get file not found, very odd

    echo "** Set permissions for bluez-alsa D-Bus"
    usermod -a -G audio mpd
    echo "** Set permissions for bt-agent PIN code file"
    chmod 0600 /etc/bluetooth/pin.conf

    echo "** Set permissions for triggerhappy to execute ALSA commands"
    usermod -a -G audio nobody

    echo "** Create MPD runtime environment"
    touch /var/lib/mpd/state

    echo "** Create MPD and NFS symlinks"
    [ ! -e /var/lib/mpd/music/NAS ] &&  ln -s /mnt/NAS /var/lib/mpd/music/NAS
    [ ! -e /var/lib/mpd/music/NVME ] &&  ln -s /mnt/NVME /var/lib/mpd/music/NVME
    [ ! -e /var/lib/mpd/music/SATA ] &&  ln -s /mnt/SATA /var/lib/mpd/music/SATA
    [ ! -e /var/lib/mpd/music/OSDISK ] && ln -s /mnt/OSDISK /var/lib/mpd/music/OSDISK
    [ ! -e /var/lib/mpd/music/SDCARD ] && ln -s /mnt/SDCARD /var/lib/mpd/music/SDCARD
    [ ! -e /var/lib/mpd/music/USB ] && ln -s /media /var/lib/mpd/music/USB
    [ ! -e /srv/nfs ] && mkdir /srv/nfs
    [ ! -e /srv/nfs/usb ] && ln -s /media /srv/nfs/usb
    [ ! -e /srv/nfs/nvme ] && ln -s /mnt/NVME /srv/nfs/nvme
    [ ! -e /srv/nfs/sata ] && ln -s /mnt/SATA /srv/nfs/sata

    echo "** Create moode and PHP logfiles"
    touch /var/log/moode.log
    chmod 0666 /var/log/moode.log
    touch /var/log/php_errors.log
    chmod 0666 /var/log/php_errors.log

    echo "** Set permissions on homedir scripts"
    chmod 0755 /home/pi/*.sh

    echo "** Set permissions on www and camilladsp dirs"
    # Web dirs
    chmod -R 0755 /var/www
    chmod -R 0755 /var/local/www
    chmod -R 0777 /var/local/www/db
    chmod -R ug-s /var/local/www
    # CamillaDSP
    chmod -R a+rw /usr/share/camilladsp
    chown -R mpd /var/lib/cdsp

    echo "** Create moode-sqlite3.db database"
    if [ -f $SQLDB ]
    then
        rm $SQLDB
    fi
    # Strip creation of radio stations from the sql, stations are create by the station backup import
    cat $SQLDB".sql" | grep -v "INSERT INTO cfg_radio" | sqlite3 $SQLDB
    cat $SQLDB".sql" | grep "INSERT INTO cfg_radio" | grep "(499" | sqlite3 $SQLDB

    echo "** Set default accent color"
    sqlite3 $SQLDB "UPDATE cfg_system SET value='Carrot' WHERE param='accent_color'"

    echo "** Import radio stations"
    import_stations full "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-full_$PKG_VERSION.zip"

    echo "** Set permissions for currentsong.txt and playhistory.log"
    touch /var/log/moode_playhistory.log
    touch /var/local/www/currentsong.txt
    chmod 0777 /var/log/moode_playhistory.log
    chmod 0777 /var/local/www/currentsong.txt

    echo "** Set permissions for /var/local/www/db and /var/local/php dirs"
    chmod -R 0777 /var/local/www/db
    chown www-data:www-data /var/local/php

    echo "** Generate alsaequal binary"
    mkdir -p /opt/alsaequal/
    amixer -D alsaequal > /dev/null
    chmod 0755 /opt/alsaequal/alsaequal.bin
    chown mpd:audio /opt/alsaequal//alsaequal.bin

    echo "** Delete certain Linux default files"
    if [ -d "/var/www/html" ]
    then
        rm -rf /var/www/html
    fi
    rm -f /etc/update-motd.d/10-uname
    if [ -f /etc/motd ]
    then
        mv /etc/motd /etc/motd.default
    fi

    echo "** Set permissions for pam and sudoers drop files"
    chmod 0644 /etc/pam.d/sudo
    chmod 0440 /etc/sudoers.d/010_moode
    chmod 0440 /etc/sudoers.d/010_www-data-nopasswd

    # --------------------------------------------------------------------------
    # Overwrite files not owned by moode-player (owned by other packages)
    # --------------------------------------------------------------------------
    echo "** Copy overwrite files to target dirs"
    cp -rf $SRC/etc/* /etc/
    cp -rf $SRC/lib/* /lib/ > /dev/null 2>&1
    cp -rf $SRC/usr/* /usr/ > /dev/null 2>&1
    cp -rf $SRC/var/lib /var/lib/ > /dev/null 2>&1
    # Logic to handle config.txt
    ischroot
    if [ $? -gt 0 ]; then
        # On Bookworm Lite (not running within imgbuild)
        echo "** Copy config.txt to /boot/firmware"
        cp -f $SRC/boot/firmware/config.txt /boot/firmware > /dev/null 2>&1
    else
        # Within imgbuild
        # NOTE: config.txt is installed during worker.php startup
        echo "** Skip copying config.txt to /boot/firmware"
    fi

    # --------------------------------------------------------------------------
    # Patch config files with sed
    # --------------------------------------------------------------------------
    echo "** Patch config files with sed"
    # From the root moode git repo find files to patch with sed:
    #  find . -name "*.sed*" |sort

    # /etc/bluetooth/main.conf
    # Name = Moode Bluetooth
    # Class = 0x20041C
    #   2  = Service Class: Audio
    #   c  = Rendering (Printing, Speaker) Capturing (Scanner, Microphone)
    #   04 = Major Device Class: Audio/Video
    #   1c = Minor Device Class: Portable Audio (Loudspeaker x14 + Headphones  x18)
    # DiscoverableTimeout = 0
    #   Stay discoverable forever
    # ControllerMode = dual
    #   Both BR/EDR and LE transports enabled (when supported by the HW)
    # JustWorksRepairing = always
    # TemporaryTimeout = 90
    #   How long to keep temporary devices around
    sed -i -e 's/[#]Name[ ]=[ ].*/Name = Moode Bluetooth/' \
        -e 's/[#]Class[ ]=[ ].*/Class = 0x2c041c/' \
        -e 's/#DiscoverableTimeout[ ]/DiscoverableTimeout /' \
        -e 's/[#]ControllerMode[ ]=[ ].*/ControllerMode = dual/' \
        -e 's/[#]JustWorksRepairing[ ]=[ ].*/JustWorksRepairing = always/' \
        -e 's/[#]TemporaryTimeout[ ]=[ ].*/TemporaryTimeout = 90/' \
        /etc/bluetooth/main.conf

    # /etc/default/mpd
    # Uncomment # MPDCONF=/etc/mpd.conf
    sed -i "s/^#[ ]MPDCONF/MPDCONF/" /etc/default/mpd

    # /etc/php/$PHP_VER/cli/php.ini
    sed -i -e "s/^post_max_size.*/post_max_size = 128M/" \
        -e "s/^upload_max_filesize.*/upload_max_filesize = 128M/" \
        -e "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" \
        /etc/php/$PHP_VER/cli/php.ini

    # /etc/php/$PHP_VER/fpm/pool.d/www.conf
	# pm.max_children = 64
    sed -i "s/^pm[.]max_children.*/pm.max_children = 64/" /etc/php/$PHP_VER/fpm/pool.d/www.conf

    # /etc/php/$PHP_VER/fpm/php.ini
    # max_execution_time = 300
    # max_input_vars = 32768
    # memory_limit = -1
    # post_max_size = 75M
    # upload_max_filesize = 75M
    # session.save_path = "0;666;/var/local/php"
    sed -i -e "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" \
        -e "s/^max_execution_time.*/max_execution_time = 300/" \
        -e "s/^max_input_time.*/max_input_time = -1/" \
        -e "s/^;max_input_vars.*/max_input_vars = 32768/" \
        -e "s/^memory_limit.*/memory_limit = -1/" \
        -e "s/^post_max_size.*/post_max_size = 128M/" \
        -e "s/^upload_max_filesize.*/upload_max_filesize = 128M/" \
        -e "s/^;defensive.*/defensive = 1/" \
        /etc/php/$PHP_VER/fpm/php.ini

    # /etc/minidlna.conf
    # media_dir=A,/var/lib/mpd/music
    # log_level=off
    # friendly_name=Moode DLNA
    # model_name=MiniDLNA
    # inotify=no
    # wide_links=yes
    sed -i -e '/^media_dir=.*/s/media_dir=.*/media_dir=A,\/var\/lib\/mpd\/music/' \
        -e 's/^[#]log_level=.*/log_level=off/' \
        -e 's/^[#]friendly_name=.*/friendly_name=Moode DLNA/' \
        -e 's/^[#]model_name=.*/model_name=MiniDLNA/' \
        -e 's/^[#]inotify=yes/inotify=no/' \
        -e 's/^[#]wide_links=no/wide_links=yes/' \
        /etc/minidlna.conf

    # /etc/modules
    # add line i2c-dev
    [[ -z $(grep "^i2c-dev" /etc/modules) ]] && sed -i '$a i2c-dev' /etc/modules

    # /etc/shairport-sync.conf
    # interpolation = "soxr";
    # audio_backend_latency_offset_in_seconds = 0.0;
    # audio_backend_buffer_desired_length_in_seconds = 0.2;
    # run_this_before_entering_active_state = "/var/local/www/commandw/spspre.sh";
    # run_this_after_exiting_active_state = "/var/local/www/commandw/spspost.sh";
    # active_state_timeout = 10.0;
    # wait_for_completion = "yes";
    # allow_session_interruption = "no";
    # session_timeout = 120;
    # output_rate = 44100;
    # output_format = "S16";
    # disable_standby_mode = "auto";
    # disable_synchronization = "no";
    # cover_art_cache_directory = "/var/local/www/imagesw/airplay-covers";
    sed -i -e 's/\/\/.*interpolation[ ]=[ ]\"auto\"[;]\(.*\)/interpolation = "soxr";\1/' \
        -e 's/\/\/[[:space:]]\+\(audio_backend_latency_offset_in_seconds\)/\1/' \
        -e 's/\/\/.*\(audio_backend_buffer_desired_length_in_seconds =\)/\1/' \
        -e 's/\/\/.*\(run_this_before_entering_active_state\)[ ]=[ ]\".*\"\(.*\)/\1 = "\/var\/local\/www\/commandw\/spspre.sh"\2/' \
        -e 's/\/\/.*\(run_this_after_exiting_active_state\)[ ]=[ ]\".*\"\(.*\)/\1 = "\/var\/local\/www\/commandw\/spspost.sh"\2/' \
        -e 's/\/\/[[:space:]]\+\(active_state_timeout\)/\1/' \
        -e 's/\/\/[[:space:]]\+wait_for_completion[ ]=[ ]\"no\"[;]\(.*\)/wait_for_completion = "yes";\1/' \
        -e 's/\/\/[[:space:]]\+\(allow_session_interruption\)/\1/' \
        -e 's/\/\/[[:space:]]\+\(session_timeout\)/\1/' \
        -e 's/\/\/[[:space:]]\+output_rate[ ]=[ ]\"auto\"[;]\(.*\)/output_rate = 44100;\1/' \
        -e 's/\/\/[[:space:]]\+output_format[ ]=[ ]\"auto\"[;]\(.*\)/output_format = "S16";\1/' \
        -e 's/\/\/[[:space:]]\+disable_standby_mode[ ]=[ ]\"never\"[;]\(.*\)/disable_standby_mode = "auto";\1/' \
        -e 's/\/\/[[:space:]]\+\(disable_synchronization\)/\1/' \
        -e 's/\/\/.*\(cover_art_cache_directory\)[ ]=[ ]\".*\"\(.*\)/\1 = "\/var\/local\/www\/imagesw\/airplay-covers";/' \
        /etc/shairport-sync.conf

    # /etc/nsswitch.conf
    # passwd:         compat
    # group:          compat
    # shadow:         compat
    # hosts:          files mdns4_minimal [NOTFOUND=return] dns wins mdns4
    sed -i -e '/^passwd:/s/files/compat/' \
        -e '/^group:/s/files/compat/' \
        -e '/^shadow:/s/files/compat/' \
        -e 's/^hosts:.*/hosts:          files mdns4_minimal [NOTFOUND=return] dns wins mdns4/' \
        -e '/^hosts/s/files.*/files mdns4_minimal [NOTFOUND=return] dns wins mdns4/' \
        /etc/nsswitch.conf

    # /etc/upmpdcli.conf
    # friendlyname = Moode UPNP
    # avfriendlyname = Moode UPNP
    # upnpav = 1
    # openhome = 0
    # checkcontentformat = 1
    # iconpath = /usr/share/upmpdcli/moode_audio.png
    # ohproductroom = Moode UPNP
    sed -i -e 's/[#]friendlyname[ ]=.*/friendlyname = Moode UPNP/' \
        -e 's/[#]avfriendlyname[ ]=.*/avfriendlyname = Moode UPNP/' \
        -e 's/[#]upnpav[ ]=.*/upnpav = 1/' \
        -e 's/[#]openhome[ ]=.*/openhome = 0/' \
        -e 's/[#]checkcontentformat[ ]=.*/checkcontentformat = 1/' \
        -e 's/[#]iconpath[ ]=.*/iconpath = \/usr\/share\/upmpdcli\/moode_audio.png/' \
        -e 's/[#]ohproductroom[ ]=.*/ohproductroom = Moode UPNP/' \
        /etc/upmpdcli.conf

    # /etc/X11/Xwrapper.config
    # allowed_users=anybody
    # needs_root_rights=yes
    sed -i "s/^allowed_users.*/allowed_users=anybody\nneeds_root_rights=yes/" /etc/X11/Xwrapper.config

    # /etc/systemd/journald.conf
    # SystemMaxUse=20M
    # RuntimeMaxUse=20M
    sed -i -e "s/^#SystemMaxUse.*/SystemMaxUse=20M/" \
        -e "s/^#RuntimeMaxUse.*/RuntimeMaxUse=20M/" \
        /etc/systemd/journald.conf

    # /etc/log2ram.conf
    # SIZE=32M
    # NOTIFICATION=false
    sed -i -e "s/^SIZE.*/SIZE=32M/" \
        -e "s/^#NOTIFICATION=.*/NOTIFICATION=false/" \
        /etc/log2ram.conf
    # /usr/local/bin/log2ram
    # Add A (preserve ACL's) to rsync options
    # Note: Remove this when new version includes the patch
    sed -i "s/rsync -aXv/rsync -AaXv/" /usr/local/bin/log2ram

    # /etc/logrotate.d/
    chown root:root /etc/logrotate.d/log2ram
    sed -i 's/*.log/log/' /etc/logrotate.d/mpd

	# /etc/peppymeter/config.txt
	# framebuffer.device = /dev/fb0
	# mouse.device = /dev/input/event0
	# mouse.enabled = False
	# pipe.name = /tmp/peppymeter
	sed -i -e 's/^framebuffer.device.*/framebuffer.device = \/dev\/fb0/' \
		-e 's/^mouse.device.*/mouse.device = \/dev\/input\/event0/' \
		-e 's/^mouse.enabled.*/mouse.enabled = False/' \
		-e 's/^pipe.name.*/pipe.name = \/tmp\/peppymeter/' \
		/etc/peppymeter/config.txt

	# /etc/peppyspectrum/config.txt
	# framebuffer.device = /dev/fb0
	# mouse.device = /dev/input/event0
	# mouse.enabled = False
	# pipe.name = /tmp/peppyspectrum
	sed -i -e 's/^framebuffer.device.*/framebuffer.device = \/dev\/fb0/' \
		-e 's/^mouse.device.*/mouse.device = \/dev\/input\/event0/' \
		-e 's/^mouse.enabled.*/mouse.enabled = False/' \
		-e 's/^pipe.name.*/pipe.name = \/tmp\/peppyspectrum/' \
		/etc/peppyspectrum/config.txt

    # --------------------------------------------------------------------------
    # Install NGINX and MPD configs
    # --------------------------------------------------------------------------
    # NGINX config
    echo "** Install NGINX conf"
    cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    rm -f /etc/nginx/sites-enabled/*
    sudo ln -s /etc/nginx/sites-available/moode-http.conf /etc/nginx/sites-enabled/moode-http.conf

    # MPD config
    echo "** Install MPD conf"
    touch /etc/mpd.conf
    chown mpd:audio /etc/mpd.conf
    chmod 0666 /etc/mpd.conf

    # In case any changes are made to systemd file reload config
    ischroot
    if [ $? -gt 0 ]; then
        # On Bookworm Lite (not running within imgbuild)
        echo "** Restart systemd (daemon-reload)"
        systemctl daemon-reload
    fi

    # --------------------------------------------------------------------------
    # Finish up
    # --------------------------------------------------------------------------
    # Don't now why there is a empty database dir instead of a database file
    if [ -d "/var/lib/mpd/database" ]
    then
        echo "** Delete /var/lib/mpd/database dir (it should be a file)"
        rmdir -rf /var/lib/mpd/database
    fi

    echo "** Sync changes to disk"
    sync

    echo "Moode-player package postinstall finished, please reboot"
}

################################################################################
# Prior install exists
#
# Upgrades can come from any version:
# - Detect if a patch is needed to apply
# - Make the patches as fault tolerant as needed
#
################################################################################
function on_upgrade() {
    # --------------------------------------------------------------------------
    # Release 10 series (Trixie)
    # --------------------------------------------------------------------------
	# Introduced in r1001
	#dpkg --compare-versions $VERSION lt "10.0.1-1moode1"
	#if [ $? -eq 0 ]; then
	#	echo "There are no postinstall updates for r1001"
	#fi

    # --------------------------------------------------------------------------
    # Any release
    # --------------------------------------------------------------------------
    # Update SSH header
    cp -f $SRC/etc/update-motd.d/00-moodeos-header /etc/update-motd.d/

    # Update radio stations and logos (version to version)
    # Release 10.0.1
    #dpkg --compare-versions $VERSION lt "10.0.1-1moode1"
    #if [ $? -eq 0 ]; then
    #    import_stations update "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-update-10.0.1.zip"
    #fi

	# Release 10.0.2
    #dpkg --compare-versions $VERSION lt "10.0.2-1moode1"
    #if [ $? -eq 0 ]; then
    #    import_stations update "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-update-10.0.2.zip"
    #fi

    # Reset first use help to show just the Welcome notification.
    # Since this is an update we can assume the first use help coupons have already been dismissed.
    sqlite3 $SQLDB "UPDATE cfg_system SET value='n,n,y' WHERE param='first_use_help'"

    # Set permissions for service files
    chmod 0644 \
    /etc/systemd/system/bluealsa-aplay@.service \
    /etc/systemd/system/bluealsa.service \
    /etc/systemd/system/bt-agent.service \
    /etc/systemd/system/plexamp.service \
    /etc/udev/rules.d/10-a2dp-autoconnect.rules \
    /lib/systemd/system/rotenc.service \
    /lib/systemd/system/shellinabox.service \
    /lib/systemd/system/squeezelite.service \
    /lib/systemd/system/localdisplay.service \
    /lib/systemd/system/tmp.mount
    # Set permissions for etc files
    chmod 0644 \
    /etc/bluealsaaplay.conf \
    /etc/machine-info \
    /etc/nftables.conf \
    /etc/squeezelite.conf

    # Update sample playlists
    # NOTE: Updates will be new image only
    #cp -rf $SRC/var/lib/mpd/playlists/* /var/lib/mpd/playlists/ > /dev/null 2>&1

    # --------------------------------------------------------------------------
    # Bring it alive ;-)
    # --------------------------------------------------------------------------
    echo "Moode-player package upgrade finished, please reboot"
}

################################################################################
#
# Main
#
################################################################################
if [ "$ACTION" = "configure" ] && [ -z $VERSION ] || [ "$ACTION" = "abort-remove" ]
then
    # --------------------------------------------------------------------------
    # Perform installation (no prior install exists)
    # --------------------------------------------------------------------------
    on_install
elif [ "$ACTION" = "configure" ] && [ -n $VERSION ]
then
    # --------------------------------------------------------------------------
    # Perform upgrade (prior install exists)
    # --------------------------------------------------------------------------
    on_upgrade
elif echo "${ACTION}" | grep -E -q "(abort|fail)"
then
    echo "Failed to install before the post-installation script was run." >&2
    exit 1
fi
