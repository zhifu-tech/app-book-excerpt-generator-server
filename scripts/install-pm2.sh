#!/bin/bash

# 在服务器上安装 PM2
# 使用方法: ./install-pm2.sh

set -e

# 配置变量
SERVER_HOST="8.138.183.116"
SERVER_USER="root"
SERVER_PORT="22"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}在服务器上安装 PM2...${NC}"

ssh -t -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST} << 'ENDSSH'
# 检查 Node.js
if ! command -v node &> /dev/null; then
  echo "错误: Node.js 未安装，请先安装 Node.js"
  exit 1
fi

echo "Node.js 版本: $(node --version)"
echo "npm 版本: $(npm --version)"

# 检查 PM2 是否已安装
if command -v pm2 &> /dev/null; then
  echo "PM2 已安装: $(pm2 --version)"
  echo "是否重新安装? (y/N)"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "跳过安装"
    exit 0
  fi
fi

# 安装 PM2
echo "正在安装 PM2..."
npm install -g pm2

# 验证安装
if command -v pm2 &> /dev/null; then
  echo -e "\033[0;32m✓ PM2 安装成功\033[0m"
  pm2 --version
  
  # 设置 PM2 开机自启
  echo ""
  echo "设置 PM2 开机自启..."
  pm2 startup
  echo "注意: 请复制上面的命令并在服务器上执行"
else
  echo -e "\033[0;31m✗ PM2 安装失败\033[0m"
  exit 1
fi
ENDSSH

echo -e "${GREEN}PM2 安装完成！${NC}"


