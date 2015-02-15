#!/bin/sh

echo "Pulling ..."
git clone git://git.videolan.org/ffmpeg.git ffmpeg

CONFIGURE_FLAGS="--enable-cross-compile --enable-pthreads --disable-ffserver --disable-ffmpeg \
		 --disable-ffprobe --disable-encoders --enable-neon --enable-swscale --enable-avfilter \
		 --disable-zlib --disable-bzlib --disable-debug --enable-gpl --enable-optimizations --enable-pic"

LIBS="libavcodec libavformat libavutil libswscale libavdevice libavfilter \
      libpostproc libswresample"

ARCHS="armv7 armv7s arm64 i386 x86_64"

# directories
SOURCE="ffmpeg"
FAT="libs"
SCRIPT_DIR=$( (cd -P $(dirname $0) && pwd) )

SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"

FDK_AAC=`pwd`/fdk-aac/fdk-aac-ios
if [ "$FDK_AAC" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac --enable-nonfree"
fi

COMPILE="y"
LIPO="y"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CPU=
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=7.0"
		    else
		    	SIMULATOR="-mios-simulator-version-min=5.0"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    if [ $ARCH = "armv7s" ]
		    then
		    	CPU="--cpu=swift"
		    else
		    	CPU=
		    fi
		    SIMULATOR=
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CFLAGS="-arch $ARCH $SIMULATOR"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		if [ "$FDK_AAC" ]
		then
		    CFLAGS="$CFLAGS -I$FDK_AAC/include"
		    LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		fi
		
		# Add smbclient if exists
		SMB_LIB="$SCRIPT_DIR/samba/source3/bin/$ARCH"
		SMB_INC="$SCRIPT_DIR/libs/include"
		CONFIGURE_OPTIONS="--enable-libsmbclient --enable-version3"
		CFLAGS="$CFLAGS -I$SMB_INC"
		LDFLAGS="$LDFLAGS -L$SMB_LIB -ltalloc -ltevent -ltdb -lwbclient -lz -liconv"
		
		ln -s $SMB_LIB/libsmbclient.dylib.0 $SMB_LIB/libsmbclient.dylib
		ln -s $SMB_LIB/libwbclient.dylib.0 $SMB_LIB/libwbclient.dylib
		
		$CWD/$SOURCE/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    $CONFIGURE_FLAGS \
		    $CONFIGURE_OPTIONS \
		    --extra-cflags="$CFLAGS" \
		    --extra-cxxflags="$CXXFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    $CPU \
		    --prefix="$THIN/$ARCH"

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi
