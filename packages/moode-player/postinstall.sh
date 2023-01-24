#!/bin/bash
#########################################################################
#
# Script for post processing afer moode-player package installation
#
# (C) bitkeeper 2022 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

ACTION=$1
VERSION=$2

# Version number is set by build process
PKG_VERSION="x.x.x"

SQLDB=/var/local/www/db/moode-sqlite3.db

#TODO: support mode [full|update], required when the first update needs to be created
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
      wget --no-verbose -O $TMP_STATIONS_BACKUP $MOODE_STATIONS_URL || true
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

function on_install() {
      # perform install

      echo "** Basic optimizations"
      dphys-swapfile swapoff
      dphys-swapfile uninstall
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

      echo "** Systemd enable/disable"
      systemctl daemon-reload > /dev/null 2>&1
      systemctl enable haveged > /dev/null 2>&1
      systemctl unmask hostapd > /dev/null 2>&1
      # These services are started on-demand or by moOde worker daemon (worker.php)
      disable_services=(
          bluetooth \
          bluez-alsa \
          dnsmasq \
          hciuart \
          hostapd \
          minidlna \
          mpd \
          mpd.service \
          mpd.socket \
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

      echo "** Create MPD runtime environment"
      touch /var/lib/mpd/state

      echo "** Set permissions for D-Bus (for bluez-alsa)"
      usermod -a -G audio mpd

      echo "** Create symlinks"
      [ ! -e /var/lib/mpd/music/NAS ] &&  ln -s /mnt/NAS /var/lib/mpd/music/NAS
      [ ! -e /var/lib/mpd/music/SDCARD ] && ln -s /mnt/SDCARD /var/lib/mpd/music/SDCARD
      [ ! -e /var/lib/mpd/music/USB ] && ln -s /media /var/lib/mpd/music/USB
      [ ! -e /srv/nfs ] && ln -s /media /srv/nfs


      echo "** Create logfiles"
      touch /var/log/moode.log
      chmod 0666 /var/log/moode.log
      touch /var/log/php_errors.log
      chmod 0666 /var/log/php_errors.log

      chmod 0755 /home/pi/*.sh

      echo "** Reset permissions"
      chmod -R 0755 /var/www
      chmod -R 0755 /var/local/www
      chmod -R 0777 /var/local/www/db
      chmod -R ug-s /var/local/www

      chmod -R a+rw /usr/share/camilladsp

      echo "** Create database"
      if [ -f $SQLDB ]
      then
        rm $SQLDB
      fi
      # strip creation of radion stations from the sql, stations are create by the station backup import
      cat $SQLDB".sql" | grep -v "INSERT INTO cfg_radio" | sqlite3 $SQLDB
      cat $SQLDB".sql" | grep "INSERT INTO cfg_radio" | grep "(499" | sqlite3 $SQLDB

      # Set to Carrot for moOde 8 series
      sqlite3 $SQLDB "UPDATE cfg_system SET value='Carrot' WHERE param='accent_color'"

      import_stations full "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-full_$PKG_VERSION.zip"

      LIBCACHE_BASE="/var/local/www/libcache"
      echo "** Initial permissions for certain files. These also get set during moOde Worker startup"
      touch /var/local/www/playhistory.log
      touch /var/local/www/currentsong.txt
      chmod 0777 /var/local/www/playhistory.log
      chmod 0777 /var/local/www/currentsong.txt

      echo "** Establish permissions"
      chmod -R 0777 /var/local/www/db
      chown www-data:www-data /var/local/php

      echo "** Generate alsaequal binary"
      mkdir -p /opt/alsaequal/
      amixer -D alsaequal > /dev/null
      chmod 0755 /opt/alsaequal/alsaequal.bin
      chown mpd:audio /opt/alsaequal//alsaequal.bin

      echo "** Misc deletes"
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

      echo "** Setup config files"
      # ------------------------------------------------------------------------------------------
      # Overwrite files not owned by moode-player (a prob owned by other packages)
      # ------------------------------------------------------------------------------------------
      SRC=/usr/share/moode-player
      cp -rf $SRC/etc/* /etc/
      cp -rf $SRC/lib/* /lib/ > /dev/null 2>&1
      cp -rf $SRC/usr/* /usr/ > /dev/null 2>&1
      cp -rf $SRC/boot/* /boot/ > /dev/null 2>&1


      # ------------------------------------------------------------------------------------------
      # Patch files with sed
      # ------------------------------------------------------------------------------------------
      # From the root moode git repo find files to patch with sed:
      #  find . -name "*.sed*" |sort
      PHP_VER="7.4"

      # /etc/bluetooth/main.conf
		  # Name = Moode Bluetooth
		  # Class = 0x20041C
          #   2  = Service Class: Audio
          #   4  = Major Device Class: Audio/Video
          #   1C = Minor Device Class: Loudspeaker x14 & Headphones  x18
		  # DiscoverableTimeout = 0
          #   Stay discoverable forever
		  # ControllerMode = dual
          #   Both BR/EDR and LE transports enabled (when supported by the HW)
          # TemporaryTimeout = 90
          #   How long to keep temporary devices around
      sed -i -e 's/[#]Name[ ]=[ ].*/Name = Moode Bluetooth/' \
             -e 's/[#]Class[ ]=[ ].*/Class = 0x20041C/' \
             -e 's/#DiscoverableTimeout[ ]/DiscoverableTimeout /' \
             -e 's/[#]ControllerMode[ ]=[ ].*/ControllerMode = dual/' \
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

      # /etc/dnsmasq.conf
      # interface=wlan0      # Use interface wlan0
      # bind-interfaces      # Bind to the interface to make sure we aren't sending things elsewhere
      # server=127.0.0.1     # Forward DNS requests to self
      # domain-needed        # Don't forward short names
      # bogus-priv           # Never forward addresses in the non-routed address spaces.
      # dhcp-range=172.24.1.50,172.24.1.150,12h # IP address range and lease time
      sed -i -e 's/^[#]bind-interfaces$/bind-interfaces/' \
             -e 's/^[#]interface=$/interface=wlan0/' \
             -e '0,/^#server/s/#server=.*/server=127.0.0.1/' \
             -e 's/^[#]domain-needed$/domain-needed/' \
             -e 's/^[#]bogus-priv$/bogus-priv/' \
             -e '0,/^[#]dhcp-range=.*$/s/^[#]dhcp-range=.*/dhcp-range=172.24.1.50,172.24.1.150,12h/' \
             /etc/dnsmasq.conf

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
      sed -i "s/^allowed_users.*/allowed_users=anybody/" /etc/X11/Xwrapper.config

      # /etc/systemd/journald.conf
      # SystemMaxUse=20M
      # RuntimeMaxUse=20M
      sed -i -e "s/^#SystemMaxUse.*/SystemMaxUse=20M/" \
             -e "s/^#RuntimeMaxUse.*/RuntimeMaxUse=20M/" \
             /etc/systemd/journald.conf

      # NGINX
      cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf
      rm -f /etc/nginx/sites-enabled/*
      sudo ln -s /etc/nginx/sites-available/moode-http.conf /etc/nginx/sites-enabled/moode-http.conf

      # MPD
      touch /etc/mpd.conf
      chown mpd:audio /etc/mpd.conf
      chmod 0666 /etc/mpd.conf

      # in case any changes are made to systemd file reload config
      systemctl daemon-reload

      sync

      #--------------------------------------------------------------------------------------------------------
      # bring it alive ;-)
      #--------------------------------------------------------------------------------------------------------
      #echo "** Starting servers"
      # restart some services to pickup new configuration
      # systemctl stop nginx
      # systemctl restart php7.4-fpm
      # systemctl start nginx
      # systemctl restart smbd
      # systemctl restart nmbd
      # systemctl restart winbind

      #TODO: make this a systemd service
      # /usr/bin/udisks-glue --config=/etc/udisks-glue.conf > /dev/null 2>&1
      # systemctl restart udisks-glue

      #don't now why there is a empty database dir instead of a database file
      if [ -d /var/lib/mpd/database ]
      then
        rmdir -rf /var/lib/mpd/database
      fi

      # On boot set default playlist and output 1
      # NOTE: Moved to worker.php for r810 release
#cat > /etc/runonce.d/moode_first_boot <<EOL
#!/bin/bash
#timeout 30s bash -c 'until mpc status; do sleep 3; done';
#mpc status
#if [[ $? -eq 0 ]]
#then
#  mpc load "Default Playlist"
#  mpc enable only 1
#fi
#EOL

      echo "moode-player install finished, please reboot"
}

function on_upgrade() {
      #--------------------------------------------------------------------------------------------------------
      # Upgrades can come from any version:
      # - Detect if a patch is needed to apply
      # - Make the upgrade patches as fault tolerant as needed
      #--------------------------------------------------------------------------------------------------------

      SRC=/usr/share/moode-player

      # Introduced in r801
      # Fix missing radio station seperator record with id 499, use "insert or ignore" instead of "insert"
      cat $SQLDB".sql" | grep "INSERT INTO cfg_radio" | grep "(499"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB

      # Introduced in r802
      # Increase trust timeout for scanned, un-paired devices
      # If it's already been set the command won't have any effect which is what we want
      sed -i -e 's/[#]TemporaryTimeout[ ]=[ ].*/TemporaryTimeout = 90/' /etc/bluetooth/main.conf

      # Introduced in r810
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

      # Introduced in r812
      sed -i -e "s/^;max_input_vars.*/max_input_vars = 32768/" /etc/php/7.4/fpm/php.ini

      # Introduced in r820
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

      # Introduced in r821
      # Receiver Master volume opt-in change default to 1 (Yes)
      sqlite3 $SQLDB "UPDATE cfg_multiroom SET value='1' WHERE param='rx_mastervol_opt_in'"
      # Maintenance interval
      sqlite3 $SQLDB "UPDATE cfg_system SET value='21600' WHERE param='maint_interval'"
      # CoverView extra metadata for wide mode
      cat $SQLDB".sql" | grep "INSERT INTO cfg_system" | grep "scnsaver_xmeta"  | sed "s/^INSERT/INSERT OR IGNORE/" |  sqlite3 $SQLDB

      # Introduced in r822
	  # Bump pm.max_children. Refer to watchdog.sh for use of pm_max_children value in monitoring/reducing fpm pool
      PHP_VER="7.4"
      sed -i "s/^pm[.]max_children.*/pm.max_children = 64/" /etc/php/$PHP_VER/fpm/pool.d/www.conf
      # Start/stop nqptp on-demand
      systemctl disable nqptp

      # Introduced in r823
      # Update Default Playlist with new URL for BBC Radio 1
      sed -i "s|http://stream.live.vc.bbcmedia.co.uk/bbc_radio_one|http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_low/ak/bbc_radio_one.m3u8|" /var/lib/mpd/playlists/Default\ Playlist.m3u
      # HTTPS-Only feature (initially not enabled)
      sqlite3 $SQLDB "UPDATE cfg_system SET value='97206' WHERE param='feat_bitmask'"
      # Remove Bluetooth speaker sharing param 'btmulti' (obsolete)
      sqlite3 $SQLDB "UPDATE cfg_system SET param='RESERVED_80', value='' WHERE id='80'"

      # Introduced in r824
      # Remove broken line in shairport-sync.conf
      sed -i "/audio_backend_buffer_desired_length_in_seconds'/d" /etc/shairport-sync.conf
      # Remove unneeded conf that was part of obsolete Bluetooth speaker sharing option
      rm /etc/alsa/conf.d/20-bluealsa-dmix.conf

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

      # General
      # Any release may contain station updates
      # Import_stations update
      import_stations update "https://dl.cloudsmith.io/public/moodeaudio/m8y/raw/files/moode-stations-update_$PKG_VERSION.zip"

      #--------------------------------------------------------------------------------------------------------
      # bring it alive ;-)
      #--------------------------------------------------------------------------------------------------------
      # just start it to add playlist and then stop it
      #echo "wait at max 30 seconds until mpd is started ...."
      #/usr/local/bin/moodeutl -r
      #timeout 30s bash -c 'until mpc status; do sleep 3; done';
      echo "moode-player upgrade finished, please reboot"
}


if [ "$ACTION" = "configure" ] && [ -z $VERSION ] || [ "$ACTION" = "abort-remove" ]
then
      on_install
elif [ "$ACTION" = "configure" ] && [ -n $VERSION ]
then
      #--------------------------------------------------------------------------------------------------------
      # perform upgrade"
      # Existing configuration files that are change are NOT updated.
      # If you need to patch a config file this is the right place
      #--------------------------------------------------------------------------------------------------------
      on_upgrade
elif echo "${ACTION}" | grep -E -q "(abort|fail)"
then
      echo "Failed to install before the post-installation script was run." >&2
      exit 1
fi
