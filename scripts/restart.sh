#!/bin/bash

# 重启服务脚本
# 使用方法: ./restart.sh

set -e

# 配置变量
SERVER_HOST="8.138.183.116"
SERVER_USER="root"
SERVER_PORT="22"
APP_DIR="/opt/book-excerpt-generator-server"

# SSH 密钥配置（自动检测）
SSH_KEY_NAME="id_rsa_book_excerpt"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_ALIAS="book-excerpt-server"

# 检测 SSH 密钥或别名
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

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}重启服务器上的服务...${NC}"

ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
cd /opt/book-excerpt-generator-server

# 检查并安装 PM2（如果未安装）
if ! command -v pm2 &> /dev/null; then
  echo "PM2 未安装，正在安装..."
  npm install -g pm2
fi

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
  fi
elif command -v fuser &> /dev/null; then
  fuser -k 3001/tcp 2>/dev/null || true
fi

# 停止所有 node server.js 进程
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f "node.*/opt/book-excerpt-generator-server" 2>/dev/null || true

# 等待端口释放
echo "等待端口释放..."
sleep 3

# 使用 PM2 管理服务
if command -v pm2 &> /dev/null; then
  echo "使用 PM2 重启服务..."
  pm2 start ecosystem.config.cjs
  pm2 save
  sleep 2
  pm2 status
else
  echo "警告: PM2 安装失败，使用 node 直接启动..."
  # 启动服务
  echo "启动服务..."
  nohup node server.js > logs/out.log 2> logs/error.log &
  sleep 2
  
  # 检查进程
  echo "检查进程..."
  ps aux | grep "node.*server.js" | grep -v grep || echo "进程未找到"
fi

echo ""
echo "测试服务..."
sleep 2
curl -s http://localhost:3001/health && echo "" || echo "服务可能还在启动中..."
ENDSSH

echo -e "${GREEN}重启完成！${NC}"
echo -e "${YELLOW}测试地址: http://${SERVER_HOST}:3001/health${NC}"

