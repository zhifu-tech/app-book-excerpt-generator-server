# 项目结构

## 目录结构

```
book-excerpt-generator-server/
├── src/                          # 源代码目录
│   ├── config/                   # 配置管理
│   │   └── index.js             # 应用配置（环境变量、路径等）
│   ├── constants/                # 常量定义
│   │   └── defaultConfig.js     # 默认配置数据
│   ├── controllers/              # 控制器层
│   │   ├── configController.js   # 配置控制器
│   │   └── healthController.js  # 健康检查控制器
│   ├── services/                 # 服务层（业务逻辑）
│   │   └── configService.js     # 配置服务
│   ├── routes/                   # 路由定义
│   │   ├── index.js             # 路由入口
│   │   └── configRoutes.js      # 配置路由
│   ├── middleware/               # 中间件
│   │   ├── errorHandler.js      # 错误处理中间件
│   │   └── requestLogger.js     # 请求日志中间件
│   ├── utils/                    # 工具函数
│   │   ├── logger.js            # 日志工具
│   │   └── validator.js         # 验证工具
│   └── app.js                   # Express 应用配置
├── scripts/                      # 脚本目录
│   ├── deploy.sh                # 部署脚本
│   ├── restart.sh               # 重启脚本
│   ├── check-status.sh          # 状态检查脚本
│   └── ...                      # 其他脚本
├── data/                         # 数据目录
│   └── config.json              # 配置文件（自动生成）
├── logs/                         # 日志目录（自动生成）
├── server.js                     # 服务器入口文件
├── package.json                  # 项目配置
├── ecosystem.config.cjs          # PM2 配置
├── .env                          # 环境变量（不提交到 Git）
├── .eslintrc.json                # ESLint 配置
├── .prettierrc                   # Prettier 配置
└── README.md                      # 项目说明
```

## 架构设计

### 分层架构

1. **Controller 层** (`src/controllers/`)
   - 处理 HTTP 请求和响应
   - 调用 Service 层处理业务逻辑
   - 不包含业务逻辑

2. **Service 层** (`src/services/`)
   - 包含核心业务逻辑
   - 处理数据读写
   - 可被多个 Controller 复用

3. **Utils 层** (`src/utils/`)
   - 通用工具函数
   - 日志、验证等辅助功能

4. **Middleware 层** (`src/middleware/`)
   - Express 中间件
   - 错误处理、请求日志等

### 配置管理

- **环境变量**: 通过 `.env` 文件管理
- **应用配置**: `src/config/index.js` 统一管理
- **默认配置**: `src/constants/defaultConfig.js`

### 日志系统

- 支持多级别日志（error, warn, info, debug）
- 支持文件日志和控制台日志
- 自动创建日志目录
- JSON 格式日志便于分析

## 开发规范

### 代码风格

- 使用 ESLint 进行代码检查
- 使用 Prettier 进行代码格式化
- 遵循 ES6+ 语法

### 命名规范

- 文件名: 小写字母，使用连字符（kebab-case）
- 类名: 大驼峰（PascalCase）
- 函数/变量: 小驼峰（camelCase）
- 常量: 大写下划线（UPPER_SNAKE_CASE）

### 文件组织

- 每个模块一个文件
- 相关功能放在同一目录
- 使用 `index.js` 作为目录入口

## 扩展指南

### 添加新的 API 端点

1. 在 `src/routes/` 创建路由文件
2. 在 `src/controllers/` 创建控制器
3. 在 `src/routes/index.js` 注册路由

### 添加新的服务

1. 在 `src/services/` 创建服务文件
2. 在控制器中调用服务

### 添加新的中间件

1. 在 `src/middleware/` 创建中间件文件
2. 在 `src/app.js` 中注册中间件
