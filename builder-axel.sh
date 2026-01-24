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

# ============================================
# Autotools 构建问题预防措施
# ============================================

# 1. 清理可能存在的旧生成文件（防止版本不匹配）
echo "=== Cleaning old generated files ==="
rm -f aclocal.m4 configure config.h.in
rm -rf autom4te.cache
find . -name 'Makefile.in' -delete 2>/dev/null || true

# 2. 确保 m4 目录存在
mkdir -p m4

# 3. 复制系统 m4 宏到本地（防止宏找不到）
echo "=== Copying system m4 macros ==="
for macro_dir in /usr/share/aclocal /usr/local/share/aclocal; do
    if [ -d "$macro_dir" ]; then
        for macro in pkg ax_pthread ax_check_openssl ax_require_defined; do
            if ls "$macro_dir"/${macro}*.m4 >/dev/null 2>&1; then
                cp -n "$macro_dir"/${macro}*.m4 m4/ 2>/dev/null || true
            fi
        done
    fi
done

# 4. 修复 AC_CONFIG_MACRO_DIR 重复问题（如果存在）
echo "=== Fixing AC_CONFIG_MACRO_DIR conflicts ==="
if [ -f configure.ac ]; then
    # 统一使用 AC_CONFIG_MACRO_DIRS
    sed -i 's/^AC_CONFIG_MACRO_DIR(\[m4\])/AC_CONFIG_MACRO_DIRS([m4])/' configure.ac 2>/dev/null || true
    # 删除重复的宏定义
    if grep -c "AC_CONFIG_MACRO_DIR" configure.ac | grep -q "^[2-9]"; then
        awk '!seen[$0]++ || !/AC_CONFIG_MACRO_DIR/' configure.ac > configure.ac.tmp && mv configure.ac.tmp configure.ac
    fi
fi

# 5. 设置 ACLOCAL_PATH 包含所有可能的宏目录
export ACLOCAL_PATH="/usr/share/aclocal:/usr/local/share/aclocal:$(pwd)/m4"

# 6. 确保 gettext 相关文件存在
if [ -f /usr/share/gettext/po/Makefile.in.in ]; then
    mkdir -p po
    cp -n /usr/share/gettext/po/Makefile.in.in po/ 2>/dev/null || true
fi

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
