#!/bin/bash

# Global build settings
export SDKPATH=/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk
export SIMSDKPATH=/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk
export MIN_TVOS_VERSION=9.0
export HOST=arm-apple-darwin
export LDFLAGS_NATIVE="-isysroot $SDKPATH"
export LDFLAGS_SIMULATOR="-isysroot $SIMSDKPATH"
export TASN1_CFLAGS="-Ilibtasn1/include"
export TASN1_LIBS="-Llibtasn1 -ltasn1"
export ARCHES="arm64"

# libtasn1 defines
export TASN1_URL="http://ftp.gnu.org/gnu/libtasn1/libtasn1-4.8.tar.gz"
export TASN1_DIR_NAME="libtasn1-4.8"

# libdsm defines
export DSM_URL="https://github.com/videolabs/libdsm/releases/download/v0.2.4/libdsm-0.2.4.zip"
export DSM_DIR_NAME="libdsm-0.2.4"

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

#Build libtasn1 for each architecture
for i in $ARCHES
do
	build_files="$build_files build/$i/lib/libtasn1.a"
	export ARCH=$i
	if [[ $i == *"arm"* ]]
	then
		export LDFLAGS=$LDFLAGS_NATIVE
	else
		export LDFLAGS=$LDFLAGS_SIMULATOR
	fi
	export CFLAGS="-arch $ARCH $LDFLAGS -mtvos-version-min=$MIN_TVOS_VERSION -fembed-bitcode"
	./configure --host=$HOST --prefix=$PWD/build/$ARCH && make && make install
done

echo $build_files

#Merge the compiled binaries into a single universal one
mkdir -p build/universal
lipo -create $build_files -output build/universal/libtasn1.a

#Copy headers across
mkdir build/universal/include
cp -R build/arm64/include build/universal/

cd ../

#Copy binary to libdsm folder for its build process
cp -R $TASN1_DIR_NAME/build/universal $DSM_DIR_NAME/libtasn1

######################################################################
#Build libdsm

cd $DSM_DIR_NAME
rm -rf build

build_files=""
for i in $ARCHES
do
	build_files="$build_files build/$i/lib/libdsm.a"
	export ARCH=$i
	if [[ $i == *"arm"* ]]
	then
		export LDFLAGS=$LDFLAGS_NATIVE
	else
		export LDFLAGS=$LDFLAGS_SIMULATOR
	fi
	export CFLAGS="-arch $ARCH $LDFLAGS -mtvos-version-min=$MIN_TVOS_VERSION -fembed-bitcode -DNDEBUG"
	./bootstrap
	./configure --host=$HOST --prefix=$PWD/build/$ARCH && make && make install
done

#Merge the compiled binaries into a single universal one
mkdir -p build/universal
lipo -create $build_files -output build/universal/libdsm.a

#Copy headers across
mkdir build/universal/include
cp -R build/arm64/include build/universal

#Move final product to parent directory
cp -R build/universal ../libdsm
