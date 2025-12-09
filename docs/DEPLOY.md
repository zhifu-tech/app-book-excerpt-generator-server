# 部署指南

## 服务器信息

- **服务器地址**: 8.138.183.116
- **默认端口**: 3001
- **部署目录**: `/opt/book-excerpt-generator-server`

## 快速部署

### 方法 1: 使用部署脚本（推荐）

```bash
cd source/apps/book-excerpt-generator-server/scripts
chmod +x deploy.sh
./deploy.sh
```

**注意**:

- 部署脚本位于 `scripts/` 目录
- 需要修改 `scripts/deploy.sh` 中的 `SERVER_USER` 为实际的服务器用户名
- 脚本会自动检测并使用 SSH 密钥（如果已配置）

### 方法 2: 手动部署

#### 1. 连接到服务器

```bash
ssh root@8.138.183.116
```

#### 2. 创建应用目录

```bash
mkdir -p /opt/book-excerpt-generator-server
cd /opt/book-excerpt-generator-server
```

#### 3. 上传文件

从本地机器执行：

```bash
cd source/apps/book-excerpt-generator-server

# 上传核心文件
scp server.js package.json package-lock.json ecosystem.config.cjs example.env \
  root@8.138.183.116:/opt/book-excerpt-generator-server/

# 上传源代码目录
scp -r src/ root@8.138.183.116:/opt/book-excerpt-generator-server/
```

或者使用 rsync（更高效）：

```bash
rsync -avz --exclude 'node_modules' --exclude '.git' \
  source/apps/book-excerpt-generator-server/ \
  root@8.138.183.116:/opt/book-excerpt-generator-server/
```

#### 4. 安装 Node.js（如果未安装）

**CentOS/RHEL 系统（阿里云 ECS 通常使用此系统）:**

```bash
ssh root@8.138.183.116

# 使用 NodeSource 安装 Node.js 18.x
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# 验证安装
node --version
npm --version
```

**Debian/Ubuntu 系统:**

```bash
ssh root@8.138.183.116

# 使用 NodeSource 安装 Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# 验证安装
node --version
npm --version
```

#### 5. 在服务器上安装依赖

```bash
cd /opt/book-excerpt-generator-server
npm install --production
```

#### 6. 配置环境变量

```bash
cd /opt/book-excerpt-generator-server

# 复制示例环境变量文件
cp example.env .env

# 编辑环境变量（可选）
# vi .env
```

`.env` 文件示例：

```env
PORT=3001
HOST=0.0.0.0
NODE_ENV=production
CORS_ORIGIN=*
LOG_LEVEL=info
LOG_FORMAT=json
ENABLE_FILE_LOGGING=true
```

#### 7. 创建必要目录

```bash
mkdir -p logs data
```

#### 8. 启动服务

**使用 PM2（推荐）:**

```bash
# 安装 PM2（如果未安装）
npm install -g pm2

# 启动服务
cd /opt/book-excerpt-generator-server
pm2 start ecosystem.config.cjs

# 设置开机自启
pm2 startup
pm2 save

# 查看状态
pm2 status
pm2 logs book-excerpt-server
```

**或使用 systemd:**

创建服务文件 `/etc/systemd/system/book-excerpt-server.service`:

```ini
[Unit]
Description=Book Excerpt Generator Config Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/book-excerpt-generator-server
ExecStart=/usr/bin/node /opt/book-excerpt-generator-server/server.js
Restart=always
RestartSec=10
StandardOutput=append:/opt/book-excerpt-generator-server/logs/out.log
StandardError=append:/opt/book-excerpt-generator-server/logs/error.log

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
systemctl daemon-reload
systemctl enable book-excerpt-server
systemctl start book-excerpt-server
systemctl status book-excerpt-server
```

## 配置防火墙

确保服务器防火墙允许 3001 端口：

```bash
# Ubuntu/Debian
ufw allow 3001/tcp

# CentOS/RHEL
firewall-cmd --permanent --add-port=3001/tcp
firewall-cmd --reload
```

**注意**: 如果使用云服务器（如阿里云 ECS），需要在云控制台的安全组中开放 3001 端口。

## 验证部署

### 健康检查

```bash
curl http://8.138.183.116:3001/health
```

预期响应：

```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 1234.56
}
```

### 获取配置

```bash
curl http://8.138.183.116:3001/api/config
```

预期响应：

```json
{
  "themes": [...],
  "fonts": [...],
  "fontColors": [...]
}
```

## 更新部署

### 使用 PM2

```bash
# 从本地执行部署脚本（推荐）
cd source/apps/book-excerpt-generator-server/scripts
./deploy.sh

# 或手动更新
ssh root@8.138.183.116
cd /opt/book-excerpt-generator-server

# 上传新文件（从本地执行）
# scp -r src/ server.js package.json root@8.138.183.116:/opt/book-excerpt-generator-server/

# 安装新依赖（如果有）
npm install --production

# 重启服务
pm2 restart book-excerpt-server
```

### 使用 systemd

```bash
ssh root@8.138.183.116
cd /opt/book-excerpt-generator-server

# 上传新文件（从本地执行）
# scp -r src/ server.js package.json root@8.138.183.116:/opt/book-excerpt-generator-server/

# 安装新依赖（如果有）
npm install --production

# 重启服务
systemctl restart book-excerpt-server
```

## 日志查看

### PM2

```bash
pm2 logs book-excerpt-server
```

### systemd

```bash
journalctl -u book-excerpt-server -f
```

或查看日志文件：

```bash
# 应用日志（由日志系统生成）
tail -f /opt/book-excerpt-generator-server/logs/error.log
tail -f /opt/book-excerpt-generator-server/logs/info.log
tail -f /opt/book-excerpt-generator-server/logs/debug.log

# PM2 日志
tail -f /opt/book-excerpt-generator-server/logs/out.log
```

**注意**: 新的日志系统会按级别分别记录到不同的日志文件中。

## 使用 Nginx 反向代理（可选）

如果需要使用域名和 HTTPS，可以配置 Nginx：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 环境变量

环境变量配置已在步骤 6 中说明。完整的配置选项：

```bash
cd /opt/book-excerpt-generator-server
cat > .env << EOF
# 服务器配置
PORT=3001
HOST=0.0.0.0
NODE_ENV=production

# CORS 配置
CORS_ORIGIN=*

# 日志配置
LOG_LEVEL=info
LOG_FORMAT=json
ENABLE_FILE_LOGGING=true
EOF
```

**重要**:

- 修改 `.env` 文件后需要重启服务才能生效
- 生产环境建议限制 `CORS_ORIGIN`，不要使用 `*`

## 故障排查

### 检查服务是否运行

```bash
# PM2
pm2 status

# systemd
systemctl status book-excerpt-server

# 端口占用
netstat -tlnp | grep 3001
# 或
ss -tlnp | grep 3001
```

### 检查日志

```bash
# PM2
pm2 logs book-excerpt-server --lines 50

# systemd
journalctl -u book-excerpt-server -n 50
```

### 重启服务

```bash
# PM2
pm2 restart book-excerpt-server

# systemd
systemctl restart book-excerpt-server
```

## 安全建议

1. **使用非 root 用户运行服务**

   ```bash
   # 创建专用用户
   useradd -r -s /bin/false book-excerpt
   chown -R book-excerpt:book-excerpt /opt/book-excerpt-generator-server
   # 在 systemd 服务文件中修改 User=book-excerpt
   ```

2. **配置防火墙规则**
   - 系统防火墙：开放 3001 端口
   - 云服务器安全组：配置入站规则

3. **使用 HTTPS（通过 Nginx）**
   - 配置 SSL 证书
   - 使用 Let's Encrypt 免费证书

4. **限制 CORS 来源**

   ```env
   # 生产环境不要使用 *
   CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com
   ```

5. **定期备份 `data/config.json`**

   ```bash
   # 创建备份脚本
   cp /opt/book-excerpt-generator-server/data/config.json \
      /opt/book-excerpt-generator-server/data/config.json.backup.$(date +%Y%m%d)
   ```

6. **监控服务状态**
   - 使用 PM2 监控
   - 配置健康检查
   - 设置告警通知

## 快速部署脚本

项目提供了多个便捷脚本（位于 `scripts/` 目录）：

- `deploy.sh` - 一键部署脚本
- `restart.sh` - 重启服务脚本
- `check-status.sh` - 检查服务状态脚本
- `fix-502.sh` - 修复 502 错误脚本
- `setup-ssh-key.sh` - 配置 SSH 免密登录

使用方法：

```bash
cd source/apps/book-excerpt-generator-server/scripts
chmod +x *.sh
./deploy.sh
```
