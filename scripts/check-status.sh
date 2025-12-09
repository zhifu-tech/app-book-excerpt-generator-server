#!/bin/bash

# 检查服务器状态脚本
# 使用方法: ./check-status.sh

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

echo -e "${GREEN}检查服务器状态...${NC}"

ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
echo "=========================================="
echo "1. 检查 Node.js 是否安装"
echo "=========================================="
if command -v node &> /dev/null; then
  echo -e "\033[0;32m✓ Node.js 已安装: $(node --version)\033[0m"
  echo -e "\033[0;32m✓ npm 版本: $(npm --version)\033[0m"
else
  echo -e "\033[0;31m✗ Node.js 未安装\033[0m"
fi

echo ""
echo "=========================================="
echo "2. 检查服务目录"
echo "=========================================="
if [ -d "/opt/book-excerpt-generator-server" ]; then
  echo -e "\033[0;32m✓ 服务目录存在\033[0m"
  ls -la /opt/book-excerpt-generator-server/ | head -10
else
  echo -e "\033[0;31m✗ 服务目录不存在\033[0m"
fi

echo ""
echo "=========================================="
echo "3. 检查 Node.js 进程"
echo "=========================================="
if pgrep -f "node.*server.js" > /dev/null; then
  echo -e "\033[0;32m✓ Node.js 进程正在运行\033[0m"
  ps aux | grep "node.*server.js" | grep -v grep
else
  echo -e "\033[0;31m✗ Node.js 进程未运行\033[0m"
fi

echo ""
echo "=========================================="
echo "4. 检查 PM2 进程"
echo "=========================================="
if command -v pm2 &> /dev/null; then
  echo "PM2 已安装，检查进程："
  pm2 list
else
  echo -e "\033[0;33m⚠ PM2 未安装\033[0m"
fi

echo ""
echo "=========================================="
echo "5. 检查端口监听"
echo "=========================================="
if netstat -tlnp 2>/dev/null | grep :3001 > /dev/null || ss -tlnp 2>/dev/null | grep :3001 > /dev/null; then
  echo -e "\033[0;32m✓ 端口 3001 正在监听\033[0m"
  netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001
else
  echo -e "\033[0;31m✗ 端口 3001 未监听\033[0m"
fi

echo ""
echo "=========================================="
echo "6. 检查防火墙"
echo "=========================================="
if command -v firewall-cmd &> /dev/null; then
  echo "firewall-cmd 状态："
  firewall-cmd --list-ports 2>/dev/null || echo "无法获取防火墙状态"
elif command -v ufw &> /dev/null; then
  echo "ufw 状态："
  ufw status 2>/dev/null || echo "无法获取防火墙状态"
else
  echo "未检测到防火墙管理工具"
fi

echo ""
echo "=========================================="
echo "7. 检查日志（最近 20 行）"
echo "=========================================="
if [ -f "/opt/book-excerpt-generator-server/logs/error.log" ]; then
  echo "错误日志："
  tail -20 /opt/book-excerpt-generator-server/logs/error.log
else
  echo "错误日志文件不存在"
fi

if [ -f "/opt/book-excerpt-generator-server/logs/out.log" ]; then
  echo ""
  echo "输出日志："
  tail -20 /opt/book-excerpt-generator-server/logs/out.log
else
  echo "输出日志文件不存在"
fi

echo ""
echo "=========================================="
echo "8. 测试本地连接"
echo "=========================================="
cd /opt/book-excerpt-generator-server 2>/dev/null || echo "无法进入服务目录"
if curl -s http://localhost:3001/health > /dev/null; then
  echo -e "\033[0;32m✓ 本地健康检查成功\033[0m"
  curl -s http://localhost:3001/health | head -5
else
  echo -e "\033[0;31m✗ 本地健康检查失败\033[0m"
fi

echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
ENDSSH

echo ""
echo -e "${GREEN}状态检查完成！${NC}"


