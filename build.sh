################
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.
################

sudo dnf -y groupinstall "Development Tools"
sudo dnf -y install python \
     ragel \
     byacc \
     flex \
     autoconf \
     automake \
     lbzip2 \
     gettext \
     autogen \
     libtool \
     gperf \
     gettext-devel \
     meson \
     ninja-build \
     gcc-c++ \
     libattr \
     pkg-config \
     which \
     cmake \
     glib2-devel

set -x

. ./env.sh

mkdir -p ${magicprefix}


# copied from:
# https://gist.github.com/kleisauke/acfa1c09522705efa5eb0541d2d00887
cat > "${magicdir}/emscripten-crossfile.meson" <<END
[binaries]
c = 'emcc'
cpp = 'em++'
ld = 'wasm-ld'
ar = 'emar'
ranlib = 'emranlib'
pkgconfig = ['emconfigure', 'pkg-config']
# https://docs.gtk.org/glib/cross-compiling.html#cross-properties
[properties]
growing_stack = true
have_c99_vsnprintf = true
have_c99_snprintf = true
have_unix98_printf = true
# Ensure that '-s PTHREAD_POOL_SIZE=*' is not injected into .pc files
[built-in options]
c_thread_count = 0
cpp_thread_count = 0
[host_machine]
system = 'emscripten'
cpu_family = 'wasm32'
cpu = 'wasm32'
endian = 'little'
END

check_result() {
    if [ $? -eq 0 ]; then
        echo "SEEMS GOOD."
    else
        echo "SHIT HAPPENED."
        exit 42
    fi
    echo "PREVIOUS DIR: " $(pwd)
}

######################
##### zlib
######################

cd ${magicdir}/zlib

emconfigure ./configure --static --prefix=${magicprefix} && \
    emmake make  && \
    emmake make install

check_result
######################
##### libpng
######################

cd ${magicdir}/libpng

cp Makefile.in Makefile.in.original
sed 's/DEFAULT_INCLUDES = .*/DEFAULT_INCLUDES = -I.@am__isrc@ ${CCASFLAGS}/' Makefile.in.original > Makefile.in

emconfigure ./configure --host=${CHOST} --with-binconfigs=no --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS="$(pkg-config --cflags zlib) -s USE_PTHREADS" LDFLAGS="$(pkg-config --libs zlib) -lpthread" --with-pkgconfigdir=${magicprefix}/lib/pkgconfig/ --with-zlib-prefix=${magicprefix} && \
    emmake make && \
    emmake make install

check_result
######################
##### pixman
######################

cd ${magicdir}/pixman

./autogen.sh && \
    emconfigure ./configure --host=${CHOST} --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS' LDFLAGS='-lpthread' && \
    emmake make && \
    emmake make install

check_result
######################
##### freetype
######################

cd ${magicdir}/freetype

./autogen.sh && \
    emconfigure ./configure --host=${CHOST} --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS' LDFLAGS='-lpthread' && \
    emmake make && \
    emmake make install

check_result
######################
##### expat
######################

cd ${magicdir}/libexpat/expat

./buildconf.sh &&
    emconfigure ./configure --without-docbook --host=${CHOST} --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS' LDFLAGS='-lpthread' && \
    emmake make && \
    emmake make install

check_result
######################
##### fontconfig
######################

cd ${magicdir}/fontconfig

emconfigure ./autogen.sh --prefix=${magicprefix} && \
    emconfigure ./configure  --host=${CHOST} --cache-file=enabled --disable-docs --disable-docbook --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS -pthread' LDFLAGS='-lpthread' && \
    emmake make && \
    cp fc-cache/fc-cache  fc-cache/fc-cache-bak && \
    chmod +x fc-cache/fc-cache && \
    echo 'exit 0' > fc-cache/fc-cache && \
    emmake make install

check_result
######################
##### libffi
######################

cd ${magicdir}/libffi
# the latest source code of libffi has already got emscripten support
# https://github.com/libffi/libffi/pull/763
# but not released yet, so ... the latest commit for me is ac598b7
git checkout ac598b7

./autogen.sh && \
    emconfigure ./configure --host=${CHOST} --prefix=${magicprefix} --enable-static --disable-shared --disable-dependency-tracking --disable-builddir --disable-multi-os-directory --disable-raw-api --disable-structs --disable-docs && \
    emmake make && \
    emmake make install SUBDIRS='include'

check_result
######################
##### glib
######################

cd ${magicdir}/glib

CFLAGS='-s USE_PTHREADS' LDFLAGS='-lpthread' meson setup _build --prefix=${magicprefix} --cross-file=$MESON_CROSS --default-library=static --buildtype=release \
  --force-fallback-for=pcre2,gvdb -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dnls=disabled \
  -Dtests=false -Dglib_assert=false -Dglib_checks=false && \
    meson install -C _build

check_result
######################
##### cairo
######################

cd ${magicdir}/cairo

CFLAGS="$(pkg-config --cflags freetype2, fontconfig, expat) -s USE_PTHREADS" LDFLAGS="$(pkg-config --libs freetype2, fontconfig, expat) -lpthread" meson setup _build --prefix=${magicprefix} --cross-file=$MESON_CROSS --default-library=static --buildtype=release -Dtests=disabled && \
    meson install -C _build

check_result
######################
##### harfbuzz
######################

cd ${magicdir}/harfbuzz

./autogen.sh && \
    emconfigure ./configure --host=${CHOST} --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS -pthread' LDFLAGS='-lpthread' && \
    emmake make && \
    emmake make install

check_result
######################
##### reinstall: freetype
##### somebody said I should do this, I don't know why
##### but... fuck it, whatever
######################

cd ${magicdir}/freetype

./autogen.sh && \
    emconfigure ./configure --host=${CHOST} --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS' LDFLAGS='-lpthread' && \
    emmake make && \
    emmake make install

check_result
######################
##### fribidi
######################

cd ${magicdir}/fribidi
sudo chmod +rwx autogen.sh
sudo chmod +rwx c2man/c2man-install/c2man
export PATH=$PATH:${magicdir}/fribidi/c2man/c2man-install

./autogen.sh && \
    emconfigure ./configure --host=${CHOST} --prefix=${magicprefix} --enable-shared=no --disable-dependency-tracking CFLAGS='-s USE_PTHREADS -pthread' LDFLAGS='-lpthread' && \
    emmake make && \
    emmake make install

check_result
######################
##### pango
######################

cd ${magicdir}/pango

# remove test
# because it uses something emscripten don't have?
# like: g_io_channel_unix_new ?
cp meson.build meson.build.original
grep -vwE "subdir\('tests'\)" meson.build.original > meson.build

CFLAGS="$(pkg-config --cflags glib-2.0, cairo, pixman-1, fribidi, freetype2, fontconfig, expat) -s USE_PTHREADS" LDFLAGS="$(pkg-config --libs glib-2.0, cairo, pixman-1, fribidi, freetype2, fontconfig, expat) -lpthread" meson setup _build --prefix=${magicprefix} --cross-file=$MESON_CROSS --default-library=static --buildtype=release -Dintrospection=disabled --force-fallback-for=pcre2,gvdb && \
    CFLAGS="$(pkg-config --cflags glib-2.0, cairo, pixman-1, fribidi, freetype2, fontconfig, expat) -s USE_PTHREADS" LDFLAGS="$(pkg-config --libs glib-2.0, cairo, pixman-1, fribidi, freetype2, fontconfig, expat) -lpthread" meson install -C _build

check_result

######################
##### build emscripten ports
######################

embuilder build sdl2 && \
    embuilder build sdl2_image && \
    embuilder build sdl2_image_jpg && \
    embuilder build sdl2_image_png && \
    embuilder build sdl2_mixer && \
    embuilder build sdl2_mixer_mp3 && \
    embuilder build sdl2_mixer_none && \
    embuilder build sdl2_net && \
    embuilder build sdl2_ttf && \
    embuilder build sdl2_gfx && \
    embuilder build sdl2-mt && \
    embuilder build mpg123 && \
    embuilder build ogg

check_result

