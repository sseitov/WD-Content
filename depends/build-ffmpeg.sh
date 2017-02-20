#!/bin/sh

echo "Pulling ..."

#git clone git://git.videolan.org/ffmpeg.git ffmpeg

CONFIGURE_FLAGS="--enable-cross-compile --enable-pthreads --disable-ffserver --disable-ffmpeg \
		 --disable-ffprobe --disable-encoders --enable-neon --enable-swscale --enable-avfilter \
		 --disable-zlib --disable-bzlib --disable-debug --enable-optimizations --enable-pic \
		 --extra-cflags=-fembed-bitcode --extra-cxxflags=-fembed-bitcode"

LIBS="libavcodec libavformat libavutil libswscale libavdevice libavfilter \
      libpostproc libswresample"

ARCHS="armv7 arm64"

# directories
SOURCE="ffmpeg-3.0.2"
FAT="libs"
SCRIPT_DIR=$( (cd -P $(dirname $0) && pwd) )

SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"
FDK_AAC=`pwd`/"libs"

COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="9.0"

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
	if [ ! `which yasm` ]
	then
	    echo 'Yasm not found'
	    if [ ! `which brew` ]
	    then
		echo 'Homebrew not found. Trying to install...'
		ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)" \
		    || exit 1
	    fi
	    echo 'Trying to install Yasm...'
	    brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
	    echo 'gas-preprocessor.pl not found. Trying to install...'
	    (curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
		-o /usr/local/bin/gas-preprocessor.pl \
		&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
		|| exit 1
	fi
	
	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
			|| exit 1
	fi
	
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"
		
		# Add smbclient if exists
		SMB_LIB="$SCRIPT_DIR/samba/source3/bin/$ARCH"
		SMB_INC="$SCRIPT_DIR/libs/include"
		CONFIGURE_OPTIONS="--enable-libsmbclient --enable-version3"
		CFLAGS="$CFLAGS -I$SMB_INC"
		LDFLAGS="$LDFLAGS -L$SMB_LIB -ltalloc -ltevent -ltdb -lwbclient -lz -liconv"
		
		ln -s $SMB_LIB/libsmbclient.dylib.0 $SMB_LIB/libsmbclient.dylib
		ln -s $SMB_LIB/libwbclient.dylib.0 $SMB_LIB/libwbclient.dylib
		
		CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --enable-gpl --enable-nonfree --enable-libfdk-aac"
		CFLAGS="$CFLAGS -I$FDK_AAC/include"
		LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		
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
