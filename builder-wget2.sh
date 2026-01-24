#!/bin/bash
set -e

# Arguments
WGET2_REF=$1
ARCH=$2

if [ -z "$ARCH" ]; then
    echo "Usage: $0 <WGET2_REF> <ARCH>"
    exit 1
fi

echo "Building Wget2 ref: $WGET2_REF for architecture: $ARCH"

# Install dependencies
dnf -y install epel-release
/usr/bin/crb enable
dnf -y install \
    autoconf \
    autoconf-archive \
    automake \
    bzip2 \
    bzip2-devel \
    ca-certificates \
    curl \
    diffutils \
    flex \
    findutils \
    gcc \
    gcc-c++ \
    gettext \
    gettext-common-devel \
    gettext-devel \
    git \
    glibc-static \
    gmp-devel \
    gnutls-devel \
    libidn2-devel \
    libnghttp2-devel \
    libpsl-devel \
    libtasn1-devel \
    libstdc++-static \
    libtool \
    libunistring-devel \
    libzstd-devel \
    m4 \
    make \
    nettle-devel \
    pcre2-devel \
    perl \
    pkgconf-pkg-config \
    python3 \
    rsync \
    tar \
    texinfo \
    lzip \
    xz \
    xz-devel \
    zlib-devel
dnf clean all

# Build and install newer autoconf (2.72+ may be required)
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

if [ ! -x /usr/bin/python ]; then
    ln -s /usr/bin/python3 /usr/bin/python
fi

dnf -y install brotli-devel || dnf -y install libbrotli-devel

if [ -z "$WGET2_REF" ]; then
    WGET2_REF=$(git ls-remote --tags --sort="v:refname" https://gitlab.com/gnuwget/wget2.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

# Clone the repository
git clone --depth 1 --branch "$WGET2_REF" https://gitlab.com/gnuwget/wget2.git /tmp/wget2-src
cd /tmp/wget2-src

# Build process
echo "Starting static build process..."
./bootstrap
./configure \
    --disable-shared \
    --enable-static \
    LDFLAGS="-static"
make

# prepare output
mkdir -p /output
cp src/wget2 /output/wget2-"$ARCH"
strip /output/wget2-"$ARCH"

echo "Build complete. Binary saved to /output/wget2-$ARCH"
ls -lh /output/wget2-"$ARCH"
