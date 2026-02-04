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

# Static library install prefix
STATIC_PREFIX=/usr/local

# Install dependencies (Alpine uses apk)
# Use system nettle-static to avoid getopt.c conflict with musl libc
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
    gmp-static \
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
    nettle-dev \
    nettle-static \
    nghttp2-dev \
    nghttp2-static \
    p11-kit-dev \
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
    zstd-static \
    libffi-dev

# Ensure python symlink exists
if [ ! -x /usr/bin/python ]; then
    ln -s /usr/bin/python3 /usr/bin/python
fi

#############################################
# Build GnuTLS dependencies from source
# Use system nettle (avoids getopt.c conflict with musl)
# Build libtasn1 and gnutls from source (no static packages available)
#############################################
echo "=== Building GnuTLS dependencies ==="
echo "Using system nettle: $(pkg-config --modversion nettle 2>/dev/null || echo 'not found')"
echo "Using system hogweed: $(pkg-config --modversion hogweed 2>/dev/null || echo 'not found')"

# Version definitions
LIBTASN1_VERSION="4.19.0"
GNUTLS_VERSION="3.8.3"

# Build libtasn1 (static) - no Alpine static package available
echo "=== Building libtasn1 $LIBTASN1_VERSION ==="
cd /tmp
curl -LO "https://ftp.gnu.org/gnu/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz"
tar xzf libtasn1-${LIBTASN1_VERSION}.tar.gz
cd libtasn1-${LIBTASN1_VERSION}
./configure \
    --prefix=$STATIC_PREFIX \
    --enable-static \
    --disable-shared \
    --disable-doc
make -j$(nproc)
make install

# Build GnuTLS (static) - use system nettle, build libtasn1 from source
echo "=== Building GnuTLS $GNUTLS_VERSION ==="
cd /tmp
curl -LO "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-${GNUTLS_VERSION}.tar.xz"
xz -d gnutls-${GNUTLS_VERSION}.tar.xz
tar xf gnutls-${GNUTLS_VERSION}.tar
cd gnutls-${GNUTLS_VERSION}
./configure \
    --prefix=$STATIC_PREFIX \
    --enable-static \
    --disable-shared \
    --disable-doc \
    --disable-tools \
    --disable-tests \
    --disable-nls \
    --disable-cxx \
    --disable-guile \
    --disable-libdane \
    --without-p11-kit \
    --with-included-unistring \
    LIBTASN1_CFLAGS="-I$STATIC_PREFIX/include" \
    LIBTASN1_LIBS="-L$STATIC_PREFIX/lib -ltasn1"
make -j$(nproc)
make install

# Update PKG_CONFIG_PATH for wget2 to find our static libraries
export PKG_CONFIG_PATH="$STATIC_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
echo "gnutls: $(pkg-config --modversion gnutls 2>/dev/null || echo 'not found')"

#############################################
# Build wget2
#############################################

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
./configure --help | grep -i gnutls || true

# Configure for static build with GnuTLS
# Use system libraries (installed via apk)
./configure \
    --disable-shared \
    --enable-static \
    --with-gnutls=yes \
    --without-openssl \
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
# Need to add all dependencies explicitly for static linking
# Note: p11-kit disabled via --without-p11-kit in GnuTLS configure
make -j$(nproc) LDFLAGS="-static -all-static" \
    LIBS="-lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lidn2 -lunistring -lpsl -lnghttp2 -lbrotlidec -lbrotlicommon -llzma -lz -lbz2 -lpcre2-8 -lpthread"

# Verify static linking
echo "=== Verifying static linking ==="
file src/wget2
ldd src/wget2 2>&1 || echo "Binary is statically linked (expected)"

# Verify HTTPS support
echo "=== Verifying HTTPS support ==="
./src/wget2 --version || true
./src/wget2 --version 2>&1 | grep -i gnutls && echo "GnuTLS support: ENABLED" || echo "GnuTLS support: DISABLED"

# Prepare output
mkdir -p /output
cp src/wget2 /output/wget2-"$ARCH"
strip /output/wget2-"$ARCH"

echo "Build complete. Binary saved to /output/wget2-$ARCH"
ls -lh /output/wget2-"$ARCH"
