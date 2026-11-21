#!/bin/bash
# Builds Wine 11.0 from source for x86_64 macOS (runs under Rosetta 2), new-style WoW64,
# PE side compiled with mingw-w64.
# Usage:  arch -x86_64 /bin/bash build/build-wine.sh [configure|make|install|all]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
SRC="$HERE/sources/wine"
OBJ="$HERE/obj"
OUT="$ROOT/runtime/wine-cx"
XLIB="$ROOT/runtime/wine/lib"        # x86_64 FreeType, GnuTLS, SDL2, MoltenVK from the prebuilt Wine package
BREW=/opt/homebrew                    # headers and tools (arm64 Homebrew)
JOBS="$(sysctl -n hw.ncpu)"

[ "$(uname -m)" = "x86_64" ] || { echo "run as: arch -x86_64 /bin/bash $0" >&2; exit 1; }

export PATH="$BREW/opt/bison/bin:$BREW/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MACOSX_DEPLOYMENT_TARGET=10.15
# Keep pkg-config from handing us arm64 Homebrew libraries.
export PKG_CONFIG_LIBDIR=/nonexistent PKG_CONFIG_PATH=

WARN="-Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-int-conversion -Wno-deprecated-declarations"

do_configure() {
  mkdir -p "$OBJ"; cd "$OBJ"
  # The ac_cv_lib_soname_* values are preseeded because configure cannot parse the bare
  # install names of the prebuilt dylibs (it records garbage, and dlopen then fails).
  "$SRC/configure" \
    --prefix="$OUT" \
    --enable-archs=i386,x86_64 \
    --disable-tests \
    --with-mingw --with-freetype --with-gnutls --with-sdl --with-vulkan --with-coreaudio \
    --without-x --without-alsa --without-capi --without-dbus --without-oss --without-pulse \
    --without-udev --without-v4l2 --without-gphoto --without-sane --without-cups --without-krb5 \
    --without-netapi --without-pcap --without-usb --without-gstreamer --without-inotify \
    --without-gettext --without-fontconfig --without-opencl --without-pcsclite --without-unwind \
    CC="clang" CXX="clang++" \
    CFLAGS="-O2 $WARN" CXXFLAGS="-O2" CROSSCFLAGS="-O2" \
    FREETYPE_CFLAGS="-I$BREW/opt/freetype/include/freetype2" FREETYPE_LIBS="-L$XLIB -lfreetype" \
    GNUTLS_CFLAGS="-I$BREW/opt/gnutls/include -I$BREW/opt/nettle/include -I$BREW/opt/libtasn1/include -I$BREW/opt/p11-kit/include/p11-kit-1" GNUTLS_LIBS="-L$XLIB -lgnutls" \
    SDL2_CFLAGS="-I$BREW/opt/sdl2/include/SDL2 -D_THREAD_SAFE" SDL2_LIBS="-L$XLIB -lSDL2" \
    ac_cv_lib_soname_MoltenVK=libMoltenVK.dylib ac_cv_lib_soname_vulkan= \
    ac_cv_lib_soname_SDL2=libSDL2-2.0.0.dylib \
    ac_cv_lib_soname_freetype=libfreetype.6.dylib \
    ac_cv_lib_soname_gnutls=libgnutls.30.dylib
}

do_make() {
  cd "$OBJ"
  # The sfnt2fon build tool links FreeType by a bare name; dyld finds it in the working directory.
  ln -sf "$XLIB/libfreetype.6.dylib" "$OBJ/libfreetype.dylib"
  make -j"$JOBS"
}

do_install() { cd "$OBJ"; rm -rf "$OUT"; make -j"$JOBS" install >/dev/null; }

case "${1:-all}" in
  configure) do_configure ;;
  make)      do_make ;;
  install)   do_install ;;
  all)       do_configure; do_make; do_install ;;
esac
