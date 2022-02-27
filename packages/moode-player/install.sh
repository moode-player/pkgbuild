
#########################################################################
#
# Recipe for installing moOde audio player on clean RaspiOS Lite system
# RaspiOS Lite Bullseye release is required.
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

# Step 0 - Write RaspiOS image to SD card

# Step 1 - Configure APT for moOde package repo
curl -1sLf \
'https://dl.cloudsmith.io/public/moodeaudio/m8y/setup.deb.sh' \
| sudo -E bash

# Step 2 - Make sure OS is up to date
sudo apt update
sudo apt upgrade

# Reboot in case upgrade installs new kernel
sudo reboot

# Step 3 - Install moOde audio player

echo "Install moOde audio player"
sudo apt install moode-player

# Step 4 - Install kernel drivers

KERNEL_VER=$(uname -r | sed -r "s/([0-9.]*)[-].*/\1/")
echo "Checking for drivers built for kernel version: ${KERNEL_VER}"
# NOTE: Be sure to update this array
SUPPORTED_KERNELS=(5.10.63 5.10.92 5.15.23)
inarray=$(echo ${SUPPORTED_KERNELS[@]} | grep -o "$KERNEL_VER" | wc -w)
if [ $inarray -eq 1 ]
then
    echo "Installing kernel drivers"
    sudo apt install aloop-$KERNEL_VER pcm1794a-$KERNEL_VER ax88179-$KERNEL_VER rtl88xxau-$KERNEL_VER
else
    echo "Warning: drivers have not yet been built for this kernel version"
    echo "Skipping driver install"
fi

# Apply package hold protection
sudo moode-apt-mark hold
sudo reboot
