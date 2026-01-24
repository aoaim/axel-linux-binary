#!/bin/bash
set -ex

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

# Build and install newer autoconf (2.72+ may be required)
echo "=== Building autoconf 2.72 ==="
echo "Current autoconf version: $(autoconf --version | head -1)"
curl -fsSL https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz -o /tmp/autoconf-2.72.tar.xz
tar -xf /tmp/autoconf-2.72.tar.xz -C /tmp
cd /tmp/autoconf-2.72
./configure --prefix=/usr
make
make install
hash -r
echo "New autoconf version: $(autoconf --version | head -1)"
cd /
rm -rf /tmp/autoconf-2.72 /tmp/autoconf-2.72.tar.xz

dnf clean all

if [ ! -x /usr/bin/python ]; then
    ln -s /usr/bin/python3 /usr/bin/python
fi

dnf -y install brotli-devel || dnf -y install libbrotli-devel

# Install gpgme-devel for AM_PATH_GPGME macro
dnf -y install gpgme-devel || true

if [ -z "$WGET2_REF" ]; then
    WGET2_REF=$(git ls-remote --tags --sort="v:refname" https://gitlab.com/gnuwget/wget2.git | tail -n 1 | sed 's@.*/@@;s@\^{}@@')
fi

# Clone the repository
git clone --depth 1 --branch "$WGET2_REF" https://gitlab.com/gnuwget/wget2.git /tmp/wget2-src
cd /tmp/wget2-src

# ============================================
# Autotools 构建问题预防措施
# ============================================

# 1. 清理可能存在的旧生成文件（防止版本不匹配）
echo "=== Cleaning old generated files ==="
rm -f aclocal.m4 configure config.h.in
rm -rf autom4te.cache m4/gnulib-cache.m4 m4/gnulib-comp.m4
find . -name 'Makefile.in' -delete 2>/dev/null || true

# 2. 确保 m4 目录存在
mkdir -p m4

# 3. 复制系统 m4 宏到本地（防止宏找不到）
echo "=== Copying system m4 macros ==="
for macro_dir in /usr/share/aclocal /usr/local/share/aclocal; do
    if [ -d "$macro_dir" ]; then
        # 复制可能需要的宏文件
        for macro in gpgme libtool pkg ax_pthread; do
            if ls "$macro_dir"/${macro}*.m4 >/dev/null 2>&1; then
                cp -n "$macro_dir"/${macro}*.m4 m4/ 2>/dev/null || true
            fi
        done
    fi
done

# 4. 修复 AC_CONFIG_MACRO_DIR 重复问题
# 新版 gnulib 使用 AC_CONFIG_MACRO_DIRS（复数），与旧的 AC_CONFIG_MACRO_DIR 冲突
echo "=== Fixing AC_CONFIG_MACRO_DIR conflicts ==="
if [ -f configure.ac ]; then
    # 统一使用 AC_CONFIG_MACRO_DIRS
    sed -i 's/^AC_CONFIG_MACRO_DIR(\[m4\])/AC_CONFIG_MACRO_DIRS([m4])/' configure.ac
    # 删除重复的宏定义
    awk '!seen[$0]++ || !/AC_CONFIG_MACRO_DIR/' configure.ac > configure.ac.tmp && mv configure.ac.tmp configure.ac
fi

# 5. 设置 ACLOCAL_PATH 包含所有可能的宏目录
export ACLOCAL_PATH="/usr/share/aclocal:/usr/local/share/aclocal:$(pwd)/m4"

# 6. 处理可能缺失的可选功能宏（如 GPGME）
echo "=== Handling optional feature macros ==="
if grep -q "AM_PATH_GPGME" configure.ac && ! [ -f m4/gpgme.m4 ]; then
    # 如果找不到 gpgme.m4，尝试禁用 GPGME 或创建空桩
    if [ -f /usr/share/aclocal/gpgme.m4 ]; then
        cp /usr/share/aclocal/gpgme.m4 m4/
    else
        echo "Warning: gpgme.m4 not found, GPGME support may be disabled"
        # 创建一个桩宏，让 configure 可以继续但禁用 GPGME
        cat > m4/gpgme.m4 << 'GPGME_STUB'
dnl Stub for missing gpgme - will disable GPGME support
AC_DEFUN([AM_PATH_GPGME], [
  AC_MSG_NOTICE([GPGME not available - gpgme.m4 stub])
  $3
])
AC_DEFUN([AM_PATH_GPGME_PTHREAD], [
  AC_MSG_NOTICE([GPGME not available - gpgme.m4 stub])
  $3
])
GPGME_STUB
    fi
fi

# Build process
echo "Starting static build process..."
echo "Using autoconf: $(which autoconf) - $(autoconf --version | head -1)"
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
