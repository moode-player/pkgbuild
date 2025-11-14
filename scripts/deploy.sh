#!/usr/bin/bash
#########################################################################
#
# Helper script for upload deb + source to cloudsmith repo
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

REPO=moodeaudio/m8y/raspbian/trixie

if [ -z "${VIRTUAL_ENV}" ]
then
    VENV_DIR=$(dirname "$0")/../.venv
    echo "no virtual environment active"
    # echo "dir: ${VENV_DIR}"
    if [ ! -d "${VENV_DIR}" ]
    then
        echo "create python virtual env in .venv"
        python -m venv ${VENV_DIR}
    fi
    source ${VENV_DIR}/bin/activate
fi


cloudsmith --version > /dev/null 2>&1
if [[ $? -gt 0 ]]
then
    pip install click click-didyoumean requests requests-toolbelt semver dateutil cl-py-configparser six
    pip3 install --upgrade cloudsmith-cli --extra-index-url=https://dl.cloudsmith.io/public/cloudsmith/cli/python/index/
    if [[ $? -gt 0 ]]
    then
        echo "Error during cloudsmith install!"
        deactivate
        exit 1
    fi
    cloudsmith login
    if [[ $? -gt 0 ]]
    then
        echo "Error during cloudsmith install!"
        deactivate
        exit 1
    fi
fi

PKG=$1
CMP=$2

if [ $2 ]
then
  CMP="$2"
else
  CMP="main"
#   CMP="unstable"
fi

echo "Using channel: $CMP"

# Used for coloured output
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
LIME_YELLOW=$(tput setaf 190)
YELLOW=$(tput setaf 3)


if [ ! -d "dist" ]
then
    echo "${RED}No dist directory found. This command should be runned from a package root directory.' ${NORMAL}"
    deactivate
    exit 1
fi

if [ -z "$PKG" ]
then
    echo "No package specified, run from package dir."
    echo " usage : deploy.sh foobar_1.2.3"
    echo $DEB
    deactivate
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
    deactivate
    exit 1
fi

if [[ -n $DEB ]]
then
    echo "${GREEN}Found package to upload${NORMAL}"
    cloudsmith push deb $REPO $DEB --component $CMP
else
    echo "${YELLOW}No deb packages found to upload. Skipping.${NORMAL}"
fi

if [[ -n $DSC  && -n $DEBIAN && -n $SRC ]]
then
    echo "${GREEN}Found sources${NORMAL}"
    echo "cloudsmith push deb $REPO $DSC --sources-file $SRC  --changes-file $DEBIAN"
    cloudsmith push deb $REPO $DSC --sources-file $SRC  --changes-file $DEBIAN --component $CMP
else
    echo "${YELLOW}No source found${NORMAL}"
fi

deactivate