# DNS 配置指南

本文档说明如何在 DNS 解析服务上配置书摘卡片生成器的域名。

## 📋 域名配置概览

### 域名列表

| 服务     | 域名                          | 类型   | 用途             |
| -------- | ----------------------------- | ------ | ---------------- |
| 前端应用 | `book-excerpt.zhifu.tech`     | A 记录 | 静态前端文件服务 |
| 后端 API | `api.book-excerpt.zhifu.tech` | A 记录 | API 服务反向代理 |

### 服务器信息

- **服务器 IP**: `8.138.183.116`
- **服务器端口**:
  - HTTP: `80`
  - HTTPS: `443`
  - 后端服务: `3001`（内部，不对外开放）

## 🔧 DNS 配置步骤

### 方法一：阿里云 DNS（推荐）

如果您使用阿里云 DNS 服务：

#### 1. 登录阿里云控制台

1. 访问 [阿里云 DNS 控制台](https://dns.console.aliyun.com/)
2. 选择您的域名 `zhifu.tech`
3. 点击「解析设置」

#### 2. 添加前端域名 A 记录

**记录类型**: `A`  
**主机记录**: `book-excerpt`  
**记录值**: `8.138.183.116`  
**TTL**: `600`（10分钟，可根据需要调整）  
**解析线路**: `默认`（或根据需要选择线路）

**完整域名**: `book-excerpt.zhifu.tech` → `8.138.183.116`

#### 3. 添加后端 API 域名 A 记录

**记录类型**: `A`  
**主机记录**: `api.book-excerpt`（或 `api`，取决于 DNS 服务商）  
**记录值**: `8.138.183.116`  
**TTL**: `600`  
**解析线路**: `默认`

**完整域名**: `api.book-excerpt.zhifu.tech` → `8.138.183.116`

> **注意**: 某些 DNS 服务商可能不支持多级子域名（如 `api.book-excerpt`），如果遇到这种情况，可以：
>
> - 使用 `api-book-excerpt` 作为主机记录
> - 或者先创建 `book-excerpt` 子域名，再在其下创建 `api` 子域名

#### 4. 验证 DNS 解析

配置完成后，等待 DNS 生效（通常几分钟到几小时），然后验证：

```bash
# 检查前端域名解析
nslookup book-excerpt.zhifu.tech
# 或
dig book-excerpt.zhifu.tech

# 检查后端 API 域名解析
nslookup api.book-excerpt.zhifu.tech
# 或
dig api.book-excerpt.zhifu.tech
```

预期结果应该都指向 `8.138.183.116`。

### 方法二：Cloudflare DNS

如果您使用 Cloudflare DNS：

#### 1. 登录 Cloudflare 控制台

1. 访问 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 选择您的域名 `zhifu.tech`
3. 进入「DNS」设置

#### 2. 添加 A 记录

**Type**: `A`  
**Name**: `book-excerpt`  
**IPv4 address**: `8.138.183.116`  
**Proxy status**: `DNS only`（灰色云朵，不启用代理）或 `Proxied`（橙色云朵，启用 CDN）  
**TTL**: `Auto`

**Type**: `A`  
**Name**: `api.book-excerpt`  
**IPv4 address**: `8.138.183.116`  
**Proxy status**: `DNS only`（建议，因为 API 需要直接访问）  
**TTL**: `Auto`

> **注意**: 如果 Cloudflare 不支持 `api.book-excerpt` 这样的多级子域名，可以：
>
> - 使用 `api-book-excerpt` 作为 Name
> - 或者先添加 `book-excerpt` 记录，然后添加 `api` 作为 `book-excerpt` 的子域名

### 方法三：其他 DNS 服务商

对于其他 DNS 服务商（如 DNSPod、GoDaddy、Namecheap 等），配置方法类似：

1. 登录 DNS 管理控制台
2. 找到域名 `zhifu.tech` 的解析设置
3. 添加两条 A 记录：
   - `book-excerpt` → `8.138.183.116`
   - `api.book-excerpt` → `8.138.183.116`（或根据服务商要求配置）

## 🔍 DNS 解析验证

### 使用命令行工具验证

```bash
# 使用 nslookup
nslookup book-excerpt.zhifu.tech
nslookup api.book-excerpt.zhifu.tech

# 使用 dig
dig book-excerpt.zhifu.tech
dig api.book-excerpt.zhifu.tech

# 使用 ping（仅验证解析，不验证服务）
ping book-excerpt.zhifu.tech
ping api.book-excerpt.zhifu.tech
```

### 使用在线工具验证

- [DNS Checker](https://dnschecker.org/)
- [What's My DNS](https://www.whatsmydns.net/)
- [DNSPerf](https://www.dnsperf.com/)

### 验证 HTTP/HTTPS 访问

```bash
# 验证前端服务
curl -I http://book-excerpt.zhifu.tech
curl -I https://book-excerpt.zhifu.tech

# 验证后端 API 服务
curl -I http://api.book-excerpt.zhifu.tech
curl -I https://api.book-excerpt.zhifu.tech

# 验证健康检查端点
curl https://api.book-excerpt.zhifu.tech/health
```

## 📝 DNS 配置示例

### 阿里云 DNS 配置示例

```
记录类型 | 主机记录        | 记录值          | TTL  | 解析线路
--------|----------------|----------------|------|----------
A       | book-excerpt   | 8.138.183.116  | 600  | 默认
A       | api.book-excerpt| 8.138.183.116 | 600  | 默认
```

### Cloudflare DNS 配置示例

```
Type | Name            | Content        | Proxy | TTL
-----|----------------|---------------|-------|-----
A    | book-excerpt    | 8.138.183.116 | Off   | Auto
A    | api.book-excerpt| 8.138.183.116 | Off   | Auto
```

## ⚠️ 常见问题

### 1. 多级子域名不支持

**问题**: DNS 服务商不支持 `api.book-excerpt` 这样的多级子域名。

**解决方案**:

- 方案 A: 使用 `api-book-excerpt` 作为主机记录
  - 域名变为: `api-book-excerpt.zhifu.tech`
  - 需要修改 Nginx 配置中的 `server_name`
- 方案 B: 使用独立的子域名
  - 创建 `api` 作为 `book-excerpt` 的子域名
  - 需要 DNS 服务商支持子域名嵌套

### 2. DNS 解析不生效

**可能原因**:

- DNS 缓存未更新（等待 TTL 时间）
- DNS 记录配置错误
- 防火墙或安全组未开放端口

**解决方法**:

```bash
# 清除本地 DNS 缓存
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### 3. SSL 证书域名不匹配

**问题**: SSL 证书中的域名与 DNS 配置的域名不一致。

**解决方案**:

- 确保证书包含所有使用的域名
- 如果使用通配符证书 `*.zhifu.tech`，可以覆盖所有子域名
- 如果需要多个域名，使用 SAN（Subject Alternative Name）证书

### 4. 端口访问问题

**问题**: DNS 解析正常，但无法访问服务。

**检查清单**:

- ✅ 服务器防火墙是否开放 80/443 端口
- ✅ 云服务商安全组是否开放 80/443 端口
- ✅ Nginx 是否正常运行
- ✅ Nginx 配置是否正确
- ✅ SSL 证书是否有效

## 🔐 SSL 证书配置

### 证书域名要求

SSL 证书需要包含以下域名：

- `book-excerpt.zhifu.tech`
- `api.book-excerpt.zhifu.tech`

### 证书类型建议

1. **通配符证书**: `*.zhifu.tech`（推荐，覆盖所有子域名）
2. **多域名证书（SAN）**: 包含多个具体域名
3. **单域名证书**: 每个域名单独申请（不推荐，管理复杂）

### 证书申请

如果使用 Let's Encrypt 免费证书：

```bash
# 安装 certbot
sudo apt-get install certbot python3-certbot-nginx

# 申请证书（需要 DNS 解析已生效）
sudo certbot --nginx -d book-excerpt.zhifu.tech -d api.book-excerpt.zhifu.tech
```

## 📊 DNS 配置检查清单

- [ ] 前端域名 A 记录已添加
- [ ] 后端 API 域名 A 记录已添加
- [ ] DNS 解析已生效（使用 nslookup 验证）
- [ ] HTTP 访问正常
- [ ] HTTPS 访问正常（SSL 证书已配置）
- [ ] 防火墙和安全组已开放 80/443 端口
- [ ] Nginx 配置中的 `server_name` 与 DNS 域名一致

## 🔗 相关文档

- [前端部署文档](../book-excerpt-generator/docs/DEPLOY.md)
- [后端部署文档](./DEPLOY.md)
- [Nginx 配置说明](../book-excerpt-generator/scripts/nginx.conf)
- [后端 Nginx 配置说明](./scripts/nginx.conf)

## 📞 技术支持

如果遇到 DNS 配置问题，请检查：

1. DNS 服务商文档
2. 服务器日志: `/var/log/nginx/error.log`
3. DNS 解析工具验证结果
