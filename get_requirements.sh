#!/bin/bash

# Description: Script to fetch requirements for building this project.
# Last-modified: 2010-12-02 01:28:31
#
# Note that this script is not perfect and does not handle all errors.
# Any improvements are welcome.


# Either Git or Subversion is needed to retrieve Theos.
GIT=$(type -P git)
SVN=$(type -P svn)
if [ -z "$GIT" -a -z "$SVN" ]; then
    echo "ERROR: This script requires either 'git' or 'svn' to be installed."
    exit 1
fi

# Either wget or curl is needed to download package list and ldid.
WGET=$(type -P wget)
CURL=$(type -P curl)
if [ -z "$WGET" -a -z "$CURL" ]; then
    echo "ERROR: This script requires either 'wget' or 'curl' to be installed."
    exit 1
fi

# Download Theos
echo "Downloading Theos..."
if [ ! -z "$GIT" ]; then
    git clone --quiet git://github.com/DHowett/theos.git theos
else
    svn co http://svn.howett.net/svn/theos/trunk theos
fi

# Download MobileSubstrate header
echo "Downloading MobileSubstrate header..."
SUBSTRATE_REPO="http://apt.saurik.com"
pkg=""
if [ ! -z "$WGET" ]; then
    wget -q "${SUBSTRATE_REPO}/dists/tangelo-3.7/main/binary-iphoneos-arm/Packages.bz2"
    pkg_path=$(bzcat Packages.bz2 | grep "debs/mobilesubstrate" | awk '{print $2}')
    pkg=$(basename $pkg_path)
    wget -q "${SUBSTRATE_REPO}/${pkg_path}"
else
    curl -s -L "${SUBSTRATE_REPO}/dists/tangelo-3.7/main/binary-iphoneos-arm/Packages.bz2" > Packages.bz2
    pkg_path=$(bzcat Packages.bz2 | grep "debs/mobilesubstrate" | awk '{print $2}')
    pkg=$(basename $pkg_path)
    curl -s -L "${SUBSTRATE_REPO}/${pkg_path}" > $pkg
fi
ar -p $pkg data.tar.gz | tar -zxf - ./Library/Frameworks/CydiaSubstrate.framework/Headers/CydiaSubstrate.h
mv ./Library/Frameworks/CydiaSubstrate.framework/Headers/CydiaSubstrate.h theos/include/substrate.h
rm -rf usr Packages.bz2 $pkg

# Download ldid
echo "Downloading ldid..."
if [ "$(uname)" == "Darwin" ]; then
    if [ ! -z "$WGET" ]; then
        wget -q http://dl.dropbox.com/u/3157793/ldid
    else
        curl -s http://dl.dropbox.com/u/3157793/ldid > ldid
    fi
    mv ldid theos/bin/ldid
    chmod +x theos/bin/ldid
else
    echo "... No pre-built version of ldid is available for your system."
    echo "... You will need to provide your own copy of ldid."
fi

# Check if .deb creation tools are available (optional)
echo "Checking for dpkg-deb..."
if [ -z "$(type -P dpkg-deb)" ]; then
    echo "... dpkg-deb not found."
    echo "... If you wish to create a .deb package, you will need the 'dpkg-deb' tool."
fi

echo "Done."
