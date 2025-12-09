#!/bin/bash

# SSH 免密登录配置脚本
# 使用方法: ./setup-ssh-key.sh

set -e

# 配置变量
SERVER_HOST="8.138.183.116"
SERVER_USER="root"
SERVER_PORT="22"
SSH_KEY_NAME="id_rsa_book_excerpt"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SSH 免密登录配置${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查是否已有 SSH 密钥
SSH_DIR="$HOME/.ssh"
SSH_KEY_PATH="$SSH_DIR/$SSH_KEY_NAME"

echo -e "${YELLOW}步骤 1: 检查 SSH 密钥${NC}"
if [ -f "$SSH_KEY_PATH" ]; then
  echo -e "${GREEN}✓ 发现现有密钥: $SSH_KEY_PATH${NC}"
  read -p "是否使用现有密钥？(y/n) [y]: " use_existing
  use_existing=${use_existing:-y}
  if [ "$use_existing" != "y" ] && [ "$use_existing" != "Y" ]; then
    echo -e "${YELLOW}将生成新密钥...${NC}"
    rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
  fi
fi

# 生成 SSH 密钥（如果不存在）
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo -e "${YELLOW}步骤 2: 生成 SSH 密钥对${NC}"
  echo "密钥将保存在: $SSH_KEY_PATH"
  echo ""
  read -p "请输入密钥密码（可选，直接回车跳过）: " -s key_passphrase
  echo ""
  
  if [ -z "$key_passphrase" ]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "book-excerpt-server-$(date +%Y%m%d)"
  else
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "$key_passphrase" -C "book-excerpt-server-$(date +%Y%m%d)"
  fi
  
  echo -e "${GREEN}✓ SSH 密钥生成成功${NC}"
else
  echo -e "${GREEN}✓ 使用现有密钥${NC}"
fi

# 设置正确的权限
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_KEY_PATH"
chmod 644 "$SSH_KEY_PATH.pub" 2>/dev/null || true

# 配置 SSH config（可选）
echo ""
echo -e "${YELLOW}步骤 3: 配置 SSH config${NC}"
SSH_CONFIG="$SSH_DIR/config"
if [ ! -f "$SSH_CONFIG" ]; then
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

# 检查是否已存在配置
if grep -q "Host.*book-excerpt-server" "$SSH_CONFIG" 2>/dev/null; then
  echo -e "${YELLOW}SSH config 中已存在 book-excerpt-server 配置${NC}"
  read -p "是否更新配置？(y/n) [y]: " update_config
  update_config=${update_config:-y}
  if [ "$update_config" = "y" ] || [ "$update_config" = "Y" ]; then
    # 删除旧配置
    sed -i.bak '/^Host book-excerpt-server/,/^$/d' "$SSH_CONFIG"
  else
    update_config="n"
  fi
else
  update_config="y"
fi

if [ "$update_config" = "y" ] || [ "$update_config" = "Y" ]; then
  cat >> "$SSH_CONFIG" << EOF

Host book-excerpt-server
    HostName $SERVER_HOST
    User $SERVER_USER
    Port $SERVER_PORT
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
  echo -e "${GREEN}✓ SSH config 已更新${NC}"
  echo "  现在可以使用: ssh book-excerpt-server"
fi

# 复制公钥到服务器
echo ""
echo -e "${YELLOW}步骤 4: 复制公钥到服务器${NC}"
echo "需要输入一次服务器密码来完成配置..."
echo ""

# 尝试使用 ssh-copy-id
if command -v ssh-copy-id &> /dev/null; then
  echo "使用 ssh-copy-id 复制公钥..."
  ssh-copy-id -i "$SSH_KEY_PATH.pub" -p $SERVER_PORT $SERVER_USER@$SERVER_HOST || {
    echo -e "${RED}ssh-copy-id 失败，尝试手动复制...${NC}"
    
    # 手动复制
    echo "手动复制公钥..."
    cat "$SSH_KEY_PATH.pub" | ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST \
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  }
else
  echo "ssh-copy-id 未安装，手动复制公钥..."
  cat "$SSH_KEY_PATH.pub" | ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
fi

echo -e "${GREEN}✓ 公钥已复制到服务器${NC}"

# 测试免密登录
echo ""
echo -e "${YELLOW}步骤 5: 测试免密登录${NC}"
echo "测试连接..."

if ssh -i "$SSH_KEY_PATH" -p $SERVER_PORT -o ConnectTimeout=5 -o BatchMode=yes $SERVER_USER@$SERVER_HOST "echo 'SSH 免密登录成功！'" 2>/dev/null; then
  echo -e "${GREEN}✓ SSH 免密登录配置成功！${NC}"
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${GREEN}配置完成${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo "现在可以使用以下方式连接服务器："
  echo "  1. 使用别名: ssh book-excerpt-server"
  echo "  2. 直接连接: ssh -i $SSH_KEY_PATH -p $SERVER_PORT $SERVER_USER@$SERVER_HOST"
  echo ""
  echo "部署脚本将自动使用密钥进行认证。"
else
  echo -e "${RED}✗ 免密登录测试失败${NC}"
  echo "请检查："
  echo "  1. 服务器是否允许密钥认证"
  echo "  2. 服务器 ~/.ssh/authorized_keys 文件权限是否正确（应为 600）"
  echo "  3. 服务器 SSH 配置是否允许密钥认证"
  exit 1
fi

