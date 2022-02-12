#!/usr/bin/bash
#########################################################################
#
# Helper script for upload deb + source to cloudsmith repo
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

REPO=moodeaudio/m8y/raspbian/bullseye

cloudsmith --version > /dev/null 2>&1
if [[ $? -gt 0 ]]
then
    sudo apt update
    sudo apt install python3-pip
    sudo pip3 install --upgrade cloudsmith-cli
    cloudsmith login
fi

PKG=$1

# Used for coloured output
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
LIME_YELLOW=$(tput setaf 190)
YELLOW=$(tput setaf 3)


if [ ! -d "dist" ]
then
    echo "${RED}No dist directory found. This command should be runned from a package root directory.' ${NORMAL}"
    exit 1
fi

if [ -z "$PKG" ]
then
    echo "No package specified, run from package dir."
    echo " usage : deploy.sh foobar_1.2.3"
    echo $DEB
    exit 1
fi

DEB=`find ./dist/binary -maxdepth 1 -name "$PKG*.deb" ! -name "$PKG-dbgsym*.deb"`
DEB_COUNT=`find ./dist/binary -maxdepth 1 -name "$PKG*.deb" | wc -l`

DSC=`find ./dist/source -maxdepth 1 -name "$PKG*.dsc"`
DEBIAN=`find ./dist/source -maxdepth 1 -name "$PKG*.debian*"`
SRC=`find ./dist/source -maxdepth 1 -name "$PKG*.orig*" ! -name "$PKG*.asc"`

if [ $DEB_COUNT -gt 1 ]
then
    echo "${YELLOW}Multiple packages found to upload, not supported.${NORMAL}"
    echo $DEB
    exit 1
fi

if [[ -n $DEB ]]
then
    echo "${GREEN}Found package to upload${NORMAL}"
    cloudsmith push deb $REPO $DEB
else
    echo "${YELLOW}No deb packages found to upload. Skipping.${NORMAL}"
fi

if [[ -n $DSC  && -n $DEBIAN && -n $SRC ]]
then
    echo "${GREEN}Found sources${NORMAL}"
    echo "cloudsmith push deb $REPO $DSC --sources-file $SRC  --changes-file $DEBIAN"
    cloudsmith push deb $REPO $DSC --sources-file $SRC  --changes-file $DEBIAN
else
    echo "${YELLOW}No source found${NORMAL}"
fi
