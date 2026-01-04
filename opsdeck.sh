#!/bin/bash
###############################################################################
#
# OpsDeck Manager Script
#
# Version: 1.0.0
# Last Updated: 2025-12-15
#
# Description: 
#   A management script for OpsDeck
#   Provides installation, update, uninstallation and management functions
#
# Requirements:
#   - Linux with systemd
#   - Root privileges for installation
#   - curl, tar
#   - x86_64 or arm64 architecture
#
###############################################################################

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    exit ${exit_code}
}

# 检查必要命令
if ! command -v curl >/dev/null 2>&1; then
    handle_error 1 "未找到 curl 命令，请先安装"
fi

# 配置部分
GH_REPO="orzonzofz/opsdeck-release"
GH_DOWNLOAD_URL="https://github.com/${GH_REPO}/releases/latest/download"

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
RES='\e[0m'

# 获取已安装路径
GET_INSTALLED_PATH() {
    if [ -f "/etc/systemd/system/opsdeck.service" ]; then
        installed_path=$(grep "WorkingDirectory=" /etc/systemd/system/opsdeck.service | cut -d'=' -f2)
        if [ -f "$installed_path/opsdeck" ]; then
            echo "$installed_path"
            return 0
        fi
    fi
    echo "/opt/opsdeck"
}

# 设置安装路径
if [ ! -n "$2" ]; then
    INSTALL_PATH='/opt/opsdeck'
else
    INSTALL_PATH=${2%/}
    if ! [[ $INSTALL_PATH == */opsdeck ]]; then
        INSTALL_PATH="$INSTALL_PATH/opsdeck"
    fi
    
    parent_dir=$(dirname "$INSTALL_PATH")
    if [ ! -d "$parent_dir" ]; then
        mkdir -p "$parent_dir" || handle_error 1 "无法创建目录 $parent_dir"
    fi
    
    if ! [ -w "$parent_dir" ]; then
        handle_error 1 "目录 $parent_dir 没有写入权限"
    fi
fi

# 如果是更新或卸载操作，使用已安装的路径
if [ "$1" = "update" ] || [ "$1" = "uninstall" ]; then
    INSTALL_PATH=$(GET_INSTALLED_PATH)
fi

clear

# 获取平台架构
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

ARCH="UNKNOWN"

if [ "$platform" = "x86_64" ]; then
  ARCH=amd64
elif [ "$platform" = "aarch64" ]; then
  ARCH=arm64
fi

# 权限和环境检查
if [ "$(id -u)" != "0" ]; then
  if [ "$1" = "install" ] || [ "$1" = "update" ] || [ "$1" = "uninstall" ]; then
    echo -e "\r\n${RED_COLOR}错误：请使用 root 权限运行此命令！${RES}\r\n"
    echo -e "提示：使用 ${GREEN_COLOR}sudo $0 $1${RES} 重试\r\n"
    exit 1
  fi
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，一键安装目前仅支持 x86_64 和 arm64 平台。\r\n"
  exit 1
elif ! command -v systemctl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，无法确定你当前的 Linux 发行版。\r\n建议手动安装。\r\n"
  exit 1
fi

# 检查并终止占用 apt 锁的进程
kill_apt_processes() {
  # 查找占用 apt 锁的进程
  local pids=$(lsof /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
  
  if [ -z "$pids" ]; then
    # 尝试用 fuser
    pids=$(fuser /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock 2>/dev/null | tr ' ' '\n' | sort -u)
  fi
  
  if [ -n "$pids" ]; then
    echo -e "${YELLOW_COLOR}发现以下进程占用 apt 锁：${RES}"
    for pid in $pids; do
      local cmd=$(ps -p $pid -o comm= 2>/dev/null)
      echo -e "  PID: $pid ($cmd)"
    done
    echo -e "${YELLOW_COLOR}正在终止这些进程...${RES}"
    for pid in $pids; do
      kill -9 $pid 2>/dev/null
    done
    sleep 2
    # 清理锁文件
    rm -f /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock 2>/dev/null
    dpkg --configure -a 2>/dev/null
    echo -e "${GREEN_COLOR}✓ apt 锁已清理${RES}"
  fi
}

# 检查并安装 OpenCV
CHECK_OPENCV() {
  echo -e "${GREEN_COLOR}检查 OpenCV 依赖...${RES}"
  
  # 检查是否已安装 OpenCV
  if ldconfig -p 2>/dev/null | grep -q libopencv; then
    echo -e "${GREEN_COLOR}✓ OpenCV 已安装${RES}"
    return 0
  fi
  
  # 检测包管理器并安装
  if command -v apt-get >/dev/null 2>&1; then
    echo -e "${YELLOW_COLOR}正在安装 OpenCV (apt-get)...${RES}"
    kill_apt_processes
    apt-get update && apt-get install -y libopencv-dev || handle_error 1 "OpenCV 安装失败"
  elif command -v yum >/dev/null 2>&1; then
    echo -e "${YELLOW_COLOR}正在安装 OpenCV (yum)...${RES}"
    yum install -y opencv opencv-devel || handle_error 1 "OpenCV 安装失败"
  elif command -v dnf >/dev/null 2>&1; then
    echo -e "${YELLOW_COLOR}正在安装 OpenCV (dnf)...${RES}"
    dnf install -y opencv opencv-devel || handle_error 1 "OpenCV 安装失败"
  elif command -v pacman >/dev/null 2>&1; then
    echo -e "${YELLOW_COLOR}正在安装 OpenCV (pacman)...${RES}"
    pacman -S --noconfirm opencv || handle_error 1 "OpenCV 安装失败"
  else
    echo -e "${RED_COLOR}错误：无法检测包管理器，请手动安装 OpenCV${RES}"
    echo -e "Ubuntu/Debian: sudo apt-get install libopencv-dev"
    echo -e "CentOS/RHEL:   sudo yum install opencv opencv-devel"
    echo -e "Arch Linux:    sudo pacman -S opencv"
    exit 1
  fi
  
  echo -e "${GREEN_COLOR}✓ OpenCV 安装完成${RES}"
}

CHECK() {
  if [ ! -d "$(dirname "$INSTALL_PATH")" ]; then
    echo -e "${GREEN_COLOR}目录不存在，正在创建...${RES}"
    mkdir -p "$(dirname "$INSTALL_PATH")" || handle_error 1 "无法创建目录 $(dirname "$INSTALL_PATH")"
  fi

  if [ -f "$INSTALL_PATH/opsdeck" ]; then
    echo "此位置已经安装，请选择其他位置，或使用更新命令"
    exit 0
  fi

  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH || handle_error 1 "无法创建安装目录 $INSTALL_PATH"
  else
    rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
  fi

  echo -e "${GREEN_COLOR}安装目录准备就绪：$INSTALL_PATH${RES}"
}

# 下载函数
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        if curl -L --connect-timeout 10 --retry 3 --retry-delay 3 "$url" -o "$output"; then
            if [ -f "$output" ] && [ -s "$output" ]; then
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW_COLOR}下载失败，${wait_time} 秒后进行第 $((retry_count + 1)) 次重试...${RES}"
            sleep $wait_time
            wait_time=$((wait_time + 5))
        else
            echo -e "${RED_COLOR}下载失败，已重试 $max_retries 次${RES}"
            return 1
        fi
    done
    return 1
}

# 获取最新版本
get_latest_version() {
    local version=$(curl -s "https://api.github.com/repos/${GH_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$version"
}

INSTALL() {
  echo -e "${GREEN_COLOR}正在获取最新版本信息...${RES}"
  local version=$(get_latest_version)
  
  if [ -z "$version" ]; then
    handle_error 1 "无法获取最新版本信息"
  fi
  
  echo -e "${GREEN_COLOR}最新版本: $version${RES}"
  
  local filename="opsdeck-linux-${ARCH}-${version}"
  local download_url="${GH_DOWNLOAD_URL}/${filename}"
  
  echo -e "\r\n${GREEN_COLOR}下载 OpsDeck ...${RES}"
  if ! download_file "$download_url" "/tmp/opsdeck"; then
    handle_error 1 "下载失败"
  fi

  chmod +x /tmp/opsdeck
  mv /tmp/opsdeck $INSTALL_PATH/opsdeck

  if [ -f $INSTALL_PATH/opsdeck ]; then
    echo -e "${GREEN_COLOR}下载成功，正在安装...${RES}"
  else
    handle_error 1 "安装失败"
  fi
}

INIT() {
  if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
    handle_error 1 "当前系统未安装 OpsDeck"
  fi

  # 创建日志目录
  mkdir -p /var/log/opsdeck
  
  cat >/etc/systemd/system/opsdeck.service <<EOF
[Unit]
Description=OpsDeck service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/opsdeck
StandardOutput=append:/var/log/opsdeck/opsdeck.log
StandardError=append:/var/log/opsdeck/opsdeck.log
Environment="NO_COLOR=1"
Environment="TERM=dumb"
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  # 配置日志轮转
  cat >/etc/logrotate.d/opsdeck <<EOF
/var/log/opsdeck/opsdeck.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        systemctl reload opsdeck >/dev/null 2>&1 || true
    endscript
}
EOF

  systemctl daemon-reload
  systemctl enable opsdeck >/dev/null 2>&1
}

SUCCESS() {
  clear
  LOCAL_IP=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
  PUBLIC_IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || echo "获取失败")
  
  echo -e "════════════════════════════════════════════════════"
  echo -e "  OpsDeck 安装成功！"
  echo -e ""
  echo -e "  访问地址："
  echo -e "    局域网：http://${LOCAL_IP}:13113/"
  echo -e "    公网：  http://${PUBLIC_IP}:13113/"
  echo -e ""
  echo -e "  默认账号："
  echo -e "    用户名：admin"
  echo -e "    密码：  password"
  echo -e "════════════════════════════════════════════════════"
  
  echo -e "\n${GREEN_COLOR}启动服务中...${RES}"
  systemctl restart opsdeck
  
  echo -e "\n${YELLOW_COLOR}温馨提示：如果端口无法访问，请检查服务器安全组、防火墙和服务状态${RES}"
  echo
  exit 0
}

UPDATE() {
    if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        handle_error 1 "未在 $INSTALL_PATH 找到 OpsDeck"
    fi

    echo -e "${GREEN_COLOR}开始更新 OpsDeck ...${RES}"

    local version=$(get_latest_version)
    
    if [ -z "$version" ]; then
        handle_error 1 "无法获取最新版本信息"
    fi
    
    echo -e "${GREEN_COLOR}最新版本: $version${RES}"
    
    echo -e "${GREEN_COLOR}停止 OpsDeck 进程${RES}\r\n"
    systemctl stop opsdeck

    cp $INSTALL_PATH/opsdeck /tmp/opsdeck.bak

    local filename="opsdeck-linux-${ARCH}-${version}"
    local download_url="${GH_DOWNLOAD_URL}/${filename}"
    
    echo -e "${GREEN_COLOR}下载 OpsDeck ...${RES}"
    if ! download_file "$download_url" "/tmp/opsdeck"; then
        echo -e "${RED_COLOR}下载失败，更新终止${RES}"
        echo -e "${GREEN_COLOR}正在恢复之前的版本...${RES}"
        mv /tmp/opsdeck.bak $INSTALL_PATH/opsdeck
        systemctl start opsdeck
        exit 1
    fi

    chmod +x /tmp/opsdeck
    mv /tmp/opsdeck $INSTALL_PATH/opsdeck

    if [ -f $INSTALL_PATH/opsdeck ]; then
        echo -e "${GREEN_COLOR}下载成功，正在更新${RES}"
    else
        echo -e "${RED_COLOR}更新失败！${RES}"
        mv /tmp/opsdeck.bak $INSTALL_PATH/opsdeck
        systemctl start opsdeck
        exit 1
    fi

    rm -f /tmp/opsdeck.bak

    echo -e "${GREEN_COLOR}启动 OpsDeck 进程${RES}\r\n"
    systemctl restart opsdeck

    echo -e "${GREEN_COLOR}更新完成！${RES}"
}

UNINSTALL() {
    if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        handle_error 1 "未在 $INSTALL_PATH 找到 OpsDeck"
    fi
    
    echo -e "${RED_COLOR}警告：卸载后将删除本地 OpsDeck 目录、数据库文件和日志文件！${RES}"
    read -p "是否确认卸载？[Y/n]: " choice
    
    case "${choice:-y}" in
        [yY]|"")
            echo -e "${GREEN_COLOR}开始卸载...${RES}"
            
            echo -e "${GREEN_COLOR}停止 OpsDeck 进程${RES}"
            systemctl stop opsdeck
            systemctl disable opsdeck
            
            echo -e "${GREEN_COLOR}删除 OpsDeck 文件${RES}"
            rm -rf $INSTALL_PATH
            rm -rf /var/log/opsdeck
            rm -f /etc/systemd/system/opsdeck.service
            rm -f /etc/logrotate.d/opsdeck
            systemctl daemon-reload
            
            echo -e "${GREEN_COLOR}OpsDeck 已完全卸载${RES}"
            ;;
        *)
            echo -e "${GREEN_COLOR}已取消卸载${RES}"
            ;;
    esac
}

SHOW_MENU() {
  INSTALL_PATH=$(GET_INSTALLED_PATH)

  echo -e "\n欢迎使用 OpsDeck 管理脚本\n"
  echo -e "${GREEN_COLOR}1、安装 OpsDeck${RES}"
  echo -e "${GREEN_COLOR}2、更新 OpsDeck${RES}"
  echo -e "${GREEN_COLOR}3、卸载 OpsDeck${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}4、查看运行状态${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}5、启动 OpsDeck${RES}"
  echo -e "${GREEN_COLOR}6、停止 OpsDeck${RES}"
  echo -e "${GREEN_COLOR}7、重启 OpsDeck${RES}"
  echo -e "${GREEN_COLOR}8、查看实时日志${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}0、退出脚本${RES}"
  echo
  read -p "请输入选项 [0-8]: " choice
  
  case "$choice" in
    1)
      INSTALL_PATH='/opt/opsdeck'
      CHECK_OPENCV
      CHECK
      INSTALL
      INIT
      SUCCESS
      return 0
      ;;
    2)
      UPDATE
      exit 0
      ;;
    3)
      UNINSTALL
      exit 0
      ;;
    4)
      if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpsDeck，请先安装！${RES}\r\n"
        return 1
      fi
      
      echo -e "\n${GREEN_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RES}"
      echo -e "${GREEN_COLOR}               OpsDeck 服务状态信息${RES}"
      echo -e "${GREEN_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RES}\n"
      
      # 服务运行状态
      if systemctl is-active opsdeck >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}【服务状态】${RES} ● 运行中"
        
        # 获取进程 PID
        local pid=$(systemctl show -p MainPID opsdeck | cut -d'=' -f2)
        
        if [ "$pid" != "0" ] && [ -n "$pid" ]; then
          echo -e "${GREEN_COLOR}【进 程 号】${RES} $pid"
          
          # 运行时长
          local uptime=$(systemctl show -p ActiveEnterTimestamp opsdeck | cut -d'=' -f2)
          if [ -n "$uptime" ]; then
            local uptime_sec=$(date -d "$uptime" +%s 2>/dev/null || echo "0")
            local current_sec=$(date +%s)
            local runtime_sec=$((current_sec - uptime_sec))
            
            local days=$((runtime_sec / 86400))
            local hours=$(((runtime_sec % 86400) / 3600))
            local minutes=$(((runtime_sec % 3600) / 60))
            
            if [ $days -gt 0 ]; then
              echo -e "${GREEN_COLOR}【运行时长】${RES} ${days}天 ${hours}小时 ${minutes}分钟"
            elif [ $hours -gt 0 ]; then
              echo -e "${GREEN_COLOR}【运行时长】${RES} ${hours}小时 ${minutes}分钟"
            else
              echo -e "${GREEN_COLOR}【运行时长】${RES} ${minutes}分钟"
            fi
          fi
          
          # CPU 使用率
          if command -v ps >/dev/null 2>&1; then
            local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | xargs)
            if [ -n "$cpu" ]; then
              echo -e "${GREEN_COLOR}【CPU 占用】${RES} ${cpu}%"
            fi
          fi
          
          # 内存使用
          if [ -f "/proc/$pid/status" ]; then
            local mem_kb=$(grep VmRSS /proc/$pid/status | awk '{print $2}')
            if [ -n "$mem_kb" ]; then
              local mem_mb=$((mem_kb / 1024))
              if [ $mem_mb -gt 1024 ]; then
                local mem_gb=$(echo "scale=2; $mem_mb / 1024" | bc)
                echo -e "${GREEN_COLOR}【内存占用】${RES} ${mem_gb} GB (${mem_mb} MB)"
              else
                echo -e "${GREEN_COLOR}【内存占用】${RES} ${mem_mb} MB"
              fi
            fi
          fi
          
          # 线程数
          if [ -d "/proc/$pid/task" ]; then
            local threads=$(ls /proc/$pid/task | wc -l)
            echo -e "${GREEN_COLOR}【线程数量】${RES} $threads"
          fi
          
          # 打开的文件描述符数
          if [ -d "/proc/$pid/fd" ]; then
            local fds=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
            echo -e "${GREEN_COLOR}【文件描述符】${RES} $fds"
          fi
        fi
      else
        echo -e "${RED_COLOR}【服务状态】${RES} ○ 已停止"
      fi
      
      # 安装路径
      echo -e "${GREEN_COLOR}【安装路径】${RES} $INSTALL_PATH"
      
      # 版本信息
      if [ -f "$INSTALL_PATH/opsdeck" ]; then
        # 尝试从文件名或GitHub获取版本，如果失败则显示文件修改时间
        local version=$(get_latest_version 2>/dev/null)
        if [ -z "$version" ]; then
          local file_date=$(stat -c %y "$INSTALL_PATH/opsdeck" 2>/dev/null | cut -d' ' -f1)
          if [ -z "$file_date" ]; then
            file_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$INSTALL_PATH/opsdeck" 2>/dev/null)
          fi
          version="${file_date:-未知}"
        fi
        echo -e "${GREEN_COLOR}【程序版本】${RES} $version"
        
        # 文件大小
        local size=$(du -h "$INSTALL_PATH/opsdeck" | cut -f1)
        echo -e "${GREEN_COLOR}【文件大小】${RES} $size"
      fi
      
      # 端口监听状态
      if command -v ss >/dev/null 2>&1; then
        local port_info=$(ss -tlnp 2>/dev/null | grep opsdeck | grep -o ":\d\+\s" | tr -d ': ')
        if [ -n "$port_info" ]; then
          echo -e "${GREEN_COLOR}【监听端口】${RES} $port_info"
        fi
      elif command -v netstat >/dev/null 2>&1; then
        local port_info=$(netstat -tlnp 2>/dev/null | grep opsdeck | awk '{print $4}' | grep -o ":\d\+$" | tr -d ':')
        if [ -n "$port_info" ]; then
          echo -e "${GREEN_COLOR}【监听端口】${RES} $port_info"
        fi
      fi
      
      # 系统开机启动状态
      if systemctl is-enabled opsdeck >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}【开机启动】${RES} 已启用"
      else
        echo -e "${YELLOW_COLOR}【开机启动】${RES} 未启用"
      fi
      
      echo -e "\n${GREEN_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RES}\n"
      echo -e "${YELLOW_COLOR}提示：使用选项 8 可查看实时日志${RES}"
      
      return 0
      ;;
    5)
      if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpsDeck，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl start opsdeck
      echo -e "${GREEN_COLOR}OpsDeck 已启动${RES}"
      return 0
      ;;
    6)
      if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpsDeck，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl stop opsdeck
      echo -e "${GREEN_COLOR}OpsDeck 已停止${RES}"
      return 0
      ;;
    7)
      if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpsDeck，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl restart opsdeck
      echo -e "${GREEN_COLOR}OpsDeck 已重启${RES}"
      return 0
      ;;
    8)
      if [ ! -f "$INSTALL_PATH/opsdeck" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpsDeck，请先安装！${RES}\r\n"
        return 1
      fi
      
      local log_file="/data/logs/app.log.$(date +%Y-%m-%d)"
      
      if [ ! -f "$log_file" ]; then
        echo -e "${RED_COLOR}日志文件不存在：$log_file${RES}"
        return 1
      fi
      
      echo -e "${GREEN_COLOR}正在查看 OpsDeck 实时日志...${RES}"
      echo -e "${YELLOW_COLOR}提示：按 Ctrl+C 退出日志查看${RES}"
      echo -e "${YELLOW_COLOR}日志文件：$log_file${RES}\n"
      
      # 使用 sed 过滤 ANSI 颜色代码，确保显示纯文本
      tail -n 20 -f "$log_file" | sed -u 's/\x1b\[[0-9;]*m//g'
      return 0
      ;;
    0)
      exit 0
      ;;
    *)
      echo -e "${RED_COLOR}无效的选项${RES}"
      return 1
      ;;
  esac
}

# 主程序
if [ $# -eq 0 ]; then
  while true; do
    SHOW_MENU
    echo
    if [ $? -eq 0 ]; then
      sleep 3
    else
      sleep 5
    fi
    clear
  done
elif [ "$1" = "install" ]; then
  CHECK_OPENCV
  CHECK
  INSTALL
  INIT
  SUCCESS
elif [ "$1" = "update" ]; then
  if [ $# -gt 1 ]; then
    echo -e "${RED_COLOR}错误：update 命令不需要指定路径${RES}"
    echo -e "正确用法: $0 update"
    exit 1
  fi
  UPDATE
elif [ "$1" = "uninstall" ]; then
  if [ $# -gt 1 ]; then
    echo -e "${RED_COLOR}错误：uninstall 命令不需要指定路径${RES}"
    echo -e "正确用法: $0 uninstall"
    exit 1
  fi
  UNINSTALL
else
  echo -e "${RED_COLOR}错误的命令${RES}"
  echo -e "用法: $0 install [安装路径]    # 安装 OpsDeck"
  echo -e "     $0 update              # 更新 OpsDeck"
  echo -e "     $0 uninstall          # 卸载 OpsDeck"
  echo -e "     $0                    # 显示交互菜单"
fi