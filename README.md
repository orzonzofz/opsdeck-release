# OpsDeck Release

预编译的 OpsDeck 二进制文件与 Docker 镜像发布仓库。

## Docker 运行

### Docker CLI

```bash
docker pull xrbzy/opsdeck:latest

docker run -d \
  --name opsdeck \
  --init \
  --pull=always \
  -p 13113:13113 \
  --log-opt max-size=10m \
  --log-opt max-file=7 \
  -v $(pwd)/data:/app/data \
  xrbzy/opsdeck:latest
```

访问：

```bash
http://localhost:13113
```

### Docker Compose

创建 `docker-compose.yml`：

```yaml
services:
  opsdeck:
    image: xrbzy/opsdeck:latest
    container_name: opsdeck
    init: true
    ports:
      - "13113:13113"
    volumes:
      - ./data:/app/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "7"
    restart: unless-stopped
```

启动：

```bash
docker compose up -d
```

## Linux 一键安装脚本

适用于 Linux 系统的自动化安装脚本，支持 systemd 服务管理。  
当前仅支持 `Debian 12` 和 `Ubuntu 24.04` 直装；其它系统版本或架构建议直接使用 Docker。
脚本会在安装和更新前自动校验当前系统、CPU 架构以及对应 Release 资产是否存在。

### 系统要求

- Linux 系统（支持 systemd）
- Root 权限
- `curl`、`tar`
- `x86_64` 或 `arm64`
- OpenCV 4.6 运行时依赖

### 交互式安装

```bash
curl -O https://raw.githubusercontent.com/orzonzofz/opsdeck-release/main/opsdeck.sh
chmod +x opsdeck.sh
sudo ./opsdeck.sh
```

### 命令行安装

```bash
sudo ./opsdeck.sh install
sudo ./opsdeck.sh update
sudo ./opsdeck.sh uninstall
```

### 服务管理

```bash
sudo systemctl status opsdeck
sudo systemctl start opsdeck
sudo systemctl stop opsdeck
sudo systemctl restart opsdeck
sudo journalctl -u opsdeck -f
```

## 预编译二进制

在 [Releases](https://github.com/orzonzofz/opsdeck-release/releases) 页面下载：

- `opsdeck-linux-amd64-vX.X.X.tar.gz`
- `opsdeck-linux-arm64-vX.X.X.tar.gz`
- `opsdeck-macos-arm64-vX.X.X.tar.gz`

### 运行时依赖

Docker 镜像已内置运行时依赖；只有直接运行二进制文件时，才需要先安装系统依赖。

**Ubuntu / Debian（最稳安装）**

```bash
sudo apt-get update
sudo apt-get install -y libopencv-dev
```

**Debian 12（最精简运行时）**

```bash
sudo apt-get update
sudo apt-get install -y \
  libopencv-core406 \
  libopencv-imgproc406 \
  libopencv-imgcodecs406 \
  libopencv-features2d406 \
  libopencv-flann406 \
  libopencv-calib3d406
```

**Ubuntu 24.04（最精简运行时）**

```bash
sudo apt-get update
sudo apt-get install -y \
  libopencv-core406t64 \
  libopencv-imgproc406t64 \
  libopencv-imgcodecs406t64 \
  libopencv-features2d406t64 \
  libopencv-flann406t64 \
  libopencv-calib3d406t64
```

**macOS ARM64**

```bash
brew install opencv
```

除 Debian 12 / Ubuntu 24.04 / macOS ARM64 外，其它系统版本或架构建议直接使用 Docker。

### 快速启动

**Linux**

```bash
tar -xzf opsdeck-linux-amd64-v1.0.0.tar.gz
chmod +x opsdeck-linux-amd64-v1.0.0
./opsdeck-linux-amd64-v1.0.0
```

**macOS**

```bash
tar -xzf opsdeck-macos-arm64-v1.0.0.tar.gz
chmod +x opsdeck-macos-arm64-v1.0.0
./opsdeck-macos-arm64-v1.0.0
```

## 首次启动说明

- 首次启动会自动创建管理员账号
- 默认用户名是 `admin`
- 如果没有设置 `ADMIN_PASSWORD`，程序会生成一次随机密码并写入数据库
- 随机密码会在首次初始化日志中输出
- 后续再次重启时，会优先使用数据库里已经保存的管理员账号配置

如果你想指定初始密码，建议在首次启动前设置环境变量：

```bash
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-strong-password
```

## 环境变量

所有配置均为可选项，不设置时会使用默认值。

### 基础配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | `13113` | 服务监听端口 |
| `DATABASE_URL` | `sqlite:./data/database.db?mode=rwc` | 数据库连接地址 |
| `RUST_LOG` | `opsdeck=info,sqlx=warn,tower_http=warn` | 日志级别 |

### 管理员初始化

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ADMIN_USERNAME` | `admin` | 仅在数据库还没有管理员配置时生效 |
| `ADMIN_PASSWORD` | 未设置 | 仅在数据库还没有管理员配置时生效；不设置则首次启动随机生成 |
| `ADMIN_SESSION_COOKIE_SECURE` | `true` | 后台登录 Cookie 默认开启 `Secure`；仅显式设置为 `false` 才关闭 |

### 授权配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `LICENSE_KEY` | 未设置 | 可选；不设置时可在前端后台填写 |

### 其他配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_ERROR_SCREENSHOT` | `false` | 失败时自动截图 |

### 示例

```bash
PORT=13113
DATABASE_URL=sqlite:./data/database.db?mode=rwc
RUST_LOG=opsdeck=info,sqlx=warn,tower_http=warn

ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-strong-password

```

## 获取帮助

- 问题反馈：[Issues](https://github.com/orzonzofz/opsdeck-release/issues)
- 版本说明：见各版本 Release 页面
