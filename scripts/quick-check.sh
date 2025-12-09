#!/bin/bash

# 快速检查服务状态脚本
# 使用方法: ./quick-check.sh

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

echo -e "${GREEN}快速检查服务状态...${NC}"

ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
cd /opt/book-excerpt-generator-server || exit 1

echo "=========================================="
echo "1. 检查 PM2 进程状态"
echo "=========================================="
if command -v pm2 &> /dev/null; then
  pm2 list
  echo ""
  if pm2 describe book-excerpt-server &> /dev/null; then
    echo "✓ PM2 进程存在"
    pm2 describe book-excerpt-server | grep -E "status|pid|uptime|restarts" | head -5
  else
    echo "✗ PM2 进程不存在"
  fi
else
  echo "PM2 未安装，检查 node 进程..."
  if pgrep -f "node.*server.js" > /dev/null; then
    echo "✓ Node.js 进程正在运行"
    ps aux | grep "node.*server.js" | grep -v grep
  else
    echo "✗ Node.js 进程未运行"
  fi
fi

echo ""
echo "=========================================="
echo "2. 检查端口监听"
echo "=========================================="
if netstat -tlnp 2>/dev/null | grep :3001 > /dev/null || ss -tlnp 2>/dev/null | grep :3001 > /dev/null; then
  echo -e "\033[0;32m✓ 端口 3001 正在监听\033[0m"
  netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001
else
  echo -e "\033[0;31m✗ 端口 3001 未监听\033[0m"
fi

echo ""
echo "=========================================="
echo "3. 测试本地连接"
echo "=========================================="
echo "测试健康检查端点..."
if curl -s http://localhost:3001/health > /dev/null; then
  echo -e "\033[0;32m✓ 本地健康检查成功\033[0m"
  echo "响应内容:"
  curl -s http://localhost:3001/health
  echo ""
  echo ""
  echo "测试 API 端点..."
  if curl -s http://localhost:3001/api/config > /dev/null; then
    echo -e "\033[0;32m✓ API 端点响应正常\033[0m"
    echo "响应内容（前 5 行）:"
    curl -s http://localhost:3001/api/config | head -5
  else
    echo -e "\033[0;31m✗ API 端点无响应\033[0m"
  fi
else
  echo -e "\033[0;31m✗ 本地健康检查失败\033[0m"
  echo "服务可能未启动或端口未监听"
fi

echo ""
echo "=========================================="
echo "4. 查看最近日志（错误）"
echo "=========================================="
if [ -f "logs/error.log" ]; then
  echo "最近 10 行错误日志:"
  tail -10 logs/error.log
else
  echo "错误日志文件不存在"
fi

echo ""
echo "=========================================="
echo "5. 查看最近日志（输出）"
echo "=========================================="
if [ -f "logs/out.log" ]; then
  echo "最近 10 行输出日志:"
  tail -10 logs/out.log
else
  echo "输出日志文件不存在"
fi

echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
ENDSSH

echo ""
echo -e "${GREEN}检查完成！${NC}"
echo -e "${YELLOW}如果服务正常，可以访问：${NC}"
echo -e "  健康检查: http://${SERVER_HOST}:3001/health"
echo -e "  API 端点: http://${SERVER_HOST}:3001/api/config"
echo ""
echo -e "${YELLOW}如果无法访问，请检查：${NC}"
echo -e "  1. 云服务器安全组是否开放端口 3001"
echo -e "  2. 服务是否正常运行（查看上方检查结果）"

