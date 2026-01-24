#!/bin/bash
set -e

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
dnf clean all

# Build and install newer autoconf (2.72+ required by axel)
echo "Building autoconf 2.72..."
curl -fsSL https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz -o /tmp/autoconf-2.72.tar.xz
tar -xf /tmp/autoconf-2.72.tar.xz -C /tmp
cd /tmp/autoconf-2.72
./configure --prefix=/usr/local
make
make install
export PATH="/usr/local/bin:$PATH"
cd /
rm -rf /tmp/autoconf-2.72 /tmp/autoconf-2.72.tar.xz
echo "Autoconf version: $(autoconf --version | head -1)"

if [ -z "$AXEL_TAG" ]; then
    AXEL_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/axel-download-accelerator/axel.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

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
