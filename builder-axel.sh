#!/bin/bash
set -ex

# Arguments
AXEL_TAG=$1
ARCH=$2

if [ -z "$ARCH" ]; then
    echo "Usage: $0 <AXEL_TAG> <ARCH>"
    exit 1
fi

echo "Building Axel version: $AXEL_TAG for architecture: $ARCH"

# Install dependencies
dnf -y install epel-release
/usr/bin/crb enable
dnf -y install \
    autoconf \
    autoconf-archive \
    automake \
    curl \
    diffutils \
    gettext \
    gettext-common-devel \
    gettext-devel \
    findutils \
    gcc \
    make \
    openssl-devel \
    pkgconf-pkg-config \
    tar \
    texinfo \
    txt2man \
    git \
    ca-certificates \
    perl \
    m4 \
    xz

# Clean dnf cache first
dnf clean all

# Build and install newer autoconf (2.72+ required by axel)
echo "=== Building autoconf 2.72 ==="
echo "Current autoconf version: $(autoconf --version | head -1)"
cd /tmp
curl -fsSL https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz -o autoconf-2.72.tar.xz
tar -xf autoconf-2.72.tar.xz
cd autoconf-2.72
./configure --prefix=/usr
make -j$(nproc)
make install
hash -r
cd /
rm -rf /tmp/autoconf-2.72 /tmp/autoconf-2.72.tar.xz
echo "New autoconf version: $(autoconf --version | head -1)"
autoconf --version

if [ -z "$AXEL_TAG" ]; then
    AXEL_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/axel-download-accelerator/axel.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

# Clone the repository
git clone --branch "$AXEL_TAG" --depth 1 https://github.com/axel-download-accelerator/axel.git /tmp/axel-src
cd /tmp/axel-src

# Build process
echo "Starting static build process..."
echo "Using autoconf: $(which autoconf) - $(autoconf --version | head -1)"
autoreconf -i
./configure CPPFLAGS="-DHAVE_ASN1_STRING_GET0_DATA"
make

# prepare output
mkdir -p /output
cp axel /output/axel-"$ARCH"
strip /output/axel-"$ARCH"

echo "Build complete. Binary saved to /output/axel-$ARCH"
ls -lh /output/axel-"$ARCH"
