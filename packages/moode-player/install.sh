
#
# install moode audio player on a clean raspberry OS bullseye lite
#

# step 0 - Prep a Debian Bullseye image on SD card

# step 1 - Install moode repo
curl -1sLf \
'https://dl.cloudsmith.io/public/moodeaudio/m8y/setup.deb.sh' \
| sudo -E bash

# step 2 - Make sure system is up2date
sudo apt update
sudo apt upgrade

sudo reboot

# step 3 - Install moode audio player

echo "install moode audio player"
sudo apt install moode-player

echo "installing drivers for kernel version: ${KERNEL_VER}"
SUPPORTED_KERNELS=(5.10.63 5.10.92)
KERNEL_VER=$(uname -r | sed -r "s/([0-9.]*)[-].*/\1/")
inarray=$(echo ${SUPPORTED_KERNELS[@]} | grep -o "$KERNEL_VER" | wc -w)
# it can happen that the kernel modules aren't already avaible for the current kernel:
if [ $inarray -eq 1 ]
then
    sudo apt install aloop-$KERNEL_VER pcm1794a-$KERNEL_VER ax88179-$KERNEL_VER rtl88xxau-$KERNEL_VER
else
    echo "Warning unsupported kernel; skipping driver install."
fi

sudo moode-apt-mark hold
sudo reboot

