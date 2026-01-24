# Axel Auto-Builder

这一仓库旨在利用 GitHub Actions 手动触发构建适用于 `amd64` 和 `arm64` 架构的 Axel 与 Wget2 二进制文件，
方便在没有 root 权限、内核较旧的学校服务器上直接使用。

当你在本仓库手动触发 GitHub Actions 时，将会执行：
1. 自动获取 Axel 与 Wget2 的最新 tag 源码。
2. 在 Docker 容器（Rocky Linux 8 环境）中编译。
3. 自动创建一个以 UTC 日期为版本号的 Release（例如 `20260124`）。
4. 将编译好的二进制文件上传到该 Release 中。

## 使用方法

只需要点一次即可完成构建和发布：

1. **Fork 或 Clone** 本仓库到你的 GitHub 账号。
2. 前往 GitHub 的 **Actions** 页面，选择 "Build and Publish Binaries"。
3. 点击 "Run workflow"。

Release 的版本号将自动使用触发时刻的 UTC 日期（例如 `20260124`）。

稍等片刻，GitHub Actions 将会完成编译，你可以在 Release 的 Assets 中找到：
- `axel-amd64`
- `axel-arm64`
- `wget2-amd64`
- `wget2-arm64`

这些二进制文件**仅适用于 Linux 系统**（amd64 和 arm64 架构）。其中 Wget2 会以静态方式构建，以便携带更多依赖，适合在老系统或精简系统中运行。

> 兼容性提示：构建环境使用 **Rocky Linux 8**，最低支持 **GLIBC 2.28**。这意味着它可以在 Rocky 8/9、AlmaLinux 8/9、CentOS 8/Stream、Debian 11+、Ubuntu 20.04+ 等较新的 Linux 发行版上运行。

## 依赖说明

构建环境基于 `rockylinux:8` 镜像，并安装了以下构建依赖（Axel 和 Wget2 会有不同依赖集）：
- `autoconf`, `autoconf-archive`, `automake`
- `gettext`
- `gcc`, `make`
- `openssl-devel` (支持 SSL/TLS)
- `pkgconf-pkg-config`
- `txt2man`

## 源码来源

源码直接从官方仓库下载：
https://github.com/axel-download-accelerator/axel
