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
PHP_VER="8.2"
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

    echo "** Set permissions for service files"
    chmod 0644 \
    /etc/systemd/system/bluealsa-aplay@.service \
    /etc/systemd/system/bt-agent.service \
    /etc/systemd/system/plexamp.service \
    /etc/udev/rules.d/10-a2dp-autoconnect.rules \
    /lib/systemd/system/rotenc.service \
    /lib/systemd/system/shellinabox.service \
    /lib/systemd/system/squeezelite.service \
    /lib/systemd/system/localdisplay.service
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
    # Release 9 series (Bookworm)
    # --------------------------------------------------------------------------
    # Introduced in r901
    dpkg --compare-versions $VERSION lt "9.0.1-1moode1"
    if [ $? -eq 0 ]; then
        # Fix GPIO buttons
        # - Fix value of 'pull' column
        sqlite3 $SQLDB "UPDATE cfg_gpio set pull='22' WHERE pull='GPIO.PUD_UP'"
        sqlite3 $SQLDB "UPDATE cfg_gpio set pull='21' WHERE pull='GPIO.PUD_DOWN'"
        # - Fix nulls, convert to ''
        sqlite3 $SQLDB "UPDATE cfg_gpio set pin='' WHERE pin IS NULL"
        sqlite3 $SQLDB "UPDATE cfg_gpio set enabled='' WHERE enabled IS NULL"
        sqlite3 $SQLDB "UPDATE cfg_gpio set pull='' WHERE pull IS NULL"
        sqlite3 $SQLDB "UPDATE cfg_gpio set command='' WHERE command IS NULL"
        sqlite3 $SQLDB "UPDATE cfg_gpio set param='' WHERE param IS NULL"
        sqlite3 $SQLDB "UPDATE cfg_gpio set value='' WHERE value IS NULL"
        # One touch options for ralbum
        sqlite3 $SQLDB "UPDATE cfg_system set param='library_onetouch_ralbum', value='No action' where param='RESERVED_142'"
        # Fix permissions for rotenc service
        chmod 0644 /lib/systemd/system/rotenc.service
    fi

    # Introduced in r902
    dpkg --compare-versions $VERSION lt "9.0.2-1moode1"
    if [ $? -eq 0 ]; then
        # Add plumbing for Plexamp renderer
        sqlite3 $SQLDB "UPDATE cfg_system SET param='paactive', value='0' WHERE param='RESERVED_13'"
        sqlite3 $SQLDB "UPDATE cfg_system SET param='pasvc', value='0' WHERE param='RESERVED_64'"
        sqlite3 $SQLDB "UPDATE cfg_system SET param='rsmafterpa', value='No' WHERE param='RESERVED_115'"
        # Default cover images
        rm /var/www/images/default-cover-v6*
        rm /var/www/images/notfound.jpg
        rm /var/www/images/pldefault.jpg
        # Pi 7inch touch display
        # - Remove square pixels lines (no solution with KMS driver)
        sed -i -e '/Square pixels/d' \
            -e '/framebuffer_width/d' \
            -e '/framebuffer_height/d' \
            -e '/framebuffer_aspect/d' \
            -e '/lcd_rotate/d' \
            /boot/firmware/config.txt
        # - Add support for backlight and 180 deg screen rotate
        sed -i '/dtparam=pciex1_gen=3/a # Pi Touch\ndtoverlay=rpi-backlight\n#dtoverlay=vc4-kms-dsi-7inch,invx,invy' /boot/firmware/config.txt
    fi

    # Introduced in r903
    dpkg --compare-versions $VERSION lt "9.0.3-1moode1"
    if [ $? -eq 0 ]; then
        # Update Hifiberry overlay names
        sqlite3 $SQLDB "UPDATE cfg_audiodev SET driver='hifiberry-dacplus-std' WHERE name='HiFiBerry Amp2/4'"
        sqlite3 $SQLDB "UPDATE cfg_audiodev SET driver='hifiberry-dacplus-std' WHERE name='HiFiBerry DAC+'"
        sqlite3 $SQLDB "UPDATE cfg_audiodev SET driver='hifiberry-dacplus-pro' WHERE name='HiFiBerry DAC+ Pro'"
        # Remove usb_auto_updatedb
        sqlite3 $SQLDB "UPDATE cfg_system SET param='RESERVED_108', value='' WHERE param='usb_auto_updatedb'"
    fi

    # Introduced in r904
    dpkg --compare-versions $VERSION lt "9.0.4-1moode1"
    if [ $? -eq 0 ]; then
        # Remove old Setup Guide
        rm /var/www/setup.txt
        # Enable 200MB swapfile
        systemctl enable dphys-swapfile
        sed -i "s/^CONF_SWAPSIZE.*/CONF_SWAPSIZE=200/" /etc/dphys-swapfile
    fi

    # Introduced in r905
    dpkg --compare-versions $VERSION lt "9.0.5-1moode1"
    if [ $? -eq 0 ]; then
        # Fix permissions on localui.service
        chmod 0644 /lib/systemd/system/localui.service
        # NVMe drive support
        # - Create mount dir
        [ ! -e /mnt/NVME ] && mkdir /mnt/NVME
        # - Add [NVMe] block to smb.conf
        sed -i "/Playlists/i[NVMe]\ncomment = NVMe Storage\npath = /mnt/NVME\nread only = No\nguest ok = Yes" /etc/samba/smb.conf
        # - Remove old NFS symlink
        systemctl stop nfs-kernel-server
        rm -f /srv/nfs
        # - Create new NFS symlinks
        [ ! -e /srv/nfs ] && mkdir /srv/nfs
        [ ! -e /srv/nfs/usb ] && ln -s /media /srv/nfs/usb
        [ ! -e /srv/nfs/nvme ] && ln -s /mnt/NVME /srv/nfs/nvme
        # - Create new MPD symlink
        [ ! -e /var/lib/mpd/music/NVME ] &&  ln -s /mnt/NVME /var/lib/mpd/music/NVME
        # Update rpi-backlight
        LOCALUI=$(sqlite3 $SQLDB "SELECT value from cfg_system WHERE param='localui'")
        if [ "$LOCALUI" = "0" ]; then
            sed -i /rpi-backlight/c\#dtoverlay=rpi-backlight /boot/firmware/config.txt
        fi
    fi

    # Introduced in r906
    dpkg --compare-versions $VERSION lt "9.0.6-1moode1"
    if [ $? -eq 0 ]; then
        # Remove ttf font file, its replaced by a woff file
        rm -f /var/www/fonts/Lato-Thin.ttf
        # Replace fbset with kmsprint for auto screensize
        HOME_DIR=$(moodeutl -d -gv home_dir)
        sed -i -e "s/SCREENSIZE=.*/SCREENSIZE=$\(kmsprint | awk '\$1 == \"FB\" {print \$3}' | awk -F\"x\" '{print \$1\",\"\$2}'\)/" $HOME_DIR/.xinitrc
    fi

    # Introduced in r907
    dpkg --compare-versions $VERSION lt "9.0.7-1moode1"
    if [ $? -eq 0 ]; then
        # Replace NPO Radio 4 with NPO Klassiek
        # - Handled by moode-player package
        # Convert ; to , delimiter in param 'camilladsp_quickconv'
        sqlite3 $SQLDB "UPDATE cfg_system SET value=replace(value, ';', ',') WHERE param='camilladsp_quickconv'"
    fi

    # Introduced in r908
    dpkg --compare-versions $VERSION lt "9.0.8-1moode1"
    if [ $? -eq 0 ]; then
        # Add debuglog param to cfg_system
        sqlite3 $SQLDB "UPDATE cfg_system SET param='debuglog', value='0' WHERE param='RESERVED_108'"
        # Add Pi2Design devices
        sqlite3 $SQLDB "DELETE FROM cfg_audiodev";
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | sqlite3 $SQLDB
    fi

    # Introduced in r910
    dpkg --compare-versions $VERSION lt "9.1.0-1moode1"
    if [ $? -eq 0 ]; then
        # Add IanCanada and Hifiberry DAC8x devices
        sqlite3 $SQLDB "DELETE FROM cfg_audiodev";
        cat $SQLDB".sql" | grep "INSERT INTO cfg_audiodev" | sqlite3 $SQLDB
        # In param 'camilladsp_quickconv' convert ; to , delimiter and remove leading or trailing single quotes
        sqlite3 $SQLDB "UPDATE cfg_system SET value=replace(value, ';', ',') WHERE param='camilladsp_quickconv'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value=replace(value, '''', '') WHERE param='camilladsp_quickconv'"
        # Add ap_fallback param to cfg_spotify
        cat $SQLDB".sql" | grep "INSERT INTO cfg_spotify" | grep "ap_fallback"  | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        # Update min initial-volume in cfg_spotify
        sqlite3 $SQLDB "UPDATE cfg_spotify SET value='5' WHERE param='initial_volume' AND value='0'"
        # Replace radio station 200px thumbs with native resolution main images
        cp "/var/local/www/imagesw/radio-logos/*.jpg" "/var/local/www/imagesw/radio-logos/thumbs/"
    fi

    # Introduced in r912
    dpkg --compare-versions $VERSION lt "9.1.2-1moode1"
    if [ $? -eq 0 ]; then
        # Remove FluxFM Hard Rock station (discontinued)
        # - Handled by moode-player package
        # Log2ram
        # - Enable cron
        systemctl enable cron
        # - Add A (preserve ACL's) to rsync options
        # - Note: Remove this prior to release if new version log2ram includes the patch
        sed -i "s/rsync -aXv/rsync -AaXv/" /usr/local/bin/log2ram
        # Remove Prefs adaptive coloring (not used, bugs)
        sqlite3 $SQLDB "UPDATE cfg_system SET param='RESERVED_91', value='' WHERE param='adaptive'"
        # Migrate rx_hostnames and rx_addresses session-only vars to SQL/Session
        RX_HOSTS=$(moodeutl -d -gv rx_hostnames)
        RX_ADDRS=$(moodeutl -d -gv rx_addresses)
        if [ -z $RX_HOSTS ]; then RX_HOSTS="-1"; fi
        if [ -z $RX_ADDRS ]; then RX_ADDRS="-1"; fi
        sqlite3 $SQLDB "UPDATE cfg_system SET param='rx_hostnames', value='$RX_HOSTS' WHERE param='usb_volknob'"
        sqlite3 $SQLDB "UPDATE cfg_system SET param='rx_addresses', value='$RX_ADDRS' WHERE param='led_state'"
    fi

    # Introduced in r913
    dpkg --compare-versions $VERSION lt "9.1.3-1moode1"
    if [ $? -eq 0 ]; then
        # Update Opus frame size default to 20ms (960) from 10ms (480)
        sqlite3 $SQLDB  "UPDATE cfg_multiroom SET value='960' WHERE param='tx_frame_size' AND value='480'"
        sqlite3 $SQLDB  "UPDATE cfg_multiroom SET value='960' WHERE param='rx_frame_size' AND value='480'"
        # Comment out rpi-backlight overlay since its now an option in per-config
        sed -i "s/^dtoverlay=rpi-backlight/#dtoverlay=rpi-backlight/" /boot/firmware/config.txt
        # Update log2ram memory size (reduce from default 128M to 32M)
        sed -i "s/^SIZE=.*/SIZE=32M/" /etc/log2ram.conf
        # Screen saver when playing
        sqlite3 $SQLDB "UPDATE cfg_system SET param='scnsaver_whenplaying', value='No' WHERE param='RESERVED_91'"
        # Librespot 5 AP fallback
        sqlite3 $SQLDB "UPDATE cfg_spotify SET value='No' WHERE param='ap_fallback'"
    fi

    # Introduced in r914
    dpkg --compare-versions $VERSION lt "9.1.4-1moode1"
    if [ $? -eq 0 ]; then
        # Reset first use help to show the Welcome notification
        sqlite3 $SQLDB "UPDATE cfg_system SET value='y,y' WHERE param='first_use_help'"
    fi

    # Introduced in r915
    dpkg --compare-versions $VERSION lt "9.1.5-1moode1"
    if [ $? -eq 0 ]; then
        # Local display refactor
        # - SQL/session vars
        sqlite3 $SQLDB "UPDATE cfg_system SET value='landscape', param='hdmi_scn_orient' WHERE param='timezone'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value='0', param='local_display' WHERE param='localui'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value='', param='RESERVED_84' WHERE param='touchscn'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value='', param='RESERVED_85' WHERE param='scnblank'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value='none', param='dsi_scn_type' WHERE param='scnrotate'"
        sqlite3 $SQLDB "UPDATE cfg_system SET value='0', param='dsi_scn_rotate' WHERE param='scnbrightness'"
        # Config.txt
        # - Improve comment
        sed -i s/Touch/Touch1/ /boot/firmware/config.txt
        # - Fan speed control
        sed -i -e "s/vc4-kms-dsi-7inch,invx,invy/vc4-kms-dsi-7inch,invx,invy\n# Fan speed\n#dtparam=fan_temp0=50000,fan_temp0_hyst=5000,fan_temp0_speed=75/" /boot/firmware/config.txt
        # Smb.conf
        sed -i -e "s/^guest account.*/guest account = root\n#admin users = @users/" /etc/samba/smb.conf
    fi

    # Introduced in r920
    dpkg --compare-versions $VERSION lt "9.2.0-1moode1"
    if [ $? -eq 0 ]; then
        # Deezer Connect
        # - Feature bitmask
        sqlite3 $SQLDB "UPDATE cfg_system SET value='97271' WHERE param='feat_bitmask'"
        # - Cfg_system params
        sqlite3 $SQLDB "UPDATE cfg_system SET param='deezersvc', value='0' WHERE param='RESERVED_84'"
        sqlite3 $SQLDB "UPDATE cfg_system SET param='deezername', value='moOde Deezer' WHERE param='RESERVED_85'"
        sqlite3 $SQLDB "UPDATE cfg_system SET param='rsmafterdeez', value='No' WHERE param='lcdup'"
        sqlite3 $SQLDB "UPDATE cfg_system SET param='deezactive', value='0' WHERE param='eth0chk'"
        # - Cfg_deezer table
        sqlite3 $SQLDB "CREATE TABLE cfg_deezer (id INTEGER PRIMARY KEY, param CHAR (32), value CHAR (32))"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (1, 'normalize_volume', 'No')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (2, 'no_interruptions', 'No')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (3, 'format', 'S16')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (4, 'initial_volume', '5')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (5, 'RESERVED_5', '')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (6, 'RESERVED_6', '')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (7, 'RESERVED_7', '')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (8, 'RESERVED_8', '')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (9, 'email', '')"
        sqlite3 $SQLDB "INSERT INTO cfg_deezer (id, param, value) VALUES (10, 'password', '')"
        # - Credentials:  /etc/deezer/deezer.toml
        # - Event script: /var/local/www/commandw/deezevent.sh
        # Remove orphaned FluxFM files (FluxFM station renamed to FluxFM - Livestream)
        rm "/var/lib/mpd/music/RADIO/FluxFM.pls"
        rm "/var/local/www/imagesw/radio-logos/FluxFM.jpg"
        rm "/var/local/www/imagesw/radio-logos/thumbs/FluxFM.jpg"
        rm "/var/local/www/imagesw/radio-logos/thumbs/FluxFM_sm.jpg"
        # PCIe SATA drive support
        # - Create mount dir
        [ ! -e /mnt/SATA ] && mkdir /mnt/SATA
        # - Add [SATA] block to smb.conf
        sed -i "/Playlists/i[SATA]\ncomment = SATA Storage\npath = /mnt/SATA\nread only = No\nguest ok = Yes" /etc/samba/smb.conf
        # - Add sata symlinks
        [ ! -e /srv/nfs/sata ] && ln -s /mnt/SATA /srv/nfs/sata
        [ ! -e /var/lib/mpd/music/SATA ] &&  ln -s /mnt/SATA /var/lib/mpd/music/SATA
        # - Remove orphaned chrome-updater.sh (renamed to chromium-updater.sh)
        rm /var/www/util/chrome-updater.sh
        # Add rfkill unblock bluetooth to rc.local
        sed -i "s|/usr/sbin/rfkill unblock wifi.*|/usr/sbin/rfkill unblock wifi > /dev/null 2>\&1\n/usr/sbin/rfkill unblock bluetooth > /dev/null 2>\&1|" /etc/rc.local
        # Fix default amixname in cfg_system
        sqlite3 $SQLDB "UPDATE cfg_system SET value='PCM' WHERE param='amixname' AND value='HDMI'"
        # Remove rpi-backlight overlay
        sed -i /rpi-backlight/d /boot/firmware/config.txt
        # Add zeroconf port option to cfg_spotify
        cat $SQLDB".sql" | grep "INSERT INTO cfg_spotify" | grep "zeroconf"  | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        cat $SQLDB".sql" | grep "INSERT INTO cfg_spotify" | grep "zeroconf_port"  | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
    fi

    # Introduced in r921
    dpkg --compare-versions $VERSION lt "9.2.1-1moode1"
    if [ $? -eq 0 ]; then
        echo "No r921 updates needed in postinstall"
    fi

    # Introduced in r922
    dpkg --compare-versions $VERSION lt "9.2.2-1moode1"
    if [ $? -eq 0 ]; then
        # PHP.ini updates
        sed -i -e "s/^post_max_size.*/post_max_size = 128M/" \
            -e "s/^upload_max_filesize.*/upload_max_filesize = 128M/" \
            /etc/php/$PHP_VER/cli/php.ini
        sed -i -e "s/^post_max_size.*/post_max_size = 128M/" \
            -e "s/^upload_max_filesize.*/upload_max_filesize = 128M/" \
            /etc/php/$PHP_VER/fpm/php.ini
        # NGINX.conf updates (client_max_body_size 128M;)
        cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    fi

    # Introduced in r923
    dpkg --compare-versions $VERSION lt "9.2.3-1moode1"
    if [ $? -eq 0 ]; then
        echo "There are no postinstall updates for r923"
    fi

    # Introduced in r924
    dpkg --compare-versions $VERSION lt "9.2.4-1moode1"
    if [ $? -eq 0 ]; then
        # Set camilladsp sample configs plugin to v3
        sqlite3 $SQLDB "UPDATE cfg_plugin SET plugin='v3-sample-configs' WHERE component='camilladsp' AND type='sample-configs'"
        # Truncate players.txt to force discover at Players first launch
        truncate /var/local/www/players.txt --size 0
    fi

    # Introduced in r925
    dpkg --compare-versions $VERSION lt "9.2.5-1moode1"
    if [ $? -eq 0 ]; then
        #echo "There are no postinstall updates for r925"
        # Add disable_synchronization param to cfg_airplay
        cat $SQLDB".sql" | grep "INSERT INTO cfg_airplay" | grep "disable_synchronization"  | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        sed -i -e 's/\/\/[[:space:]]\+\(disable_synchronization\)/\1/' /etc/shairport-sync.conf
    fi

    # Introduced in r926
    dpkg --compare-versions $VERSION lt "9.2.6-1moode1"
    if [ $? -eq 0 ]; then
        #echo "There are no postinstall updates for r926"
        # Add security protocol columns to cfg_network and cfg_ssid
        sqlite3 $SQLDB "ALTER TABLE cfg_network ADD COLUMN wlansec char(15)"
        sqlite3 $SQLDB "ALTER TABLE cfg_ssid ADD COLUMN security char(32)"
        # Set security protocol default to wpa-psk
        sqlite3 $SQLDB "UPDATE cfg_network SET wlansec='wpa-psk' WHERE id='2' OR id='3'"
        sqlite3 $SQLDB "UPDATE cfg_ssid SET security='wpa-psk' WHERE ssid!=''"
    fi

    # Introduced in r927
    dpkg --compare-versions $VERSION lt "9.2.7-1moode1"
    if [ $? -eq 0 ]; then
        #echo "There are no postinstall updates for r927"
        # MPD config updates
        cat $SQLDB".sql" | grep "INSERT INTO cfg_mpd" | grep "close_on_pause"  | sed "s/^INSERT/INSERT OR IGNORE/" | sqlite3 $SQLDB
        sqlite3 $SQLDB "UPDATE cfg_mpd SET value='notice' WHERE param='log_level'"
    fi

    # --------------------------------------------------------------------------
    # Any release
    # --------------------------------------------------------------------------
    # Update SSH header
    cp -f $SRC/etc/update-motd.d/00-moodeos-header /etc/update-motd.d/

    # Update radio stations and logos
    dpkg --compare-versions $VERSION lt "9.1.4-1moode1"
    if [ $? -eq 0 ]; then
        import_stations update "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-update-9.1.4.zip"
    fi
    import_stations update "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-update_$PKG_VERSION.zip"

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
    /lib/systemd/system/localdisplay.service
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
