# moOde audio player - package builder

This repository contains scripts to build packages for the third-party software components used in moOde audio player.

## Origin and build type
There are several ways in which packages are built and sources obtained.

| How   | Description |  Output        |
|------------|-------------| --|
| backport   | Download source package  | deb+src |
| [cargo-deb](https://github.com/kornelski/cargo-deb)  | Git clone source, generate package from rust project with cargo-deb| deb |
| rebuild    | Rebuild from stock package source | deb+src |
| [fpm](https://github.com/jordansissel/fpm)   | Git clone source, generate package with FPM| deb |
| git        | Clone source, contains debian directory | deb+src |
| git+debsrc | Clone source, use debian dir from older version | deb+src |
| git+dhmake | Clone source and create new package | deb+src |
| [stdeb](https://github.com/astraw/stdeb)   | Git clone source, generate package with stdeb| deb+src |
| [stock](https://packages.debian.org/bullseye/)      | No need to build, use stock available | - |

All forms with src as output can be rebuilt from source packages (also present in the repo).

## Overview of the third party packages that are used.

| Package    |      Version    | How  | Patches* |
|----------  |-----------------|:----|---------------|
| [alsa-cdsp](https://github.com/scripple/alsa_cdsp)  | 1.0.0-1moode1  | git+dh_make | yes |
| [alsacap](https://github.com/bubbapizza/alsacap)    | 1.0.1-1moode1  | git+dh_make |  |
| [ashuffle](https://github.com/joshkunz/ashuffle)   | 3.12.5-1moode1 | git+dh_make |  |
| [*bluez*](https://github.com/bluez/bluez)      | *5.55-3.1+rpt1* | ***stock*** |
| [bluez-alsa](https://github.com/Arkq/bluez-alsa) | 3.0.0-2moode1  | backport    |  |
| [camilladsp](https://github.com/HEnquist/camilladsp) | 0.6.3-1moode1  | cargo-deb   |  |
| [camillagui](https://github.com/HEnquist/camillagui) | 0.6.0-1moode1  | fpm   | yes |
| [*camillagui-backend*](https://github.com/HEnquist/camillagui-backend) | *0.8.0-1moode1*  | *-*  | *yes* |
| [caps](http://quitte.de/dsp/caps.html)       | 0.9.26-1moode1 | rebuild     | yes |
| [libnpupnp1](https://www.lesbonscomptes.com/upmpdcli/index.html) | 4.0.14-1moode1 | git         |  |
| [librespot](https://github.com/librespot-org/librespot)  | 0.3.1-1moode1  | cargo-deb   |  |
| [libupnpp6](https://www.lesbonscomptes.com/upmpdcli/index.html)  | 0.21.0-1moode1 | git         |  |
| [*mediainfo*](https://mediaarea.net/nl/MediaInfo)  | *20.09-1* | ***stock*** |
| [*minidlna*](https://sourceforge.net/projects/minidlna/)   | *1.3.0+dfsg-2* | ***stock*** |
| [*mpc*](https://www.musicpd.org/)        | *0.33.1* | ***stock*** |
| [mpd](https://www.musicpd.org/)        | 0.23.5-1moode3 | backport    | yes |
| [python3-camilladsp](https://github.com/HEnquist/pycamilladsp) | 0.6.0-1moode1 | stdeb |  |
| [python3-camilladsp-plot](https://github.com/HEnquist/pycamilladsp-plot) | 0.6.2-1moode1 | stdeb |  |
| [python3-libupnpp](https://www.lesbonscomptes.com/upmpdcli/index.html) | 0.20.1~-1moode1 | git   |  |
| [shairport-sync](https://github.com/mikebrady/shairport-sync) | 3.3.8-1moode1| backport | |
| [squeezelite](https://github.com/ralph-irving/squeezelite)| 1.9+git20210102.78fef68-3moode1 | rebuild |  yes |
| [trx](http://www.pogo.org.uk/~mark/trx/)        | 0.6-1moode1    |  git+dh_make |  |
| [udisks](https://www.freedesktop.org/wiki/Software/udisks/) | 1.0.5-1moode1 | ***upport*** | yes |
| [udisks-glue](https://github.com/fernandotcl/udisks-glue) | 1.3.5-1moode3 | git+debsrc |  |
| [upmpdcli](https://www.lesbonscomptes.com/upmpdcli/index.html)   | 1.5.12-1moode1 | git |  |

Patches* means patches required for the source code and excludes patches for the packing itself.
Stock pacakges can be directly used, no need to rebuild.

camillagui-backend is bundled with the camillagui package.

## Other packages in the repo for example drivers.

| Package    |      Version    | How  | Patches* | Descriptions |
|----------  |-----------------|:----|---------------|----------|
| [aloop](https://github.com/moode-player/pkgbuild )    | 5.10.63-1moode1  | fpm | yes | 384kHz patch for in tree module
| [ax88179](https://github.com/allocom/USBridgeSig-AX2v0.git)    | 5.6.4.2-1moode1  | git |  | Patched  ax88179_178a driver with Allo SIG suppport.
| [boss2-oled-p3](https://github.com/allocom/allo_boss2_oled_p3)  | 1.0.0-1moode1  | fpm |  | Allo Boss2 OLED display service
| [pcm1794a](https://github.com/moode-player/pkgbuild)  | 5.10.63-1moode1  | fpm | yes | 384kHz patch for in tree module
| [rpi-source](https://github.com/RPi-Distro/rpi-source)    | 0.1-1moode1  | git | yes | Fixes to let it work with Python 3. Only needed with development.
| [rtl88xxau](https://github.com/aircrack-ng/rtl8812au)    | 5.6.4.2-1moode1  | git |  | Required for SIG Wifi.
| [runonce](https://github.com/moode-player/pkgbuild ) | 0.1.0-1moode1 | fpm | | service for running scripts once during boot

## Usage

Requirements:
* Pi with Raspbian Lite Bullseye installed.
### Setup enviroment settings
* Copy the setenv.sh.example to `setenv.sh`
* Change the content to reflext your settings.

```bash
export DEBFULLNAME=FooBar
export DEBEMAIL=foobar@users.noreply.github.com
```

### Building a package
Go to a package dir in the subdir packages and run the `build.sh` script

```bash
cd packages/alsacap
./build.sh
```
The output will be in the `dist` directory.
### Deploy package and source

There is an helper script that deploys packages to a CloudSmith Repo.
This requires an account.

Go to a package dir that is builded and run the deploy command.

```bash
cd packages/alsacap
../../scripts/deploy.sh alsacap_1.0.1
```
