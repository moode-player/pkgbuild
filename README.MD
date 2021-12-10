# moOde package repository builder

This git repository contains scripts to build the used third-party software for moOde audio player running on Raspbian Bullseye.

## Origin and build type
The a several ways how the package is build and where the source is coming from:

| How   | Description |  Output        |
|------------|-------------| --|
| git        | Clone source, contains debian directory | deb+src |
| git+dhmake | Clone source and create new package | deb+src |
| backport   | Download source package  | deb+src |
| cargo-deb  | Git clone source, generate package from rust project with cargo-deb| deb |
| rebuild    | Rebuild from stock package source | deb+src |
| stdeb   | Git clone source, generate package with stdeb| deb+src |
| fpm   | Git clone source, generate package with FPM| deb |
| git+debsrc | Clone source, use debian dir from older version | deb+src |
| stock      | No need to build, use stock available | - |


## Overview of the current used thirdparty package status


| Package    |      Version    | How  | Patches* |
|----------  |-----------------|:----|---------------|
| alsa-cdsp  | 1.0.0-1~moode1  | git+dh_make | yes |
| alsacap    | 1.0.1-1~moode1  | git+dh_make |  |
| ashuffle   | 3.12.5-1~moode1 | git+dh_make |  |
| *bluez*      | *5.55-3.1+rpt1* | ***stock*** |
| bluez-alsa | 3.0.0-2~moode1  | backport    |  |
| camilladsp | 0.6.3-1~moode1  | cargo-deb   |  |
| camillagui | 0.6.0-1~moode1  | fpm   | yes |
| *camillagui-backend* | *0.8.0-1~moode1*  | *-*  | *yes* |
| caps       | 0.9.26-1~moode1 | rebuild     | yes |
| libnpupnp1 | 4.0.14-1~moode1 | git         |  |
| librespot  | 0.3.1-1~moode1  | cargo-deb   |  |
| libupnpp6  | 0.21.0-1~moode1 | git         |  |
| *mediainfo*  | *20.09-1* | ***stock*** |
| *minidlna*   | *1.3.0+dfsg-2* | ***stock*** |
| *mpc*        | *0.33.1* | ***stock*** |
| mpd        | 0.23.5-1~moode1 | backport    | yes |
| python3-camilladsp | 0.6.0-1~moode1 | stdeb |  |
| python3-camilladsp-plot | 0.6.2-1~moode1 | stdeb |  |
| python3-libupnpp | 0.20.1~-1moode1 | git   |  |
| *shairport-sync* | *3.3.7*| ***stock*** |
| *squeezelite*| *1.9+git20210102.78fef68-3* | ***stock*** |
| trx        | 0.6-1~moode1    |  git+dh_make |  |
| udisks-glue | 1.3.5-1~moode1 | git+debsrc |  |
| upmpdcli   | 1.5.12-1~moode1 | git |  |

Patches means patches required for the source code, excludes patches for the packing it self.
Stock pacakge can be directly used, no need to rebuild.

camillagui-backend is bundled with the camillagui package
