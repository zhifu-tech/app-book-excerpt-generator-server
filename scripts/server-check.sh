#!/bin/bash

# 服务器端检查脚本
# 在服务器上直接运行: bash server-check.sh

cd /opt/book-excerpt-generator-server || exit 1

echo "=========================================="
echo "服务状态检查"
echo "=========================================="

echo ""
echo "1. 检查 PM2 进程状态"
echo "----------------------------------------"
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
echo "2. 检查端口监听"
echo "----------------------------------------"
if netstat -tlnp 2>/dev/null | grep :3001 > /dev/null || ss -tlnp 2>/dev/null | grep :3001 > /dev/null; then
  echo "✓ 端口 3001 正在监听"
  netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001
else
  echo "✗ 端口 3001 未监听"
fi

echo ""
echo "3. 测试本地连接"
echo "----------------------------------------"
echo "测试健康检查端点..."
if curl -s http://localhost:3001/health > /dev/null; then
  echo "✓ 本地健康检查成功"
  echo "响应内容:"
  curl -s http://localhost:3001/health
  echo ""
  echo ""
  echo "测试 API 端点..."
  if curl -s http://localhost:3001/api/config > /dev/null; then
    echo "✓ API 端点响应正常"
    echo "响应内容（前 5 行）:"
    curl -s http://localhost:3001/api/config | head -5
  else
    echo "✗ API 端点无响应"
  fi
else
  echo "✗ 本地健康检查失败"
  echo "服务可能未启动或端口未监听"
fi

echo ""
echo "4. 查看最近错误日志"
echo "----------------------------------------"
if [ -f "logs/error.log" ]; then
  echo "最近 15 行错误日志:"
  tail -15 logs/error.log
else
  echo "错误日志文件不存在"
fi

echo ""
echo "5. 查看最近输出日志"
echo "----------------------------------------"
if [ -f "logs/out.log" ]; then
  echo "最近 15 行输出日志:"
  tail -15 logs/out.log
else
  echo "输出日志文件不存在"
fi

echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
echo ""
echo "如果服务正常，可以访问："
echo "  健康检查: http://8.138.183.116:3001/health"
echo "  API 端点: http://8.138.183.116:3001/api/config"
echo ""
echo "如果无法从外部访问，请检查："
echo "  1. 云服务器安全组是否开放端口 3001"
echo "  2. 服务是否正常运行（查看上方检查结果）"

