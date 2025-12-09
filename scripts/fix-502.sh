#!/bin/bash

# 修复 502 错误脚本
# 诊断并修复服务器问题

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

echo -e "${GREEN}诊断并修复 502 错误...${NC}"

ssh $SSH_OPTIONS -t -p ${SERVER_PORT} ${SSH_TARGET} << 'ENDSSH'
cd /opt/book-excerpt-generator-server || exit 1

echo "=========================================="
echo "1. 检查 PM2 进程状态"
echo "=========================================="
if command -v pm2 &> /dev/null; then
  pm2 list
  echo ""
  echo "检查 book-excerpt-server 状态："
  pm2 describe book-excerpt-server 2>/dev/null || echo "进程不存在"
else
  echo "PM2 未安装"
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
echo "3. 查看最近错误日志"
echo "=========================================="
if [ -f "logs/error.log" ]; then
  echo "最近 30 行错误日志："
  tail -30 logs/error.log
else
  echo "错误日志文件不存在"
fi

echo ""
echo "=========================================="
echo "4. 查看最近输出日志"
echo "=========================================="
if [ -f "logs/out.log" ]; then
  echo "最近 30 行输出日志："
  tail -30 logs/out.log
else
  echo "输出日志文件不存在"
fi

echo ""
echo "=========================================="
echo "5. 停止所有相关进程并释放端口"
echo "=========================================="
# 停止 PM2 进程
if command -v pm2 &> /dev/null; then
  pm2 delete book-excerpt-server 2>/dev/null || true
  pm2 stop all 2>/dev/null || true
  echo "已停止 PM2 进程"
fi

# 停止直接运行的 node 进程
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f "node.*/opt/book-excerpt-generator-server" 2>/dev/null || true
echo "已停止直接运行的 node 进程"

# 查找并杀死占用 3001 端口的进程
echo "查找并释放 3001 端口..."
if command -v lsof &> /dev/null; then
  PID=$(lsof -ti:3001 2>/dev/null || true)
  if [ ! -z "$PID" ]; then
    echo "发现占用 3001 端口的进程: $PID"
    kill -9 $PID 2>/dev/null || true
    echo "已终止进程 $PID"
  else
    echo "端口 3001 未被占用"
  fi
elif command -v fuser &> /dev/null; then
  fuser -k 3001/tcp 2>/dev/null || true
  echo "已尝试终止占用 3001 端口的进程"
else
  echo "未找到 lsof 或 fuser，使用 netstat/ss 查找进程..."
  if netstat -tlnp 2>/dev/null | grep :3001 > /dev/null; then
    PID=$(netstat -tlnp 2>/dev/null | grep :3001 | awk '{print $7}' | cut -d'/' -f1 | head -1)
    if [ ! -z "$PID" ] && [ "$PID" != "-" ]; then
      echo "发现占用 3001 端口的进程: $PID"
      kill -9 $PID 2>/dev/null || true
    fi
  elif ss -tlnp 2>/dev/null | grep :3001 > /dev/null; then
    PID=$(ss -tlnp 2>/dev/null | grep :3001 | awk '{print $6}' | cut -d',' -f2 | cut -d'=' -f2 | head -1)
    if [ ! -z "$PID" ] && [ "$PID" != "-" ]; then
      echo "发现占用 3001 端口的进程: $PID"
      kill -9 $PID 2>/dev/null || true
    fi
  fi
fi

echo "等待端口完全释放..."
sleep 3

# 再次验证端口是否已释放
if command -v lsof &> /dev/null; then
  if lsof -ti:3001 > /dev/null 2>&1; then
    echo "警告: 端口 3001 仍被占用，强制清理..."
    lsof -ti:3001 | xargs kill -9 2>/dev/null || true
    sleep 2
  fi
fi

echo ""
echo "=========================================="
echo "6. 重新启动服务"
echo "=========================================="
if command -v pm2 &> /dev/null; then
  echo "使用 PM2 启动服务..."
  pm2 start ecosystem.config.cjs
  pm2 save
  sleep 3
  pm2 status
  echo ""
  echo "查看 PM2 日志："
  pm2 logs book-excerpt-server --lines 10 --nostream
else
  echo "PM2 未安装，使用 node 直接启动..."
  mkdir -p logs
  nohup node server.js > logs/out.log 2> logs/error.log &
  sleep 3
  if pgrep -f "node.*server.js" > /dev/null; then
    echo -e "\033[0;32m✓ 进程已启动: $(pgrep -f 'node.*server.js')\033[0m"
  else
    echo -e "\033[0;31m✗ 进程启动失败\033[0m"
    echo "查看错误日志："
    tail -20 logs/error.log 2>/dev/null || echo "无法读取日志"
  fi
fi

echo ""
echo "=========================================="
echo "7. 测试服务"
echo "=========================================="
sleep 2
echo "测试本地连接..."
if curl -s http://localhost:3001/health > /dev/null; then
  echo -e "\033[0;32m✓ 本地健康检查成功\033[0m"
  curl -s http://localhost:3001/health
  echo ""
  echo "测试 API 端点..."
  curl -s http://localhost:3001/api/config | head -20
else
  echo -e "\033[0;31m✗ 本地健康检查失败\033[0m"
  echo "查看最新日志："
  tail -10 logs/error.log 2>/dev/null || echo "无法读取错误日志"
  tail -10 logs/out.log 2>/dev/null || echo "无法读取输出日志"
fi

echo ""
echo "=========================================="
echo "8. 检查防火墙"
echo "=========================================="
if command -v firewall-cmd &> /dev/null; then
  echo "firewall-cmd 状态："
  firewall-cmd --list-ports 2>/dev/null || echo "无法获取防火墙状态"
  echo ""
  echo "如果需要开放端口，运行："
  echo "  firewall-cmd --permanent --add-port=3001/tcp"
  echo "  firewall-cmd --reload"
elif command -v ufw &> /dev/null; then
  echo "ufw 状态："
  ufw status 2>/dev/null || echo "无法获取防火墙状态"
  echo ""
  echo "如果需要开放端口，运行："
  echo "  ufw allow 3001/tcp"
else
  echo "未检测到防火墙管理工具"
fi

echo ""
echo "=========================================="
echo "修复完成"
echo "=========================================="
ENDSSH

echo ""
echo -e "${GREEN}诊断和修复完成！${NC}"
echo -e "${YELLOW}请访问以下地址测试：${NC}"
echo -e "  http://${SERVER_HOST}:3001/health"
echo -e "  http://${SERVER_HOST}:3001/api/config"

