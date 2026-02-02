#!/bin/sh
set -ex

# Arguments
AXEL_TAG=$1
ARCH=$2

if [ -z "$ARCH" ]; then
    echo "Usage: $0 <AXEL_TAG> <ARCH>"
    exit 1
fi

echo "Building Axel version: $AXEL_TAG for architecture: $ARCH"

# Install dependencies (Alpine uses apk)
apk update
apk add --no-cache \
    autoconf \
    autoconf-archive \
    automake \
    build-base \
    curl \
    gettext \
    gettext-dev \
    gettext-static \
    git \
    libtool \
    linux-headers \
    m4 \
    openssl-dev \
    openssl-libs-static \
    pkgconf \
    texinfo \
    txt2man

# Get latest tag if not specified
if [ -z "$AXEL_TAG" ]; then
    AXEL_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/axel-download-accelerator/axel.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

echo "Using Axel tag: $AXEL_TAG"

# Clone the repository
git clone --branch "$AXEL_TAG" --depth 1 https://github.com/axel-download-accelerator/axel.git /tmp/axel-src
cd /tmp/axel-src

# Clean old generated files
echo "=== Cleaning old generated files ==="
rm -f aclocal.m4 configure config.h.in
rm -rf autom4te.cache
find . -name 'Makefile.in' -delete 2>/dev/null || true

# Ensure m4 directory exists
mkdir -p m4

# Fix missing gettext m4 macros
# Alpine's gettext doesn't install all required m4 files, we need to copy them manually
echo "=== Copying gettext m4 macros ==="
for macro in /usr/share/aclocal/gettext*.m4 /usr/share/aclocal/intl*.m4 /usr/share/aclocal/nls.m4 /usr/share/aclocal/po.m4; do
    if [ -f "$macro" ]; then
        cp -v "$macro" m4/
    fi
done

# If AM_GNU_GETTEXT_VERSION is still missing, create a stub
if ! grep -q "AM_GNU_GETTEXT_VERSION" m4/*.m4 2>/dev/null; then
    echo "=== Creating gettext version stub ==="
    cat > m4/gettext-version.m4 << 'EOF'
dnl Stub for AM_GNU_GETTEXT_VERSION when full gettext is not available
AC_DEFUN([AM_GNU_GETTEXT_VERSION], [])
EOF
fi

# Build process with static linking
echo "=== Starting static build process ==="
autoreconf -fiv
./configure \
    CFLAGS="-static" \
    LDFLAGS="-static" \
    LIBS="-lpthread"
make -j$(nproc)

# Verify static linking
echo "=== Verifying static linking ==="
file axel
ldd axel 2>&1 || echo "Binary is statically linked (expected)"

# Prepare output
mkdir -p /output
cp axel /output/axel-"$ARCH"
strip /output/axel-"$ARCH"

echo "Build complete. Binary saved to /output/axel-$ARCH"
ls -lh /output/axel-"$ARCH"
