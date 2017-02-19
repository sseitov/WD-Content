#!/bin/sh

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

ARCHS="arm64 x86_64"

# directories
SOURCE="x264"
FAT="libs"

SCRATCH="x264-scratch"
# must be an absolute path
THIN=`pwd`/"x264-thin"

# the one included in x264 does not work; specify full path to working one
GAS_PREPROCESSOR=/usr/local/bin/gas-preprocessor.pl

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
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
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
		echo 'x264 source not found. Pulling x264 ...'
		git clone -b stable git://git.videolan.org/x264.git
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"
		CFLAGS="-arch $ARCH"
        ASFLAGS=

		if [ "$ARCH" = "x86_64" ]
		then
		    PLATFORM="AppleTVSimulator"
		    CFLAGS="$CFLAGS -mtvos-simulator-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    HOST="--host=x86_64-apple-darwin"
		else
		    PLATFORM="AppleTVOS"
		    CFLAGS="$CFLAGS -mtvos-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    HOST="--host=aarch64-apple-darwin"
			XARCH="-arch aarch64"
            ASFLAGS="$CFLAGS"
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		if [ $PLATFORM = "AppleTVOS" ]
		then
		    export AS="gas-preprocessor.pl $XARCH -- $CC"
		else
		    export -n AS
		fi
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    --extra-cflags="$CFLAGS" \
		    --extra-asflags="$ASFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" || exit 1

		mkdir extras
		ln -s $GAS_PREPROCESSOR extras

		make -j3 install || exit 1
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
