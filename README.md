# paperddl

本项目基于 Vue 3（Vite）和 Express，旨在浏览与维护会议截稿（deadline）数据。

## 前置依赖（请协作者先安装）

### 必需

- **Node.js**：建议 **18 LTS 或 20 LTS**（不建议低于 18）
- **npm**：随 Node.js 自带即可
- **MySQL**：建议 **8.0+**（本项目仅用 MySQL 存用户账号）

已在作者本机（Windows）验证通过的版本：

- Node.js：`v18.20.8`
- npm：`10.8.2`
- MySQL client：`8.0.33`（`mysql --version`）
- Git：`2.39.1.windows.1`
- Conda：`23.5.0`（仅当你要用 `run-dev.bat`）

### 可选

- **Docker Desktop**：如果不想在本机安装 MySQL，可用 Docker 启动 MySQL 容器（作者本机当前未安装/未配置 Docker，未做版本验证）
- **Conda（Anaconda/Miniconda）**：**不是项目必须**。仓库里的 `run-dev.bat` 会尝试执行 `conda activate paperddl`，如果你不使用该脚本，可以忽略 conda。

### 快速检查命令（Windows PowerShell）

```powershell
node -v
npm -v
mysql --version
# 可选（仅当你要用 run-dev.bat）
conda --version
```

## 项目结构

- `web/`：Vue 3 前端代码（Vite）
- `server/`：Express API 服务端
- `conference/`：以 YAML 存放的会议数据
- `server/migrations/`：后端的 SQL 迁移脚本

## 当前数据模型

目前仅使用 MySQL 存储用户账号（鉴权相关）。会议数据仍以 YAML 文件保存在 `conference/**/*.yml`，公共 API 从 YAML 读取，后台管理表单会把新增数据写入 YAML。

## 安装依赖

在仓库根执行：

```powershell
npm install
npm --prefix server install
npm --prefix web install
```

说明：在 Windows PowerShell 下如果遇到 `npm.ps1` 被策略阻止，请改用 `npm.cmd`。

## 本地 MySQL 配置示例

在本地开发环境下，创建数据库和用户（示例）：

```sql
CREATE DATABASE paperddl CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'paperddl'@'localhost' IDENTIFIED BY 'paperddl_password';
GRANT ALL PRIVILEGES ON paperddl.* TO 'paperddl'@'localhost';
FLUSH PRIVILEGES;
```

初始化 `users` 表（在 PowerShell 中推荐使用管道方式导入 SQL）：

```powershell
Get-Content server/migrations/001_auth.sql | mysql -u paperddl -p paperddl
Get-Content server/migrations/002_favorites.sql | mysql -u paperddl -p paperddl
```

或者在你的 MySQL 客户端中直接执行 `server/migrations/001_auth.sql` 的内容。

## 服务端环境变量（`server/.env`）

如果没有 `server/.env`，请复制 `server/.env.example` 并按需填写：

```env
PORT=5000
DATA_ROOT=../conference

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DATABASE=paperddl
MYSQL_USER=paperddl
MYSQL_PASSWORD=paperddl_password
MYSQL_CONNECTION_LIMIT=10

JWT_SECRET=replace_with_a_long_random_secret
JWT_EXPIRES_IN=7d
COOKIE_NAME=paperddl_token
COOKIE_SECURE=false
CORS_ORIGIN=http://localhost:5173
BCRYPT_ROUNDS=12
```

注意：务必使用强随机串作为 `JWT_SECRET`。

## 创建第一个管理员

MySQL 创建并应用迁移后，运行：

```powershell
npm --prefix server run auth:create-admin -- admin your_password
```

该命令会向 `users` 表中插入一个管理员账号（用户名与密码按命令提供），密码会以 bcrypt 哈希存储。

## 本地启动（开发）

启动后端：

```powershell
npm run server:dev
```

启动前端：

```powershell
npm run web:dev
```

默认访问地址：

- 后端: http://localhost:5000
- 前端: http://localhost:5173
- 登录页: http://localhost:5173/#/login
- 后台管理: http://localhost:5173/#/admin

## 登录相关 API

- POST /api/auth/login：校验用户名与密码，成功则把 JWT 写入 HttpOnly Cookie
- GET /api/auth/me：当 cookie 有效时返回当前用户信息
- POST /api/auth/logout：清除认证 cookie
- 未登录访问 `/#/admin` 会重定向到 `/#/login?redirect=/admin`，登录后会重定向回请求页面或默认到 `/#/admin`

## 权限说明

以下 API 对所有请求者开放（只读）：

- GET /api/health
- GET /api/categories
- GET /api/conferences

以下接口需要管理员权限：

- POST /api/conferences

