#!/bin/bash

#TODO: make sure the package can upgrade an reinstalled without sideeffects, requires splitting in part that should be done only once and what should be done on upgrade or always

echo "$1"
echo "$1 $2" >> /tmp/moode.log

if [ "$1" = "configure" ]
then
  # if [ ! -z "$2" ]
  # then
      # DURING DEVELOPMENT TEMPORARY DISABLED
      # timedatectl set-timezone "America/Detroit"
      echo "pi:moodeaudio" | chpasswd

      sed -i "s/raspberrypi/moode/" /etc/hostname
      sed -i "s/raspberrypi/moode/" /etc/hosts
      # #TODO: use a dpkg-divert instead?
      cp /usr/share/moode-player/boot/config.txt.default /boot/config.txt
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
      systemctl daemon-reload
      systemctl enable haveged

      systemctl unmask hostapd

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
          phpsessionclean.service \
          phpsessionclean.timer \
          shellinabox \
          shairport-sync \
          squeezelite \
          triggerhappy \
          udisks2 \
          upmpdcli )

      for service in "${disable_services[@]}"
      do
        systemctl stop "${service}"
        systemctl disable "${service}"
      done

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
      chmod -R 0755 /var/www
      chmod -R 0755 /var/local/www
      chmod -R 0777 /var/local/www/db
      chmod -R ug-s /var/local/www
      # chmod -R 0755 /usr/local/bin


      #if [ ! -f /var/local/www/db/moode-sqlite3.db ]
      #then
        echo "** Create database"
      # fresh install

          if [ -f /var/local/www/db/moode-sqlite3.db ]
          then
            rm /var/local/www/db/moode-sqlite3.db
          fi
          cat /var/local/www/db/moode-sqlite3.db.sql | sqlite3 /var/local/www/db/moode-sqlite3.db
          sqlite3 /var/local/www/db/moode-sqlite3.db "UPDATE cfg_system SET value='Emerald' WHERE param='accent_color'"
      #else
      # echo "** Update database"
      # update
      # Do patch work
      #fi

      LIBCACHE_BASE="/var/local/www/libcache"
      echo "** Initial permissions for certain files. These also get set during moOde Worker startup"
      touch /var/local/www/playhistory.log
      touch /var/local/www/currentsong.txt
      chmod 0777 /var/local/www/playhistory.log
      chmod 0777 /var/local/www/currentsong.txt

    	echo "** Establish permissions"
    	# chmod 0777 /var/lib/mpd/music/RADIO # is part of mpd pkg
	    chmod -R 0777 /var/local/www/db
	    chown www-data:www-data /var/local/php

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

      echo "** Update sudoers file"
      #TODO: this could be added a config file instead
      if [ ! -e /etc/sudoers.d/010_www-data-nopasswd ]; then
        echo -e "www-data\tALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/010_www-data-nopasswd
        chmod 0440 /etc/sudoers.d/010_www-data-nopasswd
      fi

      echo "** Setup config files"
      #TODO:
      # Deal with the files is /usr/share/moode-player etc|lib|boot
      # mostly updates for existsing (owned by other packages) files
      # ...
      SRC=/usr/share/moode-player
      cp -f $SRC/etc/upmpdcli.conf /etc/
      cp -f $SRC/etc/rc.local /etc/
      cp -f $SRC/etc/udisks-glue.conf /etc/

      cp $SRC/etc/upmpdcli.conf /etc/

      # alsa
      rsync -av --exclude=-'20-bluealsa.conf' $SRC/etc/alsa/conf.d/ /etc/alsa/conf.d

      # nginx + php + php74-fpm
      cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf
      cp -f $SRC/etc/nginx/fastcgi_params /etc/nginx/fastcgi_params
      sed -i "s/^post_max_size.*/post_max_size = 50M/" /etc/php/7.4/cli/php.ini
      sed -i "s/^upload_max_filesize.*/upload_max_filesize = 50M/" /etc/php/7.4/cli/php.ini
      sed -i "s/^pm[.]max_children.*/pm.max_children = 50/" //etc/php/7.4/fpm/pool.d/www.conf
      sed -i "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" /etc/php/7.4/cli/php.ini

      sed -i "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" /etc/php/7.4/cli/php.ini

      sed -i "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^max_execution_time.*/max_execution_time = 300/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^max_input_time.*/max_input_time = -1/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^max_input_vars.*/max_input_vars = 10000/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^memory_limit.*/memory_limit = -1/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^post_max_size.*/post_max_size = 75M/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^upload_max_filesize.*/upload_max_filesize = 75M/" /etc/php/7.4/fpm/php.ini
      sed -i "s/^;defensive.*/defensive = 1/" /etc/php/7.4/fpm/php.ini

      cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf

      # samba
      cp -f $SRC/etc/samba/smb.conf /etc/samba

      # mpd
      cp -f $SRC/etc/mpd.conf /etc/
      chown mpd:audio /etc/mpd.conf
      chmod 0666 /etc/mpd.conf


      # incase any changes are made to systemd file reload config
      systemctl daemon-reload

      sync

      # restart some services to pickup new configuration
      systemctl stop nginx
      systemctl restart php7.4-fpm
      systemctl start nginx
      systemctl restart smbd
      systemctl restart winbind

      #don't now why there is a empty database dir instead of a database file
      if [ -d /var/lib/mpd/database ]
      then
        rmdir -rf /var/lib/mpd/database
      fi

      /usr/bin/udisks-glue --config=/etc/udisks-glue.conf > /dev/null 2>&1

      # just start it to add playlist and then stop it
      /usr/local/bin/moodeutl -r
      timeout 30s bash -c 'until mpc status; do sleep 3; done';
      mpc status
      if [[ $? -gt 0 ]]
      then
        mpc load "Default Playlist"
        echo "** List MPD outputs"
        mpc outputs
        echo "** Enable only output 1"
        mpc enable only 1
      else
        echo "hmmm problem mpd isn't started!"
      fi

      echo "moode-player install finished, please reboot"
  # fi

else
  echo "test2"

fi
