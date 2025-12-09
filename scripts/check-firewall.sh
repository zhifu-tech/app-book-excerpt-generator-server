#!/bin/bash

# 检查防火墙状态脚本
# 帮助诊断防火墙配置问题

echo "=========================================="
echo "防火墙状态检查"
echo "=========================================="

# 检查 FirewallD
echo ""
echo "1. 检查 FirewallD (firewall-cmd):"
if command -v firewall-cmd &> /dev/null; then
  if systemctl is-active --quiet firewalld; then
    echo "  ✓ FirewallD 正在运行"
    echo "  已开放的端口:"
    firewall-cmd --list-ports 2>/dev/null || echo "  无"
  else
    echo "  ⚠ FirewallD 已安装但未运行"
    echo "  提示: 如果使用云服务器，通常由安全组管理防火墙"
  fi
else
  echo "  - FirewallD 未安装"
fi

# 检查 UFW
echo ""
echo "2. 检查 UFW (ufw):"
if command -v ufw &> /dev/null; then
  UFW_STATUS=$(ufw status 2>/dev/null | head -1)
  if echo "$UFW_STATUS" | grep -q "active"; then
    echo "  ✓ UFW 正在运行"
    echo "  状态: $UFW_STATUS"
  else
    echo "  ⚠ UFW 已安装但未激活"
  fi
else
  echo "  - UFW 未安装"
fi

# 检查 iptables
echo ""
echo "3. 检查 iptables:"
if command -v iptables &> /dev/null; then
  RULES=$(iptables -L -n 2>/dev/null | wc -l)
  if [ "$RULES" -gt 8 ]; then
    echo "  ✓ iptables 有规则配置"
    echo "  规则数量: $RULES"
    echo "  查看端口 3001 相关规则:"
    iptables -L -n 2>/dev/null | grep 3001 || echo "  未找到端口 3001 的规则"
  else
    echo "  ⚠ iptables 规则很少或为空"
  fi
else
  echo "  - iptables 未安装"
fi

# 检查端口监听
echo ""
echo "4. 检查端口 3001 监听状态:"
if netstat -tlnp 2>/dev/null | grep :3001 > /dev/null || ss -tlnp 2>/dev/null | grep :3001 > /dev/null; then
  echo "  ✓ 端口 3001 正在监听"
  netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001
else
  echo "  ✗ 端口 3001 未监听"
fi

# 测试本地连接
echo ""
echo "5. 测试本地连接:"
if curl -s http://localhost:3001/health > /dev/null; then
  echo "  ✓ 本地连接成功"
  curl -s http://localhost:3001/health | head -3
else
  echo "  ✗ 本地连接失败"
fi

# 云服务器提示
echo ""
echo "=========================================="
echo "重要提示"
echo "=========================================="
echo "如果这是云服务器（如阿里云、腾讯云等）："
echo "1. 系统防火墙可能未启用（由安全组管理）"
echo "2. 需要在云控制台配置安全组规则："
echo "   - 入站规则：允许 TCP 端口 3001"
echo "   - 源地址：0.0.0.0/0（或特定 IP）"
echo ""
echo "如果系统防火墙未运行，通常不需要额外配置"
echo "但云服务器安全组必须开放端口 3001"
echo "=========================================="

