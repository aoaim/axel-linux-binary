# axel & wget2 Auto-Builder

部分生信任务我需要在学校的高性能计算平台上进行。从 NCBI 上下载数据非常慢，从欧洲镜像下载更方便，但是是平台没有安装 `axel` 和 `wget2`，没法榨干网络带宽。我当然也没有 `root` 权限去安装这两个包。因此有了这个仓库。

这个仓库 GitHub Actions 自动构建适用于 `amd64` 和 `arm64` 架构的 **axel** 与 **wget2** 静态二进制文件，方便在没有 root 权限的服务器上直接使用。

当你在本仓库**手动触发**或**等待定时任务**运行时，将会执行：
1. 自动获取 `axel` 与 `wget2` 的最新 tag 源码。
2. 在 Docker 容器（Alpine Linux 环境）中使用 **musl libc** 静态编译。
3. 自动创建一个以 UTC 日期为版本号的 Release（例如 `20260124`）。
4. 将编译好的二进制文件上传到该 Release 中。

此外，工作流每周会自动检查一次上游 `axel`/`wget2` 是否有新 tag；只要其中一个有更新，就会自动触发构建并发布新的 Release。

## 使用方法

两种方式都支持：

- **手动**：进入 Actions 点一次 "Run workflow"。
- **自动**：每周一 03:00 UTC 自动检查更新并构建发布。

手动触发只需要点一次即可完成构建和发布：

1. **Fork 或 Clone** 本仓库到你的 GitHub 账号。
2. 前往 GitHub 的 **Actions** 页面，选择 "Build and Publish Binaries"。
3. 点击 "Run workflow"。

Release 的版本号将自动使用触发时刻的 UTC 日期（例如 `20260124`）。

稍等片刻，GitHub Actions 将会完成编译，你可以在 Release 的 Assets 中找到：
- `axel-amd64`
- `axel-arm64`
- `wget2-amd64`
- `wget2-arm64`

## 兼容性

这些二进制文件**仅适用于 Linux 系统**（amd64 和 arm64 架构）。

> **完全静态链接**：使用 Alpine Linux + musl libc 编译，产出的二进制没有任何动态库依赖，可以在几乎所有 Linux 发行版上运行，包括：
> - CentOS 7/8/9、Rocky Linux、AlmaLinux
> - Debian 9+、Ubuntu 16.04+
> - 任何 Linux 内核 2.6.39+ 的系统

验证方式：
```bash
$ file axel-amd64
axel-amd64: ELF 64-bit LSB executable, x86-64, statically linked, ...

$ ldd axel-amd64
not a dynamic executable
```

## 构建环境

构建环境基于 `alpine:latest` 镜像，使用 musl libc 进行静态链接。主要依赖包括：
- `build-base`（gcc, make 等）
- `autoconf`, `autoconf-archive`, `automake`, `libtool`
- `openssl-dev`, `openssl-libs-static`
- `gnutls-dev`, `brotli-dev`, `zstd-dev` 等（用于 wget2）

## 源码来源

- **axel**: https://github.com/axel-download-accelerator/axel
- **wget2**: https://gitlab.com/gnuwget/wget2
