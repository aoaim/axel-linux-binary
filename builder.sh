#!/bin/bash
set -e

# Arguments
AXEL_TAG=$1
ARCH=$2

if [ -z "$ARCH" ]; then
    echo "Usage: $0 <AXEL_TAG> <ARCH>"
    exit 1
fi

if [ -z "$AXEL_TAG" ]; then
    AXEL_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/axel-download-accelerator/axel.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

echo "Building Axel version: $AXEL_TAG for architecture: $ARCH"

# Install dependencies
dnf -y install epel-release
/usr/bin/crb enable
dnf -y install \
    autoconf \
    autoconf-archive \
    automake \
    gettext \
    gcc \
    make \
    openssl-devel \
    pkgconf-pkg-config \
    txt2man \
    git \
    ca-certificates
dnf clean all

# Clone the repository
git clone --branch "$AXEL_TAG" --depth 1 https://github.com/axel-download-accelerator/axel.git /tmp/axel-src
cd /tmp/axel-src

# Build process
echo "Starting static build process..."
autoreconf -i
./configure CPPFLAGS="-DHAVE_ASN1_STRING_GET0_DATA"
make

# prepare output
mkdir -p /output
cp axel /output/axel-"$ARCH"
strip /output/axel-"$ARCH"

echo "Build complete. Binary saved to /output/axel-$ARCH"
ls -lh /output/axel-"$ARCH"
