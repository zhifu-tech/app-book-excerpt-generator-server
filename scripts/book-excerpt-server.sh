#!/bin/bash

# ============================================
# Book Excerpt Generator Server - 统一管理脚本
# ============================================
# 整合所有部署和管理功能
# 使用方法: ./book-excerpt-server.sh [command] [options]
# ============================================

# 严格模式：遇到错误立即退出，使用未定义变量报错，管道中任一命令失败则整个管道失败
set -euo pipefail

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================
# 配置变量
# ============================================

# 服务器配置（导出供共用脚本使用）
export SERVER_HOST="${SERVER_HOST:-8.138.183.116}"
export SERVER_USER="${SERVER_USER:-root}"
export SERVER_PORT="${SERVER_PORT:-22}"

# 应用目录配置
APP_DIR="/opt/book-excerpt-generator-server"
APP_PORT="3001"
NGINX_CONF_PATH="/etc/nginx/conf.d/book-excerpt-generator-server.conf"
SSL_CERT_DIR="/etc/nginx/ssl"

# ============================================
# 工具函数
# ============================================

# 加载共用脚本库（必须在 trap 之前加载，以便使用 safe_exit）
APP_COMMON_DIR="$(cd "$PROJECT_ROOT/../app-common" && pwd)"
[ -f "$APP_COMMON_DIR/scripts/common-utils.sh" ] && source "$APP_COMMON_DIR/scripts/common-utils.sh"
[ -f "$APP_COMMON_DIR/scripts/ssh-utils.sh" ] && source "$APP_COMMON_DIR/scripts/ssh-utils.sh"
[ -f "$APP_COMMON_DIR/scripts/nginx-utils.sh" ] && source "$APP_COMMON_DIR/scripts/nginx-utils.sh"
[ -f "$APP_COMMON_DIR/scripts/nginx-update.sh" ] && source "$APP_COMMON_DIR/scripts/nginx-update.sh"

# 设置清理 trap（脚本退出时清理临时文件，必须在加载 common-utils.sh 之后）
trap 'safe_exit $?' EXIT INT TERM

# ============================================
# 欢迎界面
# ============================================
show_welcome() {
  echo ""
  echo -e "${CYAN}"
  # 从 welcome.txt 读取欢迎画面
  local welcome_file="$APP_COMMON_DIR/welcome.txt"
  if [ -f "$welcome_file" ]; then
    cat "$welcome_file"
  else
    # 如果文件不存在，使用默认的 ASCII 艺术字
    cat << "EOF"
 ____                     __          ____                                            __        ____                                            
/\  _`\                  /\ \        /\  _`\                                         /\ \__    /\  _`\                                          
\ \ \L\ \    ___     ___ \ \ \/'\    \ \ \L\_\   __  _    ___      __   _ __   _____ \ \ ,_\   \ \,\L\_\      __   _ __   __  __     __   _ __  
 \ \  _ <'  / __`\  / __`\\ \ , <     \ \  _\L  /\ \/'\  /'___\  /'__`\/\`'__\/\ '__`\\ \ \/    \/_\__ \    /'__`\/\`'__\/\ \/\ \  /'__`\/\`'__\
  \ \ \L\ \/\ \L\ \/\ \L\ \\ \ \\`\    \ \ \L\ \\/>  </ /\ \__/ /\  __/\ \ \/ \ \ \L\ \\ \ \_     /\ \L\ \ /\  __/\ \ \/ \ \ \_/ |/\  __/\ \ \/ 
   \ \____/\ \____/\ \____/ \ \_\ \_\   \ \____/ /\_/\_\\ \____\\ \____\\ \_\  \ \ ,__/ \ \__\    \ `\____\\ \____\\ \_\  \ \___/ \ \____\\ \_\ 
    \/___/  \/___/  \/___/   \/_/\/_/    \/___/  \//\/_/ \/____/ \/____/ \/_/   \ \ \/   \/__/     \/_____/ \/____/ \/_/   \/__/   \/____/ \/_/ 
                                                                                 \ \_\                                                          
                                                                                  \/_/
EOF
  fi
  echo -e "${NC}"
  echo -e "${CYAN}              Book Excerpt Generator Server@Zhifu's Tech${NC}"
  echo ""
  local cmd="${1:-help}"
  echo -e "${YELLOW}版本: 0.2.0${NC}"
  echo -e "${YELLOW}服务器: ${SERVER_HOST:-未配置}${NC}"
  echo -e "${YELLOW}命令: ${cmd}${NC}"
  echo ""
}

# ============================================
# 帮助信息
# ============================================
show_help() {
  echo -e "${CYAN}Book Excerpt Generator Server - 使用帮助${NC}"
  echo ""
  echo -e "${YELLOW}用法:${NC}"
  echo "  ./book-excerpt-server.sh [command] [options]"
  echo ""
  echo -e "${YELLOW}可用命令:${NC}"
  echo ""
  echo -e "  ${GREEN}SSH 配置:${NC}"
  echo -e "  ${GREEN}update-ssh-key${NC}     更新 SSH 公钥到服务器"
  echo ""
  echo -e "  ${GREEN}部署:${NC}"
  echo -e "  ${GREEN}deploy${NC}             部署服务到服务器"
  echo -e "  ${GREEN}restart${NC}             重启服务"
  echo ""
  echo -e "  ${GREEN}监控:${NC}"
  echo -e "  ${GREEN}status${NC}              检查服务状态"
  echo -e "  ${GREEN}check${NC}              快速检查服务"
  echo -e "  ${GREEN}logs${NC}               查看服务日志"
  echo ""
  echo -e "  ${GREEN}Nginx 配置:${NC}"
  echo -e "  ${GREEN}update-nginx${NC}        更新 Nginx 配置文件"
  echo ""
  echo -e "  ${GREEN}工具:${NC}"
  echo -e "  ${GREEN}fix-502${NC}            修复 502 错误"
  echo -e "  ${GREEN}install-pm2${NC}        安装 PM2 进程管理器"
  echo -e "  ${GREEN}firewall${NC}           检查防火墙配置"
  echo ""
  echo -e "  ${GREEN}help${NC}               显示此帮助信息"
  echo ""
  echo -e "${YELLOW}示例:${NC}"
  echo "  ./book-excerpt-server.sh deploy"
  echo "  ./book-excerpt-server.sh status"
  echo "  ./book-excerpt-server.sh logs"
  echo "  ./book-excerpt-server.sh update-nginx"
  echo ""
}

# ============================================
# 部署功能
# ============================================
cmd_deploy() {
  print_title "部署服务到服务器 ${SERVER_HOST}"
  
  # 切换到项目根目录
  cd "$PROJECT_ROOT" || return 1
  
  # 检查本地文件
  check_file_exists "package.json" "未找到 package.json，请确保在项目根目录执行" || return 1
  check_dir_exists "src" "未找到 src/ 目录，请确保在项目根目录执行" || return 1

  # 创建临时部署目录
  TEMP_DIR=$(mktemp -d)
  register_cleanup "$TEMP_DIR"
  print_info "创建临时目录: ${TEMP_DIR}"

  # 复制必要文件
  print_info "复制文件..."
  cp -r server.js package.json package-lock.json ecosystem.config.cjs example.env "$TEMP_DIR/" 2>/dev/null || true

  # 复制源代码目录（重要！）
  if [ -d "src" ]; then
    cp -r src "$TEMP_DIR/"
    print_success "已复制 src/ 目录"
  else
    print_error "未找到 src/ 目录"
    exit 1
  fi

  # 创建数据目录
  mkdir -p "$TEMP_DIR/data"
  touch "$TEMP_DIR/data/.gitkeep"

  # 上传文件到服务器
  print_info "上传文件到服务器..."
  ssh_exec "mkdir -p ${APP_DIR}"
  scp $SSH_OPTIONS -r -P ${SERVER_PORT} "$TEMP_DIR"/* ${SSH_TARGET}:${APP_DIR}/

  # 临时目录会在脚本退出时自动清理（通过 trap）

  # 在服务器上执行部署操作
  print_info "在服务器上安装依赖并启动服务..."
  ssh_exec << 'ENDSSH'
set -e
cd /opt/book-excerpt-generator-server

# 清理旧文件
echo "清理旧文件..."
rm -f ecosystem.config.js 2>/dev/null || true
echo "✓ 已清理旧配置文件"

# 检查并安装 Node.js（如果未安装）
if ! command -v node &> /dev/null; then
  echo "安装 Node.js..."
  
  # 检测系统类型并安装 Node.js
  if [ -f /etc/redhat-release ]; then
    # CentOS/RHEL 系统
    echo "检测到 CentOS/RHEL 系统，使用 yum 安装..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs
  elif [ -f /etc/debian_version ]; then
    # Debian/Ubuntu 系统
    echo "检测到 Debian/Ubuntu 系统，使用 apt 安装..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
  else
    # 其他系统，尝试使用 nvm
    echo "检测到其他系统，尝试使用 nvm 安装..."
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] || curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 18
    nvm use 18
  fi
  
  # 验证安装
  if command -v node &> /dev/null; then
    echo "Node.js 安装完成: $(node --version)"
  else
    echo "错误: Node.js 安装失败，请手动安装"
    exit 1
  fi
fi

# 检查 Node.js 版本
if ! command -v node &> /dev/null; then
  echo "错误: Node.js 未安装"
  exit 1
fi

echo "Node.js 版本: $(node --version)"
echo "npm 版本: $(npm --version)"

# 安装依赖
if [ ! -d "node_modules" ]; then
  echo "安装依赖..."
  npm install --production
else
  echo "更新依赖..."
  npm install --production
fi

# 创建日志目录
mkdir -p logs

# 安装 PM2（如果未安装）
if ! command -v pm2 &> /dev/null; then
  echo "安装 PM2..."
  npm install -g pm2
  if command -v pm2 &> /dev/null; then
    echo "✓ PM2 安装成功: $(pm2 --version)"
  else
    echo "⚠ PM2 安装失败，将使用 node 直接启动"
  fi
fi

# 停止所有占用 3001 端口的进程
echo "停止所有占用 3001 端口的进程..."
# 使用 PM2 停止
if command -v pm2 &> /dev/null; then
  pm2 delete book-excerpt-server 2>/dev/null || true
  pm2 stop all 2>/dev/null || true
fi

# 查找并杀死占用 3001 端口的进程
if command -v lsof &> /dev/null; then
  PID=$(lsof -ti:3001 2>/dev/null || true)
  if [ ! -z "$PID" ]; then
    echo "发现占用 3001 端口的进程: $PID"
    kill -9 $PID 2>/dev/null || true
    echo "已终止进程 $PID"
  fi
elif command -v fuser &> /dev/null; then
  fuser -k 3001/tcp 2>/dev/null || true
  echo "已尝试终止占用 3001 端口的进程"
fi

# 使用 pkill 停止所有 node server.js 进程
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f "node.*/opt/book-excerpt-generator-server" 2>/dev/null || true

# 等待端口释放
echo "等待端口释放..."
sleep 3

# 验证端口是否已释放
if command -v lsof &> /dev/null; then
  if lsof -ti:3001 > /dev/null 2>&1; then
    echo "警告: 端口 3001 仍被占用，强制清理..."
    lsof -ti:3001 | xargs kill -9 2>/dev/null || true
    sleep 2
  fi
fi

# 使用 PM2 启动/重启服务
if command -v pm2 &> /dev/null; then
  echo "使用 PM2 管理进程..."
  pm2 start ecosystem.config.cjs
  pm2 save
  echo "服务已启动，使用 'pm2 status' 查看状态"
  sleep 3
  pm2 status
else
  echo "警告: 未安装 PM2，使用 node 直接启动..."
  # 启动新进程
  nohup node server.js > logs/out.log 2> logs/error.log &
  echo "服务已在后台启动，PID: $!"
  sleep 3
  # 检查进程
  if pgrep -f "node.*server.js" > /dev/null; then
    echo "✓ 进程运行中: $(pgrep -f 'node.*server.js')"
  else
    echo "✗ 进程启动失败，查看错误日志:"
    tail -10 logs/error.log 2>/dev/null || echo "无法读取日志"
  fi
fi

# 显示服务状态
echo ""
echo "检查服务状态..."
sleep 2
if curl -s http://localhost:3001/health > /dev/null; then
  echo "✓ 服务运行正常"
  curl -s http://localhost:3001/health
else
  echo "✗ 服务无法访问，检查日志:"
  tail -20 logs/error.log 2>/dev/null || echo "无法读取错误日志"
  tail -20 logs/out.log 2>/dev/null || echo "无法读取输出日志"
fi
ENDSSH

  echo ""
  print_success "部署完成！"
  echo -e "${YELLOW}服务器地址:${NC}"
  echo -e "  ${GREEN}http://${SERVER_HOST}:${APP_PORT}${NC}"
  echo -e "  ${GREEN}https://${SERVER_HOST}:${APP_PORT}${NC}"
  echo -e "${YELLOW}健康检查:${NC}"
  echo -e "  ${GREEN}http://${SERVER_HOST}:${APP_PORT}/health${NC}"
  echo -e "${YELLOW}API 端点:${NC}"
  echo -e "  ${GREEN}http://${SERVER_HOST}:${APP_PORT}/api/config${NC}"
}

# ============================================
# 重启服务
# ============================================
cmd_restart() {
  print_title "重启服务"
  
  ssh_exec << 'ENDSSH'
set -e
cd /opt/book-excerpt-generator-server

# 停止所有占用 3001 端口的进程
echo "停止所有占用 3001 端口的进程..."
if command -v pm2 &> /dev/null; then
  pm2 delete book-excerpt-server 2>/dev/null || true
  pm2 stop all 2>/dev/null || true
fi

# 查找并杀死占用 3001 端口的进程
if command -v lsof &> /dev/null; then
  PID=$(lsof -ti:3001 2>/dev/null || true)
  if [ ! -z "$PID" ]; then
    echo "发现占用 3001 端口的进程: $PID"
    kill -9 $PID 2>/dev/null || true
    echo "已终止进程 $PID"
  fi
fi

# 使用 pkill 停止所有 node server.js 进程
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f "node.*/opt/book-excerpt-generator-server" 2>/dev/null || true

# 等待端口释放
echo "等待端口释放..."
sleep 3

# 使用 PM2 启动/重启服务
if command -v pm2 &> /dev/null; then
  echo "使用 PM2 重启服务..."
  pm2 start ecosystem.config.cjs || pm2 restart book-excerpt-server
  pm2 save
  sleep 3
  pm2 status
else
  echo "警告: 未安装 PM2，使用 node 直接启动..."
  nohup node server.js > logs/out.log 2> logs/error.log &
  echo "服务已在后台启动，PID: $!"
  sleep 3
  if pgrep -f "node.*server.js" > /dev/null; then
    echo "✓ 进程运行中: $(pgrep -f 'node.*server.js')"
  else
    echo "✗ 进程启动失败"
    tail -10 logs/error.log 2>/dev/null || echo "无法读取日志"
  fi
fi

# 检查服务状态
echo ""
echo "检查服务状态..."
sleep 2
if curl -s http://localhost:3001/health > /dev/null; then
  echo "✓ 服务运行正常"
  curl -s http://localhost:3001/health
else
  echo "✗ 服务无法访问"
  tail -20 logs/error.log 2>/dev/null || echo "无法读取错误日志"
fi
ENDSSH

  echo ""
  print_success "服务重启完成！"
}

# ============================================
# 检查状态
# ============================================
cmd_status() {
  print_title "检查服务状态"
  
  ssh_exec << 'ENDSSH'
set -e
cd /opt/book-excerpt-generator-server 2>/dev/null || { echo "✗ 部署目录不存在"; exit 1; }

echo "=========================================="
echo "1. 检查部署目录"
echo "=========================================="
if [ -d "/opt/book-excerpt-generator-server" ]; then
  echo "✓ 部署目录存在"
  echo "目录大小: $(du -sh /opt/book-excerpt-generator-server 2>/dev/null | cut -f1)"
  echo ""
  echo "文件列表:"
  ls -lah /opt/book-excerpt-generator-server | head -15
else
  echo "✗ 部署目录不存在"
fi

echo ""
echo "=========================================="
echo "2. 检查关键文件"
echo "=========================================="
FILES=("server.js" "package.json" "ecosystem.config.cjs" "src/app.js")
for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "unknown")
    echo "✓ $file 存在 (${size} bytes)"
  else
    echo "✗ $file 不存在"
  fi
done

echo ""
echo "=========================================="
echo "3. 检查 Node.js 和 npm"
echo "=========================================="
if command -v node &> /dev/null; then
  echo "✓ Node.js 已安装: $(node --version)"
else
  echo "✗ Node.js 未安装"
fi

if command -v npm &> /dev/null; then
  echo "✓ npm 已安装: $(npm --version)"
else
  echo "✗ npm 未安装"
fi

echo ""
echo "=========================================="
echo "4. 检查 PM2"
echo "=========================================="
if command -v pm2 &> /dev/null; then
  echo "✓ PM2 已安装: $(pm2 --version)"
  echo ""
  echo "PM2 进程状态:"
  pm2 status 2>/dev/null || echo "无运行中的进程"
else
  echo "⚠ PM2 未安装"
  echo "运行 ./book-excerpt-server.sh install-pm2 安装"
fi

echo ""
echo "=========================================="
echo "5. 检查端口占用"
echo "=========================================="
if command -v lsof &> /dev/null; then
  PID=$(lsof -ti:3001 2>/dev/null || echo "")
  if [ ! -z "$PID" ]; then
    PROCESS=$(ps -p $PID -o comm= 2>/dev/null || echo "unknown")
    echo "⚠ 端口 3001 被进程占用 (PID: $PID, 进程: $PROCESS)"
  else
    echo "✓ 端口 3001 未被占用"
  fi
elif command -v netstat &> /dev/null; then
  if netstat -tlnp 2>/dev/null | grep ":3001 " > /dev/null; then
    echo "⚠ 端口 3001 被占用"
    netstat -tlnp 2>/dev/null | grep ":3001 "
  else
    echo "✓ 端口 3001 未被占用"
  fi
else
  echo "⚠ 无法检查端口占用（未安装 lsof/netstat）"
fi

echo ""
echo "=========================================="
echo "6. 检查服务运行状态"
echo "=========================================="
if command -v pm2 &> /dev/null; then
  if pm2 list | grep -q "book-excerpt-server"; then
    echo "✓ PM2 进程运行中"
    pm2 info book-excerpt-server 2>/dev/null | head -15
  else
    echo "⚠ PM2 进程未运行"
  fi
fi

# 检查进程
if pgrep -f "node.*server.js" > /dev/null; then
  PID=$(pgrep -f "node.*server.js" | head -1)
  echo "✓ Node.js 进程运行中 (PID: $PID)"
else
  echo "✗ Node.js 进程未运行"
fi

echo ""
echo "=========================================="
echo "7. 测试服务健康检查"
echo "=========================================="
if curl -s http://localhost:3001/health > /dev/null; then
  echo "✓ 服务健康检查通过"
  curl -s http://localhost:3001/health
  echo ""
else
  echo "✗ 服务健康检查失败"
  echo "查看错误日志:"
  tail -20 logs/error.log 2>/dev/null || echo "无法读取错误日志"
fi

echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
ENDSSH

  echo ""
  print_success "状态检查完成！"
}

# ============================================
# 快速检查
# ============================================
cmd_check() {
  print_title "快速检查服务"
  
  ssh_exec << 'ENDSSH'
set -e

echo "快速检查服务状态..."
echo ""

# 检查进程
if pgrep -f "node.*server.js" > /dev/null; then
  PID=$(pgrep -f "node.*server.js" | head -1)
  echo "✓ 服务进程运行中 (PID: $PID)"
else
  echo "✗ 服务进程未运行"
fi

# 检查端口
if command -v lsof &> /dev/null; then
  if lsof -ti:3001 > /dev/null 2>&1; then
    echo "✓ 端口 3001 正在监听"
  else
    echo "✗ 端口 3001 未监听"
  fi
fi

# 检查健康检查
if curl -s http://localhost:3001/health > /dev/null; then
  echo "✓ 服务健康检查通过"
else
  echo "✗ 服务健康检查失败"
fi

echo ""
ENDSSH
}

# ============================================
# 修复 502 错误
# ============================================
cmd_fix_502() {
  print_title "修复 502 错误"
  
  ssh_exec << 'ENDSSH'
set -e
cd /opt/book-excerpt-generator-server 2>/dev/null || { echo "✗ 部署目录不存在"; exit 1; }

echo "诊断 502 错误..."
echo ""

# 1. 检查进程
echo "1. 检查服务进程..."
if pgrep -f "node.*server.js" > /dev/null; then
  PID=$(pgrep -f "node.*server.js" | head -1)
  echo "✓ 服务进程运行中 (PID: $PID)"
else
  echo "✗ 服务进程未运行，尝试启动..."
  if command -v pm2 &> /dev/null; then
    pm2 start ecosystem.config.cjs
  else
    nohup node server.js > logs/out.log 2> logs/error.log &
  fi
  sleep 3
fi

# 2. 检查端口
echo ""
echo "2. 检查端口 3001..."
if command -v lsof &> /dev/null; then
  PID=$(lsof -ti:3001 2>/dev/null || echo "")
  if [ ! -z "$PID" ]; then
    PROCESS=$(ps -p $PID -o comm= 2>/dev/null || echo "unknown")
    echo "✓ 端口 3001 被进程占用 (PID: $PID, 进程: $PROCESS)"
  else
    echo "✗ 端口 3001 未被占用，尝试启动服务..."
    if command -v pm2 &> /dev/null; then
      pm2 restart book-excerpt-server || pm2 start ecosystem.config.cjs
    else
      nohup node server.js > logs/out.log 2> logs/error.log &
    fi
    sleep 3
  fi
fi

# 3. 检查健康检查
echo ""
echo "3. 检查服务健康检查..."
if curl -s http://localhost:3001/health > /dev/null; then
  echo "✓ 服务健康检查通过"
  curl -s http://localhost:3001/health
else
  echo "✗ 服务健康检查失败"
  echo ""
  echo "查看错误日志:"
  tail -30 logs/error.log 2>/dev/null || echo "无法读取错误日志"
  echo ""
  echo "查看输出日志:"
  tail -30 logs/out.log 2>/dev/null || echo "无法读取输出日志"
fi

# 4. 检查防火墙
echo ""
echo "4. 检查防火墙..."
if command -v firewall-cmd &> /dev/null; then
  if firewall-cmd --list-ports 2>/dev/null | grep -q "3001"; then
    echo "✓ 防火墙已开放 3001 端口"
  else
    echo "⚠ 防火墙未开放 3001 端口"
    echo "运行: firewall-cmd --add-port=3001/tcp --permanent && firewall-cmd --reload"
  fi
fi

echo ""
echo "=========================================="
echo "诊断完成"
echo "=========================================="
ENDSSH

  echo ""
  print_success "502 错误诊断完成！"
}

# ============================================
# 查看日志
# ============================================
cmd_logs() {
  local lines="${1:-50}"
  
  print_title "查看服务日志（最近 ${lines} 行）"
  
  ssh_exec << ENDSSH
set -e
cd /opt/book-excerpt-generator-server 2>/dev/null || { echo "✗ 部署目录不存在"; exit 1; }

echo "=========================================="
echo "错误日志 (logs/error.log)"
echo "=========================================="
tail -${lines} logs/error.log 2>/dev/null || echo "无法读取错误日志"

echo ""
echo "=========================================="
echo "输出日志 (logs/out.log)"
echo "=========================================="
tail -${lines} logs/out.log 2>/dev/null || echo "无法读取输出日志"

if command -v pm2 &> /dev/null; then
  echo ""
  echo "=========================================="
  echo "PM2 日志"
  echo "=========================================="
  pm2 logs book-excerpt-server --lines ${lines} --nostream 2>/dev/null || echo "无法读取 PM2 日志"
fi
ENDSSH
}

# ============================================
# 安装 PM2
# ============================================
cmd_install_pm2() {
  print_title "安装 PM2 进程管理器"
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
set -e

echo "检查 Node.js..."
if ! command -v node &> /dev/null; then
  echo "✗ Node.js 未安装，请先安装 Node.js"
  exit 1
fi

echo "✓ Node.js 已安装: $(node --version)"

echo ""
echo "检查 PM2..."
if command -v pm2 &> /dev/null; then
  echo "✓ PM2 已安装: $(pm2 --version)"
  echo "PM2 已存在，无需安装"
else
  echo "安装 PM2..."
  npm install -g pm2
  
  if command -v pm2 &> /dev/null; then
    echo "✓ PM2 安装成功: $(pm2 --version)"
    echo ""
    echo "设置 PM2 开机自启..."
    pm2 startup 2>/dev/null || echo "⚠ 无法设置开机自启（可能需要手动配置）"
  else
    echo "✗ PM2 安装失败"
    exit 1
  fi
fi
ENDSSH

  echo ""
  print_success "PM2 安装完成！"
}

# ============================================
# 更新 SSH 公钥到服务器
# ============================================
cmd_update_ssh_key() {
  print_info "更新 SSH 公钥到服务器 ${SERVER_HOST}..."
  echo ""
  
  if ! update_ssh_key_to_server; then
    print_error "SSH 公钥更新失败"
    return 1
  fi
  
  echo ""
  print_success "SSH 登录认证信息已更新！"
  print_info "现在可以使用 SSH 密钥无密码登录服务器"
}

# ============================================
# 更新 Nginx 配置
# ============================================
cmd_update_nginx() {
  # 确定配置文件路径
  local nginx_local_conf="${1:-$SCRIPT_DIR/nginx.conf}"
  check_file_exists "$nginx_local_conf" "配置文件不存在" || return 1

  # 确定证书文件路径（使用 api.book-excerpt.zhifu.tech_nginx 目录）
  local cert_dir="$SCRIPT_DIR/api.book-excerpt.zhifu.tech_nginx"
  # 优先使用 api 子域名的证书，如果没有则回退到主域名证书
  local cert_bundle_crt="$cert_dir/api.book-excerpt.zhifu.tech_bundle.crt"
  local cert_bundle_pem="$cert_dir/api.book-excerpt.zhifu.tech_bundle.pem"
  local cert_crt="$cert_dir/api.book-excerpt.zhifu.tech.crt"
  local cert_pem="$cert_dir/api.book-excerpt.zhifu.tech.pem"
  local cert_key="$cert_dir/api.book-excerpt.zhifu.tech.key"
  
  # 如果 API 子域名证书不存在，回退到主域名证书
  if [ ! -f "$cert_key" ]; then
    local fallback_cert_dir="$SCRIPT_DIR/book-excerpt.zhifu.tech_nginx"
    if [ -f "$fallback_cert_dir/book-excerpt.zhifu.tech.key" ]; then
      cert_dir="$fallback_cert_dir"
      cert_bundle_crt="$cert_dir/book-excerpt.zhifu.tech_bundle.crt"
      cert_bundle_pem="$cert_dir/book-excerpt.zhifu.tech_bundle.pem"
      cert_crt="$cert_dir/book-excerpt.zhifu.tech.crt"
      cert_pem="$cert_dir/book-excerpt.zhifu.tech.pem"
      cert_key="$cert_dir/book-excerpt.zhifu.tech.key"
      print_info "使用主域名证书目录: ${cert_dir}"
    fi
  fi

  # 检查证书文件是否存在（支持多种命名格式）
  local ssl_cert_files_exist=false
  local ssl_cert_name=""
  if [ -f "$cert_key" ]; then
    if [[ "$cert_dir" == *"api.book-excerpt.zhifu.tech_nginx"* ]]; then
      ssl_cert_name="api.book-excerpt.zhifu.tech"
    else
      ssl_cert_name="book-excerpt.zhifu.tech"
    fi
    
    if ([ -f "$cert_bundle_crt" ] || [ -f "$cert_bundle_pem" ] || [ -f "$cert_crt" ] || [ -f "$cert_pem" ]); then
      ssl_cert_files_exist=true
    fi
  fi

  if [ "$ssl_cert_files_exist" = true ]; then
    print_success "找到证书文件"
    print_info "  证书目录: ${cert_dir}"
    print_info "  证书名称: ${ssl_cert_name}"
  else
    print_warning "未找到证书文件，将跳过证书上传"
    print_info "  证书目录: ${cert_dir}"
  fi

  print_info "更新 Nginx 配置到服务器 ${SERVER_HOST}..."

  # 使用共用脚本库更新配置
  if [ "$ssl_cert_files_exist" = true ]; then
    update_nginx_config \
      "$nginx_local_conf" \
      "$NGINX_CONF_PATH" \
      "$SSH_OPTIONS" \
      "$SERVER_PORT" \
      "$SSH_TARGET" \
      "ssh_exec" \
      "$ssl_cert_name" \
      "$cert_dir" \
      "$SSL_CERT_DIR"
  else
    # 不使用 SSL 证书的简化版本
    prepare_nginx_server "$NGINX_CONF_PATH" "ssh_exec" "$SSH_TARGET"
    print_info "上传配置文件..."
    scp $SSH_OPTIONS -P "${SERVER_PORT}" "$nginx_local_conf" "${SSH_TARGET}:${NGINX_CONF_PATH}"
    test_and_reload_nginx "$NGINX_CONF_PATH" "ssh_exec" "$SSH_TARGET"
  fi

  echo ""
  print_success "Nginx 配置更新完成！"
  print_info "配置文件: ${NGINX_CONF_PATH}"
  [ "$ssl_cert_files_exist" = true ] && print_info "SSL 证书: ${SSL_CERT_DIR}/${ssl_cert_name}.*"
  echo ""
  print_info "API 端点:"
  echo -e "  ${GREEN}https://api.book-excerpt.zhifu.tech/api/config${NC}"
  echo -e "  ${GREEN}https://api.book-excerpt.zhifu.tech/health${NC}"
}

# ============================================
# 检查防火墙
# ============================================
cmd_firewall() {
  print_title "检查防火墙配置"
  
  ssh_exec << 'ENDSSH'
set -e

echo "检查防火墙状态..."
echo ""

# 检查 firewalld
if command -v firewall-cmd &> /dev/null; then
  echo "检测到 firewalld"
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "✓ firewalld 正在运行"
    echo ""
    echo "当前开放的端口:"
    firewall-cmd --list-ports 2>/dev/null || echo "无开放端口"
    echo ""
    if firewall-cmd --list-ports 2>/dev/null | grep -q "3001"; then
      echo "✓ 端口 3001 已开放"
    else
      echo "✗ 端口 3001 未开放"
      echo ""
      echo "开放端口 3001:"
      echo "  firewall-cmd --add-port=3001/tcp --permanent"
      echo "  firewall-cmd --reload"
    fi
  else
    echo "⚠ firewalld 未运行"
  fi
fi

# 检查 ufw
if command -v ufw &> /dev/null; then
  echo ""
  echo "检测到 ufw"
  ufw status 2>/dev/null || echo "ufw 未运行"
fi

# 检查 iptables
if command -v iptables &> /dev/null; then
  echo ""
  echo "检测到 iptables"
  echo "检查 3001 端口规则:"
  iptables -L -n | grep 3001 || echo "未找到 3001 端口规则"
fi

echo ""
echo "=========================================="
echo "注意: 云服务器通常使用安全组管理防火墙"
echo "请确保在云控制台开放 3001 端口"
echo "=========================================="
ENDSSH

  echo ""
  print_success "防火墙检查完成！"
}

# ============================================
# 主函数
# ============================================
main() {
  # 显示欢迎界面
  show_welcome "$1"

  # 解析命令
  COMMAND="${1:-help}"

  case "$COMMAND" in
    deploy)
      cmd_deploy
      ;;
    restart)
      cmd_restart
      ;;
    status)
      cmd_status
      ;;
    check)
      cmd_check
      ;;
    fix-502)
      cmd_fix_502
      ;;
    logs)
      cmd_logs "$2"
      ;;
    update-nginx)
      cmd_update_nginx "$2"
      ;;
    install-pm2)
      cmd_install_pm2
      ;;
    update-ssh-key)
      cmd_update_ssh_key
      ;;
    firewall)
      cmd_firewall
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      print_error "未知命令 '$COMMAND'"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

# 初始化 SSH 连接（在加载共用脚本后）
init_ssh_connection

# 执行主函数
main "$@"

