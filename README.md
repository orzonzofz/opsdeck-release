# OpsDeck Release - Pre-compiled Binaries

预编译的 OpsDeck 二进制文件和 Docker 镜像发布仓库。

## 📦 使用 Docker 镜像 (推荐)

```bash
# 拉取最新镜像
docker pull ghcr.io/orzonzofz/opsdeck-release:latest

# 运行容器
docker run -d \
  --name opsdeck \
  -p 13113:13113 \
  -v $(pwd)/data:/app/data \
  ghcr.io/orzonzofz/opsdeck-release:latest

# 访问应用
open http://localhost:13113
```

## 🚀 Linux 一键安装脚本

适用于 Linux 系统的自动化安装脚本，支持 systemd 服务管理。

### 系统要求

- Linux 系统（支持 systemd）
- Root 权限
- curl、tar 命令
- x86_64 或 arm64 架构

### 交互式安装（推荐）

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/orzonzofz/opsdeck-release/main/opsdeck.sh
chmod +x install.sh

# 运行交互式菜单
sudo ./install.sh
```

交互菜单功能：
- 1、安装 OpsDeck
- 2、更新 OpsDeck
- 3、卸载 OpsDeck
- 4、查看运行状态
- 5、启动 OpsDeck
- 6、停止 OpsDeck
- 7、重启 OpsDeck
- 8、查看实时日志

### 命令行快速安装

```bash
# 安装到默认路径 /opt/opsdeck
sudo ./install.sh opsdeck

# 安装到自定义路径
sudo ./install.sh opsdeck /usr/local

# 更新到最新版本
sudo ./opsdeck.sh update

# 卸载
sudo ./opsdeck.sh uninstall
```

### 安装后访问

脚本会自动显示访问地址：
- 局域网：`http://your-local-ip:13113/`
- 公网：`http://your-public-ip:13113/`

默认账号：
- 用户名：`admin`
- 密码：`password`

### 服务管理

安装后会自动创建 systemd 服务，可使用以下命令管理：

```bash
# 查看状态
sudo systemctl status opsdeck

# 启动服务
sudo systemctl start opsdeck

# 停止服务
sudo systemctl stop opsdeck

# 重启服务
sudo systemctl restart opsdeck

# 查看日志
sudo journalctl -u opsdeck -f
```

## 💾 下载预编译二进制

在 [Releases](https://github.com/orzonzofz/opsdeck-release/releases) 页面下载:

- `opsdeck-linux-amd64-vX.X.X.tar.gz` - Linux x86_64
- `opsdeck-linux-arm64-vX.X.X.tar.gz` - Linux ARM64  
- `opsdeck-macos-arm64-vX.X.X.tar.gz` - macOS Apple Silicon
- `opsdeck-windows-amd64-vX.X.X.zip` - Windows x64

### 快速使用

**Linux/macOS:**
```bash
tar -xzf opsdeck-linux-amd64-v1.0.0.tar.gz
chmod +x opsdeck-linux-amd64-v1.0.0
./opsdeck-linux-amd64-v1.0.0
```

**Windows:**
解压 zip 文件后双击运行 `opsdeck-windows-amd64-v1.0.0.exe`

## ⚙️ 环境变量配置

所有配置都是可选的，不设置时会使用默认值。可以通过 `.env` 文件或环境变量进行配置。

### 服务器配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | 13113 | 服务器监听端口 |

### 数据库配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DATABASE_URL` | sqlite:./data/database.db?mode=rwc | 数据库连接地址 |

### JWT 密钥配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `JWT_SECRET` | your-secret-key-change-in-production | JWT加密密钥，**生产环境务必更改！** |

### 默认管理员账号

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ADMIN_USERNAME` | admin | 管理员用户名（首次运行时创建） |
| `ADMIN_PASSWORD` | password | 管理员密码（首次运行时创建） |

> 💡 如果设置了环境变量，首次创建时会使用环境变量的值保存到数据库

### 日志配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `RUST_LOG` | info | 日志级别：trace, debug, info, warn, error |

> 💡 详细的日志配置，例如：`opsdeck=info,sqlx=warn,tower_http=warn` 

### 浏览器配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CHROME_PATH` | - | 浏览器路径（可选）<br>• 不设置时会自动下载 Chromium 到 `./data/browsers` 目录<br>• 也可以手动指定系统浏览器路径 |
| `BROWSER_HEADLESS` | true | 浏览器模式<br>• true: 无头模式（后台运行，默认）<br>• false: 有头模式（显示窗口，用于调试） |
| `BROWSER_ENABLE_IMAGES` | false | 图片加载<br>• true: 启用图片<br>• false: 禁用图片（默认，可提高性能） |
| `BROWSER_WINDOW_WIDTH` | 1440 | 窗口宽度（有头模式时生效） |
| `BROWSER_WINDOW_HEIGHT` | 900 | 窗口高度（有头模式时生效） |
| `BROWSER_VIEWPORT_WIDTH` | 1440 | 视口宽度（网页显示区域） |
| `BROWSER_VIEWPORT_HEIGHT` | 900 | 视口高度（网页显示区域） |
| `MAX_CONCURRENT_BROWSERS` | 5 | 浏览器最大并发数（同时运行的实例数量） |

### 示例配置文件

创建 `.env` 文件：

```bash
# 服务器配置
PORT=13113

# 数据库配置
DATABASE_URL=sqlite:./data/database.db?mode=rwc

# JWT 密钥（生产环境务必更改！）
JWT_SECRET=your-strong-secret-key-here

# 管理员账号
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password

# 日志级别
LOG_LEVEL=info

# 浏览器配置
BROWSER_HEADLESS=true
BROWSER_ENABLE_IMAGES=false
MAX_CONCURRENT_BROWSERS=5

```

## 🆘 获取帮助

- 问题反馈: [Issues](https://github.com/orzonzofz/opsdeck-release/issues)
- 详细文档: 见各版本 Release 说明
