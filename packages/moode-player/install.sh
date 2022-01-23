
#
# install moode audio player on a clean raspberry OS bullseye lite
#

# step 0 - Prep a Debian Bullseye image on SD card

# step 1 - Install moode repo
curl -1sLf \
'https://dl.cloudsmith.io/public/moodeaudio/m8x/setup.deb.sh' \
| sudo -E bash

# step 2 - Make sure system is up2date
sudo apt update
sudo apt upgrade

sudo reboot

# step 3 - Install moode audio player
KERNEL_VER=$(uname -r | sed -r "s/([0-9.]*)[-].*/\1/")
echo "installing drivers for kernel version: ${KERNEL_VER}"
# it can happen that the kernel modules aren't already avaible for the current kernel:
sudo apt install moode-player aloop-$KERNEL_VER pcm1794a-$KERNEL_VER ax88179-$KERNEL_VER rtl88xxau-$KERNEL_VER
sudo apt-mark hold raspberrypi-kernel mpd mpc caps
sudo reboot

