#!/bin/bash

# Example:
# - Download package source
# - Apply patch
# - Change local part of version
# - Check if build deps are present and if not install those
# - Build the package
# - Move the results

. ../../scripts/rebuilder.sh

VER_PKG=0.9.26
echo $VER_PKG

# cleanup previous buildir
rm -rf caps-$VER_PKG

# get original source pacakge
dget --no-cache http://deb.debian.org/debian/pool/main/c/caps/caps_$VER_PKG-1.dsc

cd caps-$VER_PKG

# patch and add patch to debian
patch -p1 < ../caps_12band_eqp.patch
EDITOR=/bin/true dpkg-source --commit . caps_12band_eqp.patch

# set debian local suffix flag
DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --local $DEBSUFFIX "Added patch for 12 band eqfa12p PEQ"

# if build deps aren't present, install it and clean up leftovers
dpkg-checkbuilddeps
if [[ $? -gt 0 ]]
then
    mk-build-deps --install --root sudo --remove
    rm *build-deps_$VER_PKG-*$DEBSUFFIX_armhf.*
fi

# build package
dpkg-buildpackage -us -uc
cd ..

# copy output to dist dir
mkdir -p dist
mv *$VER_PKG*$DEBSUFFIX* dist/

echo "done"
