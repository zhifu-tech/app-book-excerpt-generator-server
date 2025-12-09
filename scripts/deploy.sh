#!/bin/bash

# 部署脚本 - 书摘卡片生成器配置服务端
# 使用方法: ./deploy.sh

set -e

# 配置变量
SERVER_HOST="8.138.183.116"
SERVER_USER="root"  # 根据实际情况修改
SERVER_PORT="22"
APP_DIR="/opt/book-excerpt-generator-server"
REMOTE_DIR="source/apps/book-excerpt-generator-server"

# SSH 密钥配置（自动检测）
SSH_KEY_NAME="id_rsa_book_excerpt"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_ALIAS="book-excerpt-server"

# 检测 SSH 密钥或别名
if [ -f "$SSH_KEY_PATH" ]; then
  SSH_OPTIONS="-i $SSH_KEY_PATH"
  SSH_TARGET="$SERVER_USER@$SERVER_HOST"
elif ssh -o ConnectTimeout=1 -o BatchMode=yes "$SSH_ALIAS" "echo" &>/dev/null; then
  SSH_OPTIONS=""
  SSH_TARGET="$SSH_ALIAS"
else
  SSH_OPTIONS=""
  SSH_TARGET="$SERVER_USER@$SERVER_HOST"
fi

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始部署到服务器 ${SERVER_HOST}...${NC}"

# 检查本地文件
if [ ! -f "package.json" ]; then
  echo -e "${RED}错误: 未找到 package.json，请确保在项目根目录执行${NC}"
  exit 1
fi

# 检查 src 目录
if [ ! -d "src" ]; then
  echo -e "${RED}错误: 未找到 src/ 目录，请确保在项目根目录执行${NC}"
  exit 1
fi

# 创建临时部署目录
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}创建临时目录: ${TEMP_DIR}${NC}"

# 复制必要文件
echo -e "${YELLOW}复制文件...${NC}"
cp -r server.js package.json package-lock.json ecosystem.config.cjs example.env "$TEMP_DIR/"

# 复制源代码目录（重要！）
if [ -d "src" ]; then
  cp -r src "$TEMP_DIR/"
  echo -e "${GREEN}✓ 已复制 src/ 目录${NC}"
else
  echo -e "${RED}✗ 错误: 未找到 src/ 目录${NC}"
  exit 1
fi

# 创建数据目录
mkdir -p "$TEMP_DIR/data"

# 创建 .gitkeep 文件（如果需要）
touch "$TEMP_DIR/data/.gitkeep"

# 复制服务器端检查脚本（如果存在）
if [ -f "server-check.sh" ]; then
  cp server-check.sh "$TEMP_DIR/" 2>/dev/null || true
fi

# 上传文件到服务器
echo -e "${YELLOW}上传文件到服务器...${NC}"
ssh $SSH_OPTIONS -p ${SERVER_PORT} ${SSH_TARGET} "mkdir -p ${APP_DIR}"
scp $SSH_OPTIONS -r -P ${SERVER_PORT} "$TEMP_DIR"/* ${SSH_TARGET}:${APP_DIR}/

# 清理临时目录
rm -rf "$TEMP_DIR"

# 在服务器上执行部署操作
echo -e "${YELLOW}在服务器上安装 Node.js、依赖并启动服务...${NC}"
ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
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
  # 使用 lsof 查找占用端口的进程
  PID=$(lsof -ti:3001 2>/dev/null || true)
  if [ ! -z "$PID" ]; then
    echo "发现占用 3001 端口的进程: $PID"
    kill -9 $PID 2>/dev/null || true
    echo "已终止进程 $PID"
  fi
elif command -v fuser &> /dev/null; then
  # 使用 fuser 查找并杀死占用端口的进程
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

echo -e "${GREEN}部署完成！${NC}"
echo -e "${YELLOW}服务器地址: http://${SERVER_HOST}:3001${NC}"
echo -e "${YELLOW}健康检查: http://${SERVER_HOST}:3001/health${NC}"
echo -e "${YELLOW}API 端点: http://${SERVER_HOST}:3001/api/config${NC}"

