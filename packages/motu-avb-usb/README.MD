The motu-avb-usb package are drivers for the MOTU AVB line of devices.

When you simultaneously capturing and playing audio and have cracks and pops this driver could be your solution. If everything is fine don't bother to install it, see below:

The driver also installs the file /etc/modprobe.d/motu-avb.conf with drivers options.
The downside of using this driver that the samplerate isn't dynamic and should be set in this file.

See https://github.com/Drumfix/motu-avb-usb for more info about the use.

