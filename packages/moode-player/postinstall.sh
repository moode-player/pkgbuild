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

# Version number is set by build process
PKG_VERSION="x.x.x"

SQLDB=/var/local/www/db/moode-sqlite3.db

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
        if [ "$mode" == "full" ]
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
    systemctl disable dphys-swapfile > /dev/null 2>&1
    systemctl disable cron.service > /dev/null 2>&1
    systemctl enable rpcbind > /dev/null 2>&1
    systemctl set-default multi-user.target > /dev/null 2>&1
    systemctl stop apt-daily.timer > /dev/null 2>&1
    systemctl disable apt-daily.timer > /dev/null 2>&1
    systemctl mask apt-daily.timer > /dev/null 2>&1
    systemctl stop apt-daily-upgrade.timer > /dev/null 2>&1
    systemctl disable apt-daily-upgrade.timer > /dev/null 2>&1
    systemctl mask apt-daily-upgrade.timer > /dev/null 2>&1
    systemctl daemon-reload > /dev/null 2>&1

    echo "** Disable certain systemd services"
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

    echo "** Set permissions for service files"
    chmod 0644 \
    /etc/systemd/system/bluealsa-aplay@.service \
    /etc/systemd/system/bluealsa.service \
    /etc/systemd/system/bt-agent.service \
    /etc/udev/rules.d/10-a2dp-autoconnect.rules \
    /lib/systemd/system/rotenc.service \
    /lib/systemd/system/shellinabox.service

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
    [ ! -e /var/lib/mpd/music/SDCARD ] && ln -s /mnt/SDCARD /var/lib/mpd/music/SDCARD
    [ ! -e /var/lib/mpd/music/USB ] && ln -s /media /var/lib/mpd/music/USB
    [ ! -e /srv/nfs ] && ln -s /media /srv/nfs

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
    SRC=/usr/share/moode-player
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
    PHP_VER="8.2"

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
    sed -i -e "s/^post_max_size.*/post_max_size = 50M/" \
        -e "s/^upload_max_filesize.*/upload_max_filesize = 50M/" \
        -e "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" \
        /etc/php/$PHP_VER/cli/php.ini

    # /etc/php/$PHP_VER/fpm/pool.d/www.conf
	# pm.max_children = 64
    sed -i "s/^pm[.]max_children.*/pm.max_children = 64/" /etc/php/$PHP_VER/fpm/pool.d/www.conf

    # /etc/php/$PHP_VER/fpm/php.ini
    # max_execution_time = 300
    # max_input_vars = 10000
    # memory_limit = -1
    # upload_max_filesize = 75M
    # session.save_path = "0;666;/var/local/php"
    sed -i -e "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" \
        -e "s/^max_execution_time.*/max_execution_time = 300/" \
        -e "s/^max_input_time.*/max_input_time = -1/" \
        -e "s/^;max_input_vars.*/max_input_vars = 32768/" \
        -e "s/^memory_limit.*/memory_limit = -1/" \
        -e "s/^post_max_size.*/post_max_size = 75M/" \
        -e "s/^upload_max_filesize.*/upload_max_filesize = 75M/" \
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
# - Make the upgrade patches as fault tolerant as needed
#
################################################################################
function on_upgrade() {
    # Files marked as 'overwrite' in the source tree are stored here
    SRC=/usr/share/moode-player

    # --------------------------------------------------------------------------
    # Release 8 series (Bullseye)
    # --------------------------------------------------------------------------
    # Introduced in r801
    dpkg --compare-versions $VERSION lt "8.0.1-1moode1"
    if [ $? -eq 0 ]
    then
        # Fix missing radio station seperator record with id 499, use "insert or ignore" instead of "insert"
        cat $SQLDB".sql" | grep "INSERT INTO cfg_radio" | grep "(499"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
    fi

    # Introduced in r802
    dpkg --compare-versions $VERSION lt "8.0.2-1moode1"
    if [ $? -eq 0 ]
    then
        # Increase trust timeout for scanned, un-paired devices
        # If it's already been set the command won't have any effect which is what we want
        sed -i -e 's/[#]TemporaryTimeout[ ]=[ ].*/TemporaryTimeout = 90/' /etc/bluetooth/main.conf
    fi

    # Introduced in r810
    dpkg --compare-versions $VERSION lt "8.1.0-1moode1"
    if [ $? -eq 0 ]
    then
        # Add new cfg_system rows
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "library_track_play"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "playlist_pos"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "plview_sort_group"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        # Create new cfg_ssid table and insert configured ssid if any
        sqlite3 $SQLDB "CREATE TABLE IF NOT EXISTS cfg_ssid (id INTEGER PRIMARY KEY, ssid CHAR (32), sec CHAR (32), psk CHAR (32))"
        RESULT=$(sqlite3 $SQLDB "SELECT wlan_psk FROM cfg_network WHERE id='2'")
        if [ -n "$RESULT" ]; then
            sqlite3 $SQLDB "INSERT OR IGNORE INTO cfg_ssid VALUES ('1', '', '', '')"
            sqlite3 $SQLDB "UPDATE cfg_ssid SET ssid = net.wlanssid, sec = net.wlansec, psk = net.wlan_psk FROM (SELECT id, wlanssid, wlansec, wlan_psk FROM cfg_network) AS net WHERE net.id = 2"
        fi
        # Use new subdirs from refactoring
        sed -i -e 's/\/command\/util/\/util\/sysutil/g' /etc/rc.local
        sed -i -e 's/^\/var\/www\/command\/worker.php/\/var\/www\/daemon\/worker.php/' /etc/rc.local
        sed -i -e 's/\/command\/util/\/util\/sysutil/g' /etc/udisks-glue.conf
        # Remove UPnP browser (djmount)
        sqlite3 $SQLDB "UPDATE cfg_system SET param='RESERVED_47', value='' WHERE param='upnp_browser'"
        # - TODO: apt purge djmount? There will be a dependency between djmount and moode-player package.
        # - TODO: rmdir /mnt/UPNP? What if user has an existing UPnP mount?
    fi

    # Introduced in r812
    dpkg --compare-versions $VERSION lt "8.1.2-1moode1"
    if [ $? -eq 0 ]
    then
        sed -i -e "s/^;max_input_vars.*/max_input_vars = 32768/" /etc/php/7.4/fpm/php.ini
    fi

    # Introduced in r820
    dpkg --compare-versions $VERSION lt "8.2.0-1moode1"
    if [ $? -eq 0 ]
    then
        # Maintenance interval: Change from 7200 (2 hours) to 21600 (6 hours)
        sqlite3 $SQLDB "UPDATE cfg_system SET value='21600' WHERE param='maint_interval'"
        # Change to GitHub from AWS for hosting software update downloads
        sqlite3 $SQLDB "UPDATE cfg_system SET value='https://raw.githubusercontent.com/moode-player/updates/main/moode-player' WHERE param='res_software_upd_url'"
        # File sharing feature: Add / update cfg_system rows
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "fs_smb"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "fs_nfs"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "fs_nfs_access"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        sqlite3 $SQLDB "UPDATE cfg_system SET param='fs_nfs_options', value='rw,sync,no_subtree_check,no_root_squash' WHERE id='47'"
        # Native lazyload option: Add cfg_system row
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "native_lazyload"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        # Playlist one-touch option: Add cfg_system row
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "library_onetouch_pl"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        # Screen saver mode and layout
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "scnsaver_mode"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "scnsaver_layout"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
        # NFS server feature:
        # - Create symlink
        [ ! -e /srv/nfs ] && ln -s /media /srv/nfs
        # - Update name of automount script
        sed -i -e "s/sysutil.sh smbadd/automount.sh add_mount_udisks/" /etc/udisks-glue.conf
        sed -i -e "s/sysutil.sh smbrem/automount.sh remove_mount_udisks/" /etc/udisks-glue.conf
        sed -i -e "s/sysutil.sh smb_add/automount.sh add_mount_devmon/" /etc/rc.local
        sed -i -e "s/sysutil.sh smb_remove/automount.sh remove_mount_devmon/" /etc/rc.local
        # - Disable service
        systemctl disable nfs-server.service
        # SMB server feature
        systemctl disable smbd.service
        systemctl disable nmbd.service
        # AP Router mode: Add column wlan_router to cfg_network
        RESULT=$(sqlite3 $SQLDB "SELECT wlan_router FROM cfg_network")
        if [ -z "$RESULT" ]; then
            sqlite3 $SQLDB "ALTER TABLE cfg_network ADD COLUMN wlan_router CHAR(32) default 'Off'"
        fi
    fi

    # Introduced in r821
    dpkg --compare-versions $VERSION lt "8.2.1-1moode1"
    if [ $? -eq 0 ]
    then
        # Receiver Master volume opt-in change default to 1 (Yes)
        sqlite3 $SQLDB "UPDATE cfg_multiroom SET value='1' WHERE param='rx_mastervol_opt_in'"
        # Maintenance interval
        sqlite3 $SQLDB "UPDATE cfg_system SET value='21600' WHERE param='maint_interval'"
        # CoverView extra metadata for wide mode
        cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "scnsaver_xmeta"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB
    fi

    # Introduced in r822
    dpkg --compare-versions $VERSION lt "8.2.2-1moode1"
    if [ $? -eq 0 ]
    then
        # Bump pm.max_children. Refer to watchdog.sh for use of pm_max_children value in monitoring/reducing fpm pool
        PHP_VER="7.4"
        sed -i "s/^pm[.]max_children.*/pm.max_children = 64/" /etc/php/$PHP_VER/fpm/pool.d/www.conf
        # Start/stop nqptp on-demand
        systemctl disable nqptp
    fi

    # Introduced in r823
    dpkg --compare-versions $VERSION lt "8.2.3-1moode1"
    if [ $? -eq 0 ]
    then
        # Update Default Playlist with new URL for BBC Radio 1
        sed -i "s|http://stream.live.vc.bbcmedia.co.uk/bbc_radio_one|http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_low/ak/bbc_radio_one.m3u8|" /var/lib/mpd/playlists/Default\ Playlist.m3u
        # HTTPS-Only feature (initially not enabled)
        sqlite3 $SQLDB "UPDATE cfg_system SET value='97206' WHERE param='feat_bitmask'"
        # Remove Bluetooth speaker sharing param 'btmulti' (obsolete)
        sqlite3 $SQLDB "UPDATE cfg_system SET param='RESERVED_80', value='' WHERE id='80'"
    fi

    # Introduced in r824
    dpkg --compare-versions $VERSION lt "8.2.4-1moode1"
    if [ $? -eq 0 ]
    then
        # Remove broken line in shairport-sync.conf
        sed -i "/audio_backend_buffer_desired_length_in_seconds'/d" /etc/shairport-sync.conf
        # Remove unneeded conf that was part of obsolete Bluetooth speaker sharing option
        rm /etc/alsa/conf.d/20-bluealsa-dmix.conf
    fi

    # Introduced in r825
    dpkg --compare-versions $VERSION lt "8.2.5-1moode1"
    if [ $? -eq 0 ]
    then
        # Pam sudo (part of preventing spam in auth.log)
        cp -f $SRC/etc/pam.d/sudo /etc/pam.d/sudo
        # Multiroom new buffer defaults
        sqlite3 $SQLDB "UPDATE cfg_multiroom SET value='128' where param='tx_bfr'"
        sqlite3 $SQLDB "UPDATE cfg_multiroom SET value='128' where param='rx_bfr'"
        sqlite3 $SQLDB "UPDATE cfg_multiroom SET value='64' where param='rx_jitter_bfr'"
        # For restructured NGINX config
        cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf
        if [ -f /etc/nginx/sites-enabled/default ]
        then
            rm -f /etc/nginx/sites-enabled/default
            sudo ln -s /etc/nginx/sites-available/moode-http.conf /etc/nginx/sites-enabled/moode-http.conf
        fi
        # Update permissions for pam and sudoers drop files
        chmod 0644 /etc/pam.d/sudo
        chmod 0440 /etc/sudoers.d/010_moode
        chmod 0440 /etc/sudoers.d/010_www-data-nopasswd
        # Change toggle_coverview to auto_coverview to reflect actual usage
        sqlite3 $SQLDB "UPDATE cfg_system SET param='auto_coverview'WHERE id='163'"
    fi

    # Introduced in r830
    dpkg --compare-versions $VERSION lt "8.3.0-1moode1"
    if [ $? -eq 0 ]
    then
        # MPD 2 CamillaDSP volume sync
        systemctl stop mpd2cdspvolume
        systemctl disable mpd2cdspvolume
        sqlite3 $SQLDB "UPDATE cfg_system SET param='camilladsp_volume_sync', value='off' WHERE id=80"
        cp -f $SRC/etc/alsa/conf.d/camilladsp.conf /etc/alsa/conf.d/
        chown -R mpd /var/lib/cdsp
        echo "0 0" > /var/lib/cdsp/camilladsp_volume_state
        chown -R mpd /var/lib/cdsp/camilladsp_volume_state
        # Piano 2.1 status command
        cp -f $SRC/home/piano.sh $HOME
        # MPD cfg_mpd default period_time (not used but just for the sake of accuracy)
        sqlite3 $SQLDB "UPDATE cfg_mpd SET value='125000' WHERE param='period_time'"
        # ProtoDAC TDA1387 X8
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | grep "ProtoDAC TDA1387 X8" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        # URL for downloadable plugins
        sqlite3 $SQLDB "UPDATE cfg_system SET param='res_plugins_url', value='https://raw.githubusercontent.com/moode-player/plugins/main' WHERE id='16'"
        # Free up cfg_system param
        sqlite3 $SQLDB "UPDATE cfg_system SET param='RESERVED_127', value='Was kernel_architecture' WHERE id='127'"
    fi

    # Introduced in r831
    dpkg --compare-versions $VERSION lt "8.3.1-1moode1"
    if [ $? -eq 0 ]
    then
        # Update overlay name rpi-dac to i2s-dac
        sqlite3 $SQLDB "UPDATE cfg_audiodev SET driver='i2s-dac' WHERE driver='rpi-dac'"
        # Update Generic-1 and 2 I2S DAC entries
        sqlite3 $SQLDB "UPDATE cfg_audiodev SET name='Generic-2 I2S (i2s-dac)', dacchip='Passive I2S DAC' WHERE name='Generic-2 I2S (rpi-dac)'"
        sqlite3 $SQLDB "UPDATE cfg_audiodev SET dacchip='Passive I2S DAC' WHERE name='Generic-1 I2S (hifiberry-dac)'"
        # Add Raspberry Pi branded I2S overlays
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | grep "Raspberry Pi Codec Zero" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | grep "Raspberry Pi DAC+" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | grep "Raspberry Pi DAC Pro" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | grep "Raspberry Pi DigiAMP+" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        # Remove old GPIO pinout image
        rm -f /var/www/images/gpio-pins.png > /dev/null 2>&1
        # Update logfile path from /home/userid to /var/log
        sed -i "s|$HOME/katana.log|/var/log/moode_katana.log|" /etc/rc.local
        # Move log files to new location
        mv "$HOME/katana.log" /var/log/moode_katana.log > /dev/null 2>&1
        mv "$HOME/autocfg.log" /var/log/moode_autocfg.log > /dev/null 2>&1
        mv /var/log/mountmon.log /var/log/moode_mountmon.log > /dev/null 2>&1
        mv /var/local/www/playhistory.log /var/log/moode_playhistory.log > /dev/null 2>&1
        mv /var/local/www/bootcfg.bkp /boot/bootcfg.bkp > /dev/null 2>&1
        # Update Default Playlist with new URL's for 2BOB and Czech Radio Classic
        sed -i "s|http://eno.emit.com:8000/2bob_live_64.mp3|https://21363.live.streamtheworld.com/2BOB.mp3|" /var/lib/mpd/playlists/Default\ Playlist.m3u
        sed -i "s|http://icecast6.play.cz/croddur-256.mp3|https://rozhlas.stream/ddur_mp3_256.mp3|" /var/lib/mpd/playlists/Default\ Playlist.m3u
        # Remove volume filter from loudness.yml
        sed -i '/Volume:/,/type: Volume/d' /usr/share/camilladsp/configs/loudness.yml
        sed -i '/- Volume/d' /usr/share/camilladsp/configs/loudness.yml
    fi

    # Introduced in r832
    dpkg --compare-versions $VERSION lt "8.3.2-1moode1"
    if [ $? -eq 0 ]
    then
        # Add drop file to haveged to prevent service fail on arm6
        mkdir /etc/systemd/system/haveged.service.d/ > /dev/null 2>&1
        echo -e '[Service]\nSystemCallFilter=uname' | sudo tee /etc/systemd/system/haveged.service.d/syscall.conf > /dev/null
    fi

    # Introduced in r833
    dpkg --compare-versions $VERSION lt "8.3.3-1moode1"
    if [ $? -eq 0 ]
    then
        # Add thumbgen scan option to control which formats are scanned by list-songfiles.sh
        sqlite3 $SQLDB "UPDATE cfg_system SET param='library_thmgen_scan', value='Default' WHERE id='127'"
        # Remove workaround for Allo Katana driver load from rc.local (not working on kernel 6.1.y branch)
        # Load always fails with DMESG "allo-katana-codec 1-0030: Failed to read Chip or wrong Chip id: 0"
        cp -f $SRC/etc/rc.local /etc/
        # Disable bluealsa-aplay service
        systemctl disable bluealsa-aplay
        # Update bluealsa.service with -c aptx -c aptx-hd -c ldac
        cp -f $SRC/etc/systemd/system/bluealsa.service /etc/systemd/system
    fi

    # Introduced in r834
    dpkg --compare-versions $VERSION lt "8.3.4-1moode1"
    if [ $? -eq 0 ]
    then
        # Update bluealsaaplay.conf to use AUDIODEV=_audioout.conf
        sed -i 's/^AUDIODEV=.*/AUDIODEV=_audioout.conf/' /etc/bluealsaaplay.conf
        # Add SBC CODEC quality mode --sbc-quality=xq+ to bluealsa.service
        cp -f $SRC/etc/systemd/system/bluealsa.service /etc/systemd/system/
        # Add user nobody to the audio group so triggerhappy daemon can execute amixer cmd in vol.sh
        usermod -a -G audio nobody
    fi

    # Introduced in r835
    dpkg --compare-versions $VERSION lt "8.3.5-1moode1"
    if [ $? -eq 0 ]
    then
        # No updates required
        :
    fi

    # Introduced in r836
    dpkg --compare-versions $VERSION lt "8.3.6-1moode1"
    if [ $? -eq 0 ]
    then
        # No updates required
        :
    fi

    # Introduced in r837
    dpkg --compare-versions $VERSION lt "8.3.7-1moode1"
    if [ $? -eq 0 ]
    then
        # Reset options to new defaults
        sqlite3 $SQLDB "UPDATE cfg_system SET value='Waveform' WHERE param='show_npicon'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value='Genre' WHERE param='library_tagview_genre'"
        # Update hostapd.conf (remove PSK)
        cp -f $SRC/etc/hostapd/hostapd.conf /etc/hostapd/
        # Add ProtoDAC entry for FifoPiMa reclocker
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | grep "ProtoDAC TDA1387 X8 (FifoPiMa)" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        # Establish 'monitor' column in cfg_radio
        RESULT=$(sqlite3 $SQLDB "SELECT monitor FROM cfg_radio")
        if [ -z "$RESULT" ]; then
            sqlite3 $SQLDB "ALTER TABLE cfg_radio RENAME COLUMN 'reserved2' TO 'monitor'"
            sqlite3 $SQLDB "UPDATE cfg_radio SET monitor='No' WHERE id !='499'"
        fi
        # Set default for Qobuz quality param
        sqlite3 $SQLDB "UPDATE cfg_upnp SET value='6' WHERE param='qobuzformatid'"
    fi

    # Introduced in r838
    dpkg --compare-versions $VERSION lt "8.3.8-1moode1"
    if [ $? -eq 0 ]
    then
        # MPD HTTP proxy: proxy, proxy_user, proxy_password
        cat $SQLDB".sql" | grep "INSERT INTO cfg_mpd" | grep "proxy" | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        # Folder item position
        sqlite3 $SQLDB "UPDATE cfg_system SET param='folder_pos', value='-1' WHERE id='44'"
        # - Update feature bitmask (FEAT_HTTPS = 1)
        BITMASK=$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='feat_bitmask'")
        NEW_BITMASK=$(($BITMASK + 1))
        sqlite3 $SQLDB "UPDATE cfg_system SET value='$NEW_BITMASK' WHERE param='feat_bitmask'"
        # Squeezelite audio device
        sqlite3 $SQLDB "UPDATE cfg_sl SET value='_audioout' WHERE param='AUDIODEVICE'"
        # Set volknob_mpd to -1 (Default initial value)
        sqlite3 $SQLDB "UPDATE cfg_system SET value='-1' WHERE param='volknob_mpd'"
        # Remove old log files
        rm -f /var/log/shairport-sync.log
        rm -f /var/log/librespot.log
        # Plugins repo url
        sqlite3 $SQLDB "UPDATE cfg_system SET param='res_plugin_upd_url', value='https://raw.githubusercontent.com/moode-player/plugins/main' WHERE id='16'"
        # Update bitrate for San Diego Jazz 88.3
        sqlite3 $SQLDB "UPDATE cfg_radio SET bitrate='128' WHERE name='San Diego Jazz 88.3'"
    fi

    # Introduced in r839
    dpkg --compare-versions $VERSION lt "8.3.9-1moode1"
    if [ $? -eq 0 ]
    then
        # Version 2 camilladsp.conf file
        cp -f $SRC/etc/alsa/conf.d/camilladsp.conf /etc/alsa/conf.d/
    fi

    # --------------------------------------------------------------------------
    # Release 9 series (Bookworm)
    # --------------------------------------------------------------------------
    # Introduced in r9.x.y
    dpkg --compare-versions $VERSION lt "9.x.y-1moode1"
    if [ $? -eq 0 ]; then
        # Code goes here
        :
    fi

    # --------------------------------------------------------------------------
    # Any release
    # --------------------------------------------------------------------------

    # Update SSH header
    cp -f $SRC/etc/update-motd.d/00-moodeos-header /etc/update-motd.d/

    # Update radio stations and logos
    import_stations update "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-update_$PKG_VERSION.zip"

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
