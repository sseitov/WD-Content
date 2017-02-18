#!/bin/sh

echo "Pulling lib_fdk ..."
git clone git://github.com/mstorsjo/fdk-aac.git

cd fdk-aac
./autogen.sh
cd ..

CONFIGURE_FLAGS="--enable-static --with-pic=yes --disable-shared"

ARCHS="arm64 x86_64"

# directories
SOURCE="fdk-aac"
FAT="libs"

SCRATCH="fdk-scratch"
# must be an absolute path
THIN=`pwd`/"fdk-thin"

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

		CFLAGS="-arch $ARCH"

		if [ "$ARCH" = "x86_64" ]
		then
		    PLATFORM="AppleTVSimulator"
		    CFLAGS="$CFLAGS -fembed-bitcode"
		    HOST="--host=x86_64-apple-darwin"
		    CPU=
		else
		    PLATFORM="AppleTVOS"
		    CFLAGS="$CFLAGS -fembed-bitcode"
		    HOST="--host=arm-apple-darwin"
		    CPU="--with-cpu=arm64"
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -Werror=unused-command-line-argument"
		AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		$CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    $CPU \
		    CC="$CC" \
		    CXX="$CC" \
		    CPP="$CC -E" \
                    AS="$AS" \
		    CFLAGS="$CFLAGS" \
		    LDFLAGS="$LDFLAGS" \
		    CPPFLAGS="$CFLAGS" \
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
