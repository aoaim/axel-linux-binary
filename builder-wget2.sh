#!/bin/sh
set -ex

# Arguments
WGET2_REF=$1
ARCH=$2

if [ -z "$ARCH" ]; then
    echo "Usage: $0 <WGET2_REF> <ARCH>"
    exit 1
fi

echo "Building Wget2 ref: $WGET2_REF for architecture: $ARCH"

# Install dependencies (Alpine uses apk)
# Note: wget2 uses GnuTLS for SSL/TLS, but Alpine has no gnutls-static package
# So this build will NOT have HTTPS support. For HTTPS, use traditional wget 1.x
apk update
apk add --no-cache \
    autoconf \
    autoconf-archive \
    automake \
    brotli-dev \
    brotli-static \
    build-base \
    bzip2-dev \
    bzip2-static \
    curl \
    flex \
    gettext \
    gettext-dev \
    gettext-static \
    git \
    gmp-dev \
    libidn2-dev \
    libidn2-static \
    libpsl-dev \
    libpsl-static \
    libtool \
    libunistring-dev \
    libunistring-static \
    linux-headers \
    lzip \
    m4 \
    nghttp2-dev \
    nghttp2-static \
    openssl-dev \
    openssl-libs-static \
    pcre2-dev \
    pcre2-static \
    pkgconf \
    python3 \
    rsync \
    texinfo \
    xz-static \
    xz \
    xz-dev \
    zlib-dev \
    zlib-static \
    zstd-dev \
    zstd-static

# Ensure python symlink exists
if [ ! -x /usr/bin/python ]; then
    ln -s /usr/bin/python3 /usr/bin/python
fi

# Get latest tag if not specified
if [ -z "$WGET2_REF" ]; then
    WGET2_REF=$(git ls-remote --tags --sort="v:refname" https://gitlab.com/gnuwget/wget2.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

echo "Using Wget2 tag: $WGET2_REF"

# Clone the repository
git clone --depth 1 --branch "$WGET2_REF" https://gitlab.com/gnuwget/wget2.git /tmp/wget2-src
cd /tmp/wget2-src

# Fix AC_CONFIG_MACRO_DIR conflict BEFORE bootstrap
# The configure.ac has multiple AC_CONFIG_MACRO_DIR which conflicts with gnulib
echo "=== Fixing AC_CONFIG_MACRO_DIR conflict ==="
if [ -f configure.ac ]; then
    # Remove duplicate AC_CONFIG_MACRO_DIR, keep only AC_CONFIG_MACRO_DIRS
    sed -i 's/^AC_CONFIG_MACRO_DIR(\[m4\])$/dnl AC_CONFIG_MACRO_DIR([m4])/' configure.ac
    # Ensure we use AC_CONFIG_MACRO_DIRS (plural) if not already present
    if ! grep -q "AC_CONFIG_MACRO_DIRS" configure.ac; then
        sed -i 's/^dnl AC_CONFIG_MACRO_DIR(\[m4\])$/AC_CONFIG_MACRO_DIRS([m4])/' configure.ac
    fi
fi

# Build process
echo "=== Starting static build process ==="
./bootstrap --skip-po

# Check available SSL options
echo "=== Checking configure options ==="
./configure --help | grep -i ssl || true
./configure --help | grep -i openssl || true
./configure --help | grep -i gnutls || true

# Configure for static build
# NOTE: SSL/TLS support is disabled because:
# - wget2 uses GnuTLS for HTTPS (not OpenSSL)
# - Alpine Linux has no gnutls-static package
# - --with-openssl only provides hash functions, not HTTPS
# DO NOT use -static in CFLAGS during configure (breaks compiler test)
./configure \
    --disable-shared \
    --enable-static \
    --with-openssl=yes \
    --without-gnutls \
    --without-gpgme \
    --without-libmicrohttpd \
    --without-plugin-support \
    LDFLAGS="-static"

# Fix musl libc compatibility issue
# In musl, pthread_t is 'struct __pthread *', but wget_thread_id_t is 'unsigned long'
# This causes a type mismatch error in thread.c
echo "=== Applying musl libc pthread_t compatibility patch ==="
if [ -f libwget/thread.c ]; then
    sed -i 's/return gl_thread_self();/return (wget_thread_id_t)(uintptr_t)gl_thread_self();/' libwget/thread.c
    echo "Patched libwget/thread.c for musl compatibility"
fi

# Build with static linking
# Need to add all dependencies explicitly for static linking:
# - Compression: zlib, lzma, brotli (dec+common), bzip2
# - IDN: libidn2, libunistring
# - HTTP/2: nghttp2
# - PSL: libpsl
make -j$(nproc) LDFLAGS="-static -all-static" \
    LIBS="-lidn2 -lunistring -lpsl -lnghttp2 -lbrotlidec -lbrotlicommon -llzma -lz -lbz2 -lpcre2-8"

# Verify static linking
echo "=== Verifying static linking ==="
file src/wget2
ldd src/wget2 2>&1 || echo "Binary is statically linked (expected)"

# Prepare output
mkdir -p /output
cp src/wget2 /output/wget2-"$ARCH"
strip /output/wget2-"$ARCH"

echo "Build complete. Binary saved to /output/wget2-$ARCH"
ls -lh /output/wget2-"$ARCH"
