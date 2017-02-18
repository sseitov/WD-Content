#!/bin/bash

# Global build settings
export SDKPATH=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
export MIN_MACOS_VERSION=10.10
export HOST=x86_64-apple-darwin
export LDFLAGS_NATIVE="-isysroot $SDKPATH"
export TASN1_CFLAGS="-Ilibtasn1/include"
export TASN1_LIBS="-Llibtasn1 -ltasn1"
export ARCH="x86_64"

# libtasn1 defines
export TASN1_URL="http://ftp.gnu.org/gnu/libtasn1/libtasn1-4.9.tar.gz"
export TASN1_DIR_NAME="libtasn1-4.9"

# libdsm defines
export DSM_URL="https://github.com/videolabs/libdsm/releases/download/v0.2.7/libdsm-0.2.7.zip"
export DSM_DIR_NAME="libdsm-0.2.7"

######################################################################

echo "Checking libtasn1..."

# Download the latest libtasn1 library
if [ ! -d $TASN1_DIR_NAME ]; then
	echo "Downloading libtasn1..."
	curl -o $TASN1_DIR_NAME.tar.gz $TASN1_URL
	gunzip -c $TASN1_DIR_NAME.tar.gz | tar xopf -
fi
echo "... Done"

echo "Checking libdsm..."

# Download the latest version of libdsm
if [ ! -d $DSM_DIR_NAME ]; then
	echo "Downloading libdsm..."
	curl -L -J -O $DSM_URL
	unzip $DSM_DIR_NAME.zip -d $PWD
fi

echo "...Done"

######################################################################
#Build tasn1

#Remove the previous build of libtasn1 from libdsm
rm -rf $DSM_DIR_NAME/libtasn1

cd $TASN1_DIR_NAME
rm -rf build

#Build libtasn1
export LDFLAGS=$LDFLAGS_NATIVE
export CFLAGS="-arch $ARCH $LDFLAGS -mmacosx-version-min=$MIN_MACOS_VERSION -Wno-sign-compare"
./configure --host=$HOST --prefix=$PWD/build/$ARCH && make && make install

#Copy headers and binary across
cd ../
echo "Copying libtasn1 binary and headers to libdsm"

#Copy binary to libdsm folder for its build process
mkdir $DSM_DIR_NAME/libtasn1
cp -R $TASN1_DIR_NAME/build/x86_64/include $DSM_DIR_NAME/libtasn1/include
cp -R $TASN1_DIR_NAME/build/x86_64/lib/libtasn1.a $DSM_DIR_NAME/libtasn1/libtasn1.a

echo "Done!"

######################################################################
#Build libdsm

cd $DSM_DIR_NAME
rm -rf build

export LDFLAGS=$LDFLAGS_NATIVE
export CFLAGS="-arch $ARCH $LDFLAGS -mmacosx-version-min=$MIN_MACOS_VERSION -DNDEBUG -Wno-sign-compare"
./configure --host=$HOST --prefix=$PWD/build/$ARCH && make && make install

cd ../
mkdir libdsm
mkdir libdsm/include

cp $DSM_DIR_NAME/libtasn1/libtasn1.a libdsm/libtasn1.a 
cp -R $DSM_DIR_NAME/libtasn1/include libdsm/

cp -R $DSM_DIR_NAME/build/x86_64/include/bdsm/. libdsm/include
cp -R $DSM_DIR_NAME/build/x86_64/lib/libdsm.a libdsm/libdsm.a
