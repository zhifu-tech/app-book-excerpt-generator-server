#!/bin/bash

# ============================================
# Book Excerpt Generator Server - 统一管理脚本
# ============================================
# 整合所有部署和管理功能
# 使用方法: ./book-excerpt-server.sh [command] [options]
# ============================================

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================
# 配置变量
# ============================================

# 服务器配置
SERVER_HOST="8.138.183.116"
SERVER_USER="root"
SERVER_PORT="22"
APP_DIR="/opt/book-excerpt-generator-server"
APP_PORT="3001"

# SSH 配置
SSH_KEY_NAME="id_rsa_book_excerpt"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_ALIAS="book-excerpt-server"

# 初始化 SSH 连接参数
init_ssh_connection() {
  if [ -f "$SSH_KEY_PATH" ]; then
    SSH_OPTIONS="-i $SSH_KEY_PATH"
    SSH_TARGET="$SERVER_USER@$SERVER_HOST"
  elif ssh -o ConnectTimeout=1 -o BatchMode=yes "$SSH_ALIAS" "echo" &>/dev/null 2>&1; then
    SSH_OPTIONS=""
    SSH_TARGET="$SSH_ALIAS"
  else
    SSH_OPTIONS=""
    SSH_TARGET="$SERVER_USER@$SERVER_HOST"
  fi
}

# 自动初始化 SSH 连接
init_ssh_connection

# 颜色输出定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# 工具函数
# ============================================

# 打印成功消息
print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# 打印警告消息
print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# 打印错误消息
print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# 打印信息消息
print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# 打印标题
print_title() {
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}==========================================${NC}"
}

# ============================================
# 欢迎界面
# ============================================
show_welcome() {
  echo ""
  echo -e "${CYAN}"
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
  echo -e "${NC}"
  echo -e "${CYAN}              Book Excerpt Generator Server@Zhifu's Tech${NC}"
  echo ""
  local cmd="${1:-help}"
  echo -e "${YELLOW}版本: 0.2.0${NC}"
  echo -e "${YELLOW}服务器: ${SERVER_HOST}${NC}"
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
  echo -e "  ${GREEN}deploy${NC}             部署服务到服务器"
  echo -e "  ${GREEN}restart${NC}             重启服务"
  echo -e "  ${GREEN}status${NC}              检查服务状态"
  echo -e "  ${GREEN}check${NC}              快速检查服务"
  echo -e "  ${GREEN}fix-502${NC}            修复 502 错误"
  echo -e "  ${GREEN}logs${NC}               查看服务日志"
  echo -e "  ${GREEN}update-nginx${NC}        更新 Nginx 配置文件"
  echo -e "  ${GREEN}install-pm2${NC}        安装 PM2 进程管理器"
  echo -e "  ${GREEN}setup-ssh${NC}          设置 SSH 密钥认证"
  echo -e "  ${GREEN}firewall${NC}           检查防火墙配置"
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
  cd "$PROJECT_ROOT"
  
  # 检查本地文件
  if [ ! -f "package.json" ]; then
    print_error "未找到 package.json，请确保在项目根目录执行"
    exit 1
  fi

  if [ ! -d "src" ]; then
    print_error "未找到 src/ 目录，请确保在项目根目录执行"
    exit 1
  fi

  # 创建临时部署目录
  TEMP_DIR=$(mktemp -d)
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
  ssh $SSH_OPTIONS -p ${SERVER_PORT} ${SSH_TARGET} "mkdir -p ${APP_DIR}"
  scp $SSH_OPTIONS -r -P ${SERVER_PORT} "$TEMP_DIR"/* ${SSH_TARGET}:${APP_DIR}/

  # 清理临时目录
  rm -rf "$TEMP_DIR"

  # 在服务器上执行部署操作
  print_info "在服务器上安装依赖并启动服务..."
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << ENDSSH
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
# 设置 SSH 密钥
# ============================================
cmd_setup_ssh() {
  print_title "设置 SSH 密钥认证"
  
  echo -e "${YELLOW}这将帮助您设置 SSH 密钥认证，避免每次输入密码${NC}"
  echo ""
  
  # 检查是否已有密钥
  if [ -f "$SSH_KEY_PATH" ]; then
    print_warning "SSH 密钥已存在: ${SSH_KEY_PATH}"
    read -p "是否要重新生成？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "跳过密钥生成"
      exit 0
    fi
  fi
  
  # 生成 SSH 密钥
  print_info "生成 SSH 密钥..."
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "book-excerpt-server-$(date +%Y%m%d)"
  
  # 复制公钥到服务器
  print_info "复制公钥到服务器..."
  ssh-copy-id -i "${SSH_KEY_PATH}.pub" $SSH_OPTIONS -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST}
  
  print_success "SSH 密钥设置完成！"
  echo -e "${YELLOW}现在可以使用密钥认证连接服务器，无需输入密码${NC}"
}

# ============================================
# 更新 Nginx 配置
# ============================================
cmd_update_nginx() {
  # 确定配置文件路径
  if [ -n "$1" ]; then
    LOCAL_CONF="$1"
  else
    LOCAL_CONF="$SCRIPT_DIR/nginx.conf"
  fi

  # 检查本地配置文件是否存在
  if [ ! -f "$LOCAL_CONF" ]; then
    print_error "配置文件不存在: ${LOCAL_CONF}"
    exit 1
  fi

  # 确定证书文件路径（使用 api.book-excerpt.zhifu.tech_nginx 目录）
  CERT_DIR="$SCRIPT_DIR/api.book-excerpt.zhifu.tech_nginx"
  # 优先使用 api 子域名的证书，如果没有则回退到主域名证书
  CERT_BUNDLE_CRT="$CERT_DIR/api.book-excerpt.zhifu.tech_bundle.crt"
  CERT_BUNDLE_PEM="$CERT_DIR/api.book-excerpt.zhifu.tech_bundle.pem"
  CERT_CRT="$CERT_DIR/api.book-excerpt.zhifu.tech.crt"
  CERT_PEM="$CERT_DIR/api.book-excerpt.zhifu.tech.pem"
  CERT_KEY="$CERT_DIR/api.book-excerpt.zhifu.tech.key"
  
  # 如果 API 子域名证书不存在，回退到主域名证书
  if [ ! -f "$CERT_KEY" ]; then
    FALLBACK_CERT_DIR="$SCRIPT_DIR/book-excerpt.zhifu.tech_nginx"
    if [ -f "$FALLBACK_CERT_DIR/book-excerpt.zhifu.tech.key" ]; then
      CERT_DIR="$FALLBACK_CERT_DIR"
      CERT_BUNDLE_CRT="$CERT_DIR/book-excerpt.zhifu.tech_bundle.crt"
      CERT_BUNDLE_PEM="$CERT_DIR/book-excerpt.zhifu.tech_bundle.pem"
      CERT_CRT="$CERT_DIR/book-excerpt.zhifu.tech.crt"
      CERT_PEM="$CERT_DIR/book-excerpt.zhifu.tech.pem"
      CERT_KEY="$CERT_DIR/book-excerpt.zhifu.tech.key"
      print_info "使用主域名证书目录: ${CERT_DIR}"
    fi
  fi

  # 检查证书文件是否存在（支持多种命名格式）
  CERT_FILES_EXIST=false
  if [ -f "$CERT_BUNDLE_CRT" ] && [ -f "$CERT_KEY" ]; then
    CERT_FILES_EXIST=true
    CERT_FILE="$CERT_BUNDLE_CRT"
  elif [ -f "$CERT_BUNDLE_PEM" ] && [ -f "$CERT_KEY" ]; then
    CERT_FILES_EXIST=true
    CERT_FILE="$CERT_BUNDLE_PEM"
  elif [ -f "$CERT_CRT" ] && [ -f "$CERT_KEY" ]; then
    CERT_FILES_EXIST=true
    CERT_FILE="$CERT_CRT"
  elif [ -f "$CERT_PEM" ] && [ -f "$CERT_KEY" ]; then
    CERT_FILES_EXIST=true
    CERT_FILE="$CERT_PEM"
  fi

  if [ "$CERT_FILES_EXIST" = true ]; then
    print_success "找到证书文件"
    print_info "  证书文件: ${CERT_FILE}"
    print_info "  私钥文件: ${CERT_KEY}"
  else
    print_warning "未找到证书文件，将跳过证书上传"
    print_info "  证书目录: ${CERT_DIR}"
    print_info "  预期文件:"
    print_info "    - ${CERT_BUNDLE_CRT}"
    print_info "    - ${CERT_BUNDLE_PEM}"
    print_info "    - ${CERT_CRT}"
    print_info "    - ${CERT_PEM}"
    print_info "    - ${CERT_KEY}"
  fi

  NGINX_CONF_PATH="/etc/nginx/conf.d/book-excerpt-generator-server.conf"
  BACKUP_DIR="/etc/nginx/conf.d/backup"

  print_title "更新 Nginx 配置到服务器 ${SERVER_HOST}"
  print_info "本地配置文件: ${LOCAL_CONF}"
  print_info "服务器配置文件: ${NGINX_CONF_PATH}"

  # 在服务器上执行更新操作
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
set -e

# 查找 nginx 命令路径
NGINX_CMD=""
if command -v nginx &> /dev/null; then
  NGINX_CMD="nginx"
elif [ -f "/usr/sbin/nginx" ]; then
  NGINX_CMD="/usr/sbin/nginx"
elif [ -f "/usr/local/sbin/nginx" ]; then
  NGINX_CMD="/usr/local/sbin/nginx"
elif [ -f "/sbin/nginx" ]; then
  NGINX_CMD="/sbin/nginx"
fi

# 检查 Nginx 是否安装
if [ -z "$NGINX_CMD" ]; then
  echo -e "\033[0;33m⚠ Nginx 未安装或未找到，将继续上传配置文件\033[0m"
  echo "可以稍后安装 Nginx 并测试配置"
else
  NGINX_VERSION=$($NGINX_CMD -v 2>&1)
  echo -e "\033[0;32m✓ Nginx 已安装: $NGINX_VERSION\033[0m"
fi

# 创建备份目录
mkdir -p /etc/nginx/conf.d/backup
echo -e "\033[0;32m✓ 备份目录已创建\033[0m"

# 备份现有配置（如果存在）
if [ -f "/etc/nginx/conf.d/book-excerpt-generator-server.conf" ]; then
  BACKUP_FILE="/etc/nginx/conf.d/backup/book-excerpt-generator-server.conf.backup.$(date +%Y%m%d_%H%M%S)"
  cp /etc/nginx/conf.d/book-excerpt-generator-server.conf "$BACKUP_FILE"
  echo -e "\033[0;32m✓ 已备份现有配置到: $BACKUP_FILE\033[0m"
else
  echo -e "\033[0;33m⚠ 配置文件不存在，将创建新配置\033[0m"
fi

# 创建配置目录（如果不存在）
mkdir -p /etc/nginx/conf.d
echo -e "\033[0;32m✓ 配置目录已准备\033[0m"
ENDSSH

  # 上传配置文件
  print_info "上传配置文件到服务器..."
  scp $SSH_OPTIONS -P ${SERVER_PORT} "$LOCAL_CONF" ${SSH_TARGET}:${NGINX_CONF_PATH}

  # 上传证书文件（如果存在）
  if [ "$CERT_FILES_EXIST" = true ]; then
    print_info "上传 SSL 证书到服务器..."
    
    # 在服务器上创建 SSL 证书目录
    ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << ENDSSH
set -e
mkdir -p /etc/nginx/ssl
echo -e "\033[0;32m✓ SSL 证书目录已创建: /etc/nginx/ssl\033[0m"
ENDSSH
    
    # 确定证书名称（根据实际使用的证书目录）
    if [[ "$CERT_DIR" == *"api.book-excerpt.zhifu.tech_nginx"* ]]; then
      CERT_NAME="api.book-excerpt.zhifu.tech"
    else
      CERT_NAME="book-excerpt.zhifu.tech"
    fi
    
    # 上传证书文件（根据实际找到的文件类型上传）
    if [ -f "$CERT_BUNDLE_CRT" ]; then
      scp $SSH_OPTIONS -P ${SERVER_PORT} "$CERT_BUNDLE_CRT" ${SSH_TARGET}:/etc/nginx/ssl/${CERT_NAME}_bundle.crt
      print_success "证书文件已上传 (bundle.crt)"
    elif [ -f "$CERT_BUNDLE_PEM" ]; then
      scp $SSH_OPTIONS -P ${SERVER_PORT} "$CERT_BUNDLE_PEM" ${SSH_TARGET}:/etc/nginx/ssl/${CERT_NAME}_bundle.pem
      print_success "证书文件已上传 (bundle.pem)"
    elif [ -f "$CERT_CRT" ]; then
      scp $SSH_OPTIONS -P ${SERVER_PORT} "$CERT_CRT" ${SSH_TARGET}:/etc/nginx/ssl/${CERT_NAME}.crt
      print_success "证书文件已上传 (.crt)"
    elif [ -f "$CERT_PEM" ]; then
      scp $SSH_OPTIONS -P ${SERVER_PORT} "$CERT_PEM" ${SSH_TARGET}:/etc/nginx/ssl/${CERT_NAME}.pem
      print_success "证书文件已上传 (.pem)"
    fi
    
    # 上传私钥文件
    scp $SSH_OPTIONS -P ${SERVER_PORT} "$CERT_KEY" ${SSH_TARGET}:/etc/nginx/ssl/${CERT_NAME}.key
    print_success "私钥文件已上传"
    
    # 设置证书文件权限
    ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << ENDSSH
set -e
# 设置证书文件权限（644）- 支持多种格式
chmod 644 /etc/nginx/ssl/${CERT_NAME}_bundle.* 2>/dev/null || true
chmod 644 /etc/nginx/ssl/${CERT_NAME}.crt 2>/dev/null || true
chmod 644 /etc/nginx/ssl/${CERT_NAME}.pem 2>/dev/null || true
# 设置私钥文件权限（600，只有所有者可读）
chmod 600 /etc/nginx/ssl/${CERT_NAME}.key
# 设置所有者
chown root:root /etc/nginx/ssl/${CERT_NAME}.* 2>/dev/null || true
echo -e "\033[0;32m✓ 证书文件权限已设置\033[0m"
ENDSSH
  fi

  # 在服务器上验证和应用配置
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
set -e

# 检查主配置文件是否包含 conf.d
echo "检查主配置文件..."
if ! grep -q "include.*conf.d" /etc/nginx/nginx.conf 2>/dev/null; then
  echo -e "\033[0;33m⚠ 主配置文件未包含 conf.d 目录\033[0m"
  echo "检查是否需要添加 include 指令..."
  
  # 检查是否有 http 块
  if grep -q "http {" /etc/nginx/nginx.conf; then
    echo "主配置文件包含 http 块，但可能缺少 include 指令"
    echo "建议手动添加: include /etc/nginx/conf.d/*.conf;"
    echo "位置: 在 http {} 块内"
  fi
else
  echo -e "\033[0;32m✓ 主配置文件已包含 conf.d 目录\033[0m"
fi

# 确保 conf.d 目录存在
if [ ! -d "/etc/nginx/conf.d" ]; then
  echo "创建 conf.d 目录..."
  mkdir -p /etc/nginx/conf.d
  echo -e "\033[0;32m✓ conf.d 目录已创建\033[0m"
fi

# 设置文件权限
chmod 644 /etc/nginx/conf.d/book-excerpt-generator-server.conf
chown root:root /etc/nginx/conf.d/book-excerpt-generator-server.conf
echo -e "\033[0;32m✓ 文件权限已设置\033[0m"
ENDSSH

  # 测试 Nginx 配置
  echo ""
  print_title "测试 Nginx 配置"
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
set -e

# 查找 nginx 命令路径
NGINX_CMD=""
if command -v nginx &> /dev/null; then
  NGINX_CMD="nginx"
elif [ -f "/usr/sbin/nginx" ]; then
  NGINX_CMD="/usr/sbin/nginx"
elif [ -f "/usr/local/sbin/nginx" ]; then
  NGINX_CMD="/usr/local/sbin/nginx"
elif [ -f "/sbin/nginx" ]; then
  NGINX_CMD="/sbin/nginx"
fi

if [ ! -z "$NGINX_CMD" ]; then
  if $NGINX_CMD -t 2>&1; then
    echo -e "\033[0;32m✓ Nginx 配置语法正确\033[0m"
  else
    echo -e "\033[0;31m✗ Nginx 配置语法错误\033[0m"
    echo ""
    echo "如果配置有误，可以从备份恢复："
    echo "  ls -lt /etc/nginx/conf.d/backup/book-excerpt-generator-server.conf.backup.* | head -1"
    exit 1
  fi
else
  echo -e "\033[0;33m⚠ 未找到 nginx 命令，跳过配置测试\033[0m"
  echo "配置文件已上传，但无法验证语法"
  echo "可以手动测试: /usr/sbin/nginx -t 或 systemctl status nginx"
fi
ENDSSH

  # 重新加载 Nginx
  echo ""
  print_title "重新加载 Nginx 配置"
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
set -e

# 尝试重新加载（不中断服务）
if systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null; then
  echo -e "\033[0;32m✓ Nginx 配置已重新加载\033[0m"
elif systemctl restart nginx 2>/dev/null || service nginx restart 2>/dev/null; then
  echo -e "\033[0;33m⚠ 使用 restart 方式重新加载（服务会短暂中断）\033[0m"
  echo -e "\033[0;32m✓ Nginx 已重启\033[0m"
else
  echo -e "\033[0;33m⚠ 无法重新加载 Nginx（可能未运行）\033[0m"
  echo "配置文件已上传，可以手动启动:"
  echo "  systemctl start nginx"
fi

# 检查 Nginx 状态
echo ""
echo "检查 Nginx 状态..."
if systemctl is-active --quiet nginx 2>/dev/null || service nginx status &>/dev/null; then
  echo -e "\033[0;32m✓ Nginx 正在运行\033[0m"
  systemctl status nginx --no-pager -l 2>/dev/null | head -10 || service nginx status 2>/dev/null | head -10
else
  echo -e "\033[0;33m⚠ Nginx 未运行\033[0m"
  echo "配置文件已上传，可以手动启动:"
  echo "  systemctl start nginx"
fi

# 检查端口监听
echo ""
echo "检查端口监听..."
if netstat -tlnp 2>/dev/null | grep -E 'nginx.*:(80|443)' > /dev/null || \
   ss -tlnp 2>/dev/null | grep -E 'nginx.*:(80|443)' > /dev/null; then
  echo -e "\033[0;32m✓ Nginx 端口正在监听\033[0m"
  netstat -tlnp 2>/dev/null | grep -E 'nginx.*:(80|443)' || \
  ss -tlnp 2>/dev/null | grep -E 'nginx.*:(80|443)'
else
  echo -e "\033[0;33m⚠ 未检测到 Nginx 端口监听\033[0m"
fi

echo ""
echo "=========================================="
echo "配置更新完成"
echo "=========================================="
ENDSSH

  echo ""
  print_success "Nginx 配置更新完成！"
  echo -e "${BLUE}========================================${NC}"
  echo -e "${YELLOW}配置文件位置:${NC}"
  echo -e "  ${GREEN}${NGINX_CONF_PATH}${NC}"
  if [ "$CERT_FILES_EXIST" = true ]; then
    echo ""
    echo -e "${YELLOW}SSL 证书位置:${NC}"
    # 根据实际使用的证书目录确定证书名称
    if [[ "$CERT_DIR" == *"api.book-excerpt.zhifu.tech_nginx"* ]]; then
      echo -e "  ${GREEN}/etc/nginx/ssl/api.book-excerpt.zhifu.tech_bundle.*${NC}"
      echo -e "  ${GREEN}/etc/nginx/ssl/api.book-excerpt.zhifu.tech.key${NC}"
    else
      echo -e "  ${GREEN}/etc/nginx/ssl/book-excerpt.zhifu.tech_bundle.*${NC}"
      echo -e "  ${GREEN}/etc/nginx/ssl/book-excerpt.zhifu.tech.key${NC}"
    fi
  fi
  echo ""
  echo -e "${YELLOW}API 端点:${NC}"
  echo -e "  ${GREEN}https://api.book-excerpt.zhifu.tech/api/config${NC}"
  echo -e "  ${GREEN}https://api.book-excerpt.zhifu.tech/health${NC}"
}

# ============================================
# 检查防火墙
# ============================================
cmd_firewall() {
  print_title "检查防火墙配置"
  
  ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
    setup-ssh)
      cmd_setup_ssh
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

# 执行主函数
main "$@"

