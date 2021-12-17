#!/bin/bash

echo "$1"
echo "$1 $2" >> /tmp/moode.log

if [ "$1" = "configure" ]
then
  # if [ ! -z "$2" ]
  # then
      # DURING DEVELOPMENT TEMPORARY DISABLED
      # timedatectl set-timezone "America/Detroit"
      # echo "pi:moodeaudio" | chpasswd
      # #TODO: use a dpkg-divert instead?
      # cp /usr/share/moode-player/config.txt.default /boot/config.txt
      # cp /usr/share/moode-player/moodecfg.ini.default /boot/moodecfg.ini
      cp /usr/share/moode-player/boot/config.txt.default /boot/config.txt.default
      cp /usr/share/moode-player/boot/moodecfg.ini.default /boot/moodecfg.ini.default

      echo "** Basic optimizations"
      dphys-swapfile swapoff
      dphys-swapfile uninstall
      systemctl disable dphys-swapfile
      systemctl disable cron.service
      systemctl enable rpcbind
      systemctl set-default multi-user.target
      systemctl stop apt-daily.timer
      systemctl disable apt-daily.timer
      systemctl mask apt-daily.timer
      systemctl stop apt-daily-upgrade.timer
      systemctl disable apt-daily-upgrade.timer
      systemctl mask apt-daily-upgrade.timer

      echo "** Systemd enable/disable"
      systemctl enable haveged
      systemctl disable shellinabox
      systemctl disable phpsessionclean.service
      systemctl disable phpsessionclean.timer
      systemctl disable udisks2
      systemctl disable triggerhappy

      echo "** Disable hostapd and dnsmasq services"
      systemctl daemon-reload
      systemctl unmask hostapd
      systemctl disable hostapd
      systemctl disable dnsmasq

      echo "** Disable bluetooth services"
      systemctl daemon-reload
      systemctl disable bluetooth.service
      #systemctl disable bluealsa.service
      systemctl disable bluez-alsa.service
      systemctl disable hciuart.service
      # mkdir -p /var/run/bluealsa # not present ?

      echo "** Create MPD runtime environment"
      # useradd mpd # already done my mpd pkg
      # mkdir /var/lib/mpd # already done my mpd pkg
      # mkdir /var/lib/mpd/music # already done my mpd pkg
      # mkdir /var/lib/mpd/playlists # already done my mpd pkg
      touch /var/lib/mpd/state
      chown -R mpd:audio /var/lib/mpd
      # mkdir /var/log/mpd # already done my mpd pkg
      touch /var/log/mpd/log
      chmod 644 /var/log/mpd/log
      chown -R mpd:audio /var/log/mpd
      #TODO: Is it really needed to copy(is conflict with mpd itself), anyway it is generated at the start of worker.php
      # cp ./moode/mpd/mpd.conf.default /etc/mpd.conf
      chown mpd:audio /etc/mpd.conf
      chmod 0666 /etc/mpd.conf

      echo "** Set permissions for D-Bus (for bluez-alsa)"
      usermod -a -G audio mpd

      echo "** Create symlinks"
      if [ ! -e /var/lib/mpd/music/NAS ]
      then
        ln -s /mnt/NAS /var/lib/mpd/music/NAS
      fi

      if [ ! -e /var/lib/mpd/music/SDCARD ]
      then
        ln -s /mnt/SDCARD /var/lib/mpd/music/SDCARD
      fi
      if [ ! -e /var/lib/mpd/music/USB ]
      then
        ln -s /media /var/lib/mpd/music/USB
      fi

      echo "** Create logfiles"
      touch /var/log/moode.log
      chmod 0666 /var/log/moode.log
      touch /var/log/php_errors.log
      chmod 0666 /var/log/php_errors.log

      #chmod 0755 /var/www/command/*
      chmod 0755 /home/pi/*.sh

      echo "** Reset permissions"
      #TODO: maybe set the rights before packed
      # chmod -R 0744 /var/www
      # chmod 0755 /var/www/command/*
      # chmod -R 0744 /var/local/www
      # chmod -R 0777 /var/local/www/command/*
      # chmod -R 0766 /var/local/www/db
      # chmod -R 0755 /usr/local/bin

      chmod -R ug-s /var/local/www
      #chmod -R 0755 /usr/local/bin

      if [ ! -f /var/local/www/db/moode-sqlite3.db ]
      then
        echo "** Create database"
      # fresh install
        sqlite3 /var/local/www/db/moode-sqlite3.db "CREATE TRIGGER ro_columns BEFORE UPDATE OF param, value, [action] ON cfg_hash FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'read only'); END;"
        sqlite3 /var/local/www/db/moode-sqlite3.db "UPDATE cfg_system SET value='Emerald' WHERE param='accent_color'"
        cat /var/local/www/db/moode-sqlite3.db.sql | sqlite3 /var/local/www/db/moode-sqlite3.db
      else
        echo "** Update database"
      # update
      # Do patch work
      fi

      LIBCACHE_BASE=/var/local/www/libcache
      echo "** Initial permissions for certain files. These also get set during moOde Worker startup"
      touch /var/local/www/playhistory.log
      touch /var/local/www/currentsong.txt
      chmod 0777 /var/local/www/playhistory.log
      chmod 0777 /var/local/www/currentsong.txt
      touch $LIBCACHE_BASE"_all.json"
      touch $LIBCACHE_BASE"_folder.json"
      touch $LIBCACHE_BASE"_format.json"
      touch $LIBCACHE_BASE"_lossless.json"
      touch $LIBCACHE_BASE"_lossy.json"
      #FIX: this doesn't work, no clue for now?
      chmod 0777 "${LIBCACHE_BASE}_*"

    	echo "** Establish permissions"
    	# chmod 0777 /var/lib/mpd/music/RADIO # is part of mpd pkg
	    chmod -R 0777 /var/local/www/db
	    chown www-data:www-data /var/local/php

      echo "** Misc deletes"
      if [ -d "/var/www/html" ]
      then
        rm -r /var/www/html
      fi
      #TODO: must these really be deleted or can we leave them alone?
      # rm /etc/update-motd.d/10-uname
      # rm /etc/motd

      # sleep 45 $ why?
      echo "** List MPD outputs"
      mpc outputs
      echo "** Enable only output 1"
      mpc enable only 1

      echo "** Disable MiniDLNA service"
      systemctl disable minidlna

      systemctl daemon-reload
      systemctl disable upmpdcli
      systemctl disable mpd.service
      systemctl disable mpd.socket
      # systemctl disable rotenc.service
      systemctl disable squeezelite
      systemctl disable upmpdcli.service

      echo "** Update sudoers file"
      #TODO: this could be added a config file instead
      if [ ! -e /etc/sudoers.d/010_www-data-nopasswd ]; then
        echo -e "www-data\tALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/010_www-data-nopasswd
        chmod 0440 /etc/sudoers.d/010_www-data-nopasswd
      fi

      echo "** Setup config files"
      #TODO:
      # Deal with the files is /usr/share/moode-player etc|lib|boot
      # mostly updates for existsing (owned by other pacakges) files
      # ...
      SRC=/usr/share/moode-player
      cp $SRC/etc/upmpdcli.conf cp /etc/upmpdcli.conf
      cp $SRC/etc/rc.local cp /etc/rc.local

      sync
  # fi

else
  echo "test2"

fi
