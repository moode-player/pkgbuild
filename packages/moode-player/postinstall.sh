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

      # Done as last step of the script:
      # sed -i "s/raspberrypi/moode/" /etc/hostname
      # sed -i "s/raspberrypi/moode/" /etc/hosts

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

      chmod -R a+rw /usr/share/camilladsp

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
      # ------------------------------------------------------------------------------------------
      # Overwrite files not owned by moode-player (a prob owned by other packages)
      # ------------------------------------------------------------------------------------------
      SRC=/usr/share/moode-player
      cp -rf $SRC/etc/* /etc/
      cp -rf $SRC/lib/* /lib/
      cp -rf $SRC/usr/* /usr/
      cp -rf $SRC/boot/* /boot/

      #cp -f $SRC/etc/upmpdcli.conf /etc/
#      cp -f $SRC/etc/rc.local /etc/
 #     cp -f $SRC/etc/udisks-glue.conf /etc/

#      cp $SRC/etc/upmpdcli.conf /etc/

      # alsa
#      rsync -av --exclude=-'20-bluealsa.conf' $SRC/etc/alsa/conf.d/ /etc/alsa/conf.d

      # nginx + php + php74-fpm

      # /etc/nginx/nginx.conf

#      cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf
      # /etc/nginx/fastcgi_params
#      cp -f $SRC/etc/nginx/fastcgi_params /etc/nginx/fastcgi_params

      # ------------------------------------------------------------------------------------------
      # Patch files with sed
      # ------------------------------------------------------------------------------------------
      # From the root moode git repo find files to patch with sed:
      #  find . -name "*.sed*" |sort
      PHP_VER="7.4"

      # /etc/bluetooth/main.conf
		  # Name = Moode Bluetooth
		  # Class = 0x20041C		# 2  = Service Class: 		Audio
				                		# 4  = Major Device Class	Audio/Video
						               # 1C = Minor Device Class: 	Loudspeaker x14 + Headphones  x18
		  # DiscoverableTimeout = 0	# Stay discoverable forever
		  # ControllerMode = bredr 	# Enables Pi-to Pi connections
      sed -i -e 's/[#]Name[ ]=[ ].*/Name = Moode Bluetooth/' \
             -e 's/[#]Class[ ]=[ ].*/Class = 0x20041C/' \
             -e 's/#DiscoverableTimeout[ ]/DiscoverableTimeout[ ]/' \
             -e 's/[#]ControllerMode[ ]=[ ].*/ControllerMode = bredr/' \
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
			# pm.max_children = 50
      sed -i "s/^pm[.]max_children.*/pm.max_children = 50/" /etc/php/$PHP_VER/fpm/pool.d/www.conf

      # /etc/php/$PHP_VER/fpm/php.ini
      # max_execution_time = 300
      # max_input_vars = 10000
      # memory_limit = -1
      # upload_max_filesize = 75M
      # session.save_path = "0;666;/var/local/php"
      sed -i -e "s/^;session.save_path.*/session.save_path = \"0;666;\/var\/local\/php\"/" \
             -e "s/^max_execution_time.*/max_execution_time = 300/" \
             -e "s/^max_input_time.*/max_input_time = -1/" \
             -e "s/^max_input_vars.*/max_input_vars = 10000/" \
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
             -e 's/\/\/.*\(audio_backend_buffer_desired_length_in_seconds\)/\1/' \
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
             -e 's/[#]iconpath[ ]=.*/iconpath = \"\/usr\/share\/upmpdcli\/moode_audio.png\"/' \
             -e 's/[#]ohproductroom[ ]=.*/ohproductroom = Moode UPNP/' \
            /etc/upmpdcli.conf

      cp -f $SRC/etc/nginx/nginx.conf /etc/nginx/nginx.conf

      # samba
      # cp -f $SRC/etc/samba/smb.conf /etc/samba

      # mpd
      #cp -f $SRC/etc/mpd.conf /etc/
      touch /etc/mpd.conf
      chown mpd:audio /etc/mpd.conf
      chmod 0666 /etc/mpd.conf


      # incase any changes are made to systemd file reload config
      systemctl daemon-reload

      sync

      #--------------------------------------------------------------------------------------------------------
      # bring it a live ;-)
      #--------------------------------------------------------------------------------------------------------
      echo "** Sarting servers"
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
      echo "wait at max 30 seconds until mpd is started ...."
      /usr/local/bin/moodeutl -r
      timeout 30s bash -c 'until mpc status; do sleep 3; done';
      mpc status
      if [[ $? -eq 0 ]]
      then
        mpc load "Default Playlist"
        echo "** List MPD outputs"
        mpc outputs
        echo "** Enable only output 1"
        mpc enable only 1
      else
         echo "hmmm problem mpd isn't started!"
         echo "(check if after reboot the problem is fixed.)"
      fi

      sed -i "s/raspberrypi/moode/" /etc/hostname
      sed -i "s/raspberrypi/moode/" /etc/hosts

      echo "moode-player install finished, please reboot"
  # fi

else
  echo "test2"

fi
