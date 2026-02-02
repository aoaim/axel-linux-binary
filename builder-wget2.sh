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
# Note: All static libs are needed for fully static linking
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
    gnutls-dev \
    gnutls-static \
    libidn2-dev \
    libidn2-static \
    libpsl-dev \
    libpsl-static \
    libtasn1-dev \
    libtasn1-static \
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
    p11-kit-static \
    pcre2-dev \
    pcre2-static \
    pkgconf \
    python3 \
    texinfo \
    xz \
    xz-dev \
    xz-static \
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

# Clean old generated files
echo "=== Cleaning old generated files ==="
rm -f aclocal.m4 configure config.h.in
rm -rf autom4te.cache
find . -name 'Makefile.in' -delete 2>/dev/null || true

# Ensure m4 directory exists
mkdir -p m4

# Build process with static linking
echo "=== Starting static build process ==="
./bootstrap --skip-po
./configure \
    --disable-shared \
    --enable-static \
    --without-gpgme \
    --without-libmicrohttpd \
    --without-plugin-support \
    CFLAGS="-static" \
    LDFLAGS="-static -all-static"
make -j$(nproc)

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
