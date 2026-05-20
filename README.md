# paperddl

本项目基于 Vue 3（Vite）和 Express，旨在浏览与维护会议截稿（deadline）数据。

当前项目已在原有会议列表、筛选、搜索和后台管理基础上，补充了登录鉴权、分页展示、返回顶部、收藏会议等功能。

## 前置依赖（请协作者先安装）

### 必需

* **Node.js**：建议 **18 LTS 或 20 LTS**（不建议低于 18）
* **npm**：随 Node.js 自带即可
* **MySQL**：建议 **8.0+**

已在作者本机（Windows）验证通过的版本：

* Node.js：`v18.20.8`
* npm：`10.8.2`
* MySQL client：`8.0.33`（`mysql --version`）
* Git：`2.39.1.windows.1`
* Conda：`23.5.0`（仅当你要用 `run-dev.bat`）

### 可选

* **Docker Desktop**：如果不想在本机安装 MySQL，可用 Docker 启动 MySQL 容器
* **Conda（Anaconda/Miniconda）**：不是项目必须。仓库里的 `run-dev.bat` 会尝试执行 `conda activate paperddl`，如果你不使用该脚本，可以忽略 conda

### 快速检查命令（Windows PowerShell）

```powershell
node -v
npm -v
mysql --version

# 可选，仅当你要用 run-dev.bat
conda --version
```

## 项目结构

* `web/`：Vue 3 前端代码（Vite）
* `server/`：Express API 服务端
* `conference/`：以 YAML 存放的会议数据
* `server/migrations/`：后端的 SQL 迁移脚本

## 当前功能

### 会议浏览

* 展示会议 / 期刊截稿信息
* 支持按方向、年份、CCF、CORE、THCPL 等条件筛选
* 支持关键词搜索
* 支持分页展示
* 切换分页后自动滚动到搜索区域附近
* 支持右下角返回顶部按钮

### 登录与权限

* 支持用户注册、登录、退出
* 使用 JWT + HttpOnly Cookie 保存登录状态
* 普通用户可以浏览和收藏会议
* 管理员可以进入后台管理页面
* 未登录访问后台会跳转到登录页

### 后台管理

* 管理员可以通过后台新增会议
* 新增会议仍写入 YAML 文件
* 会议主体数据不迁移到 MySQL

### 收藏会议

* 登录用户可以收藏 / 取消收藏会议
* 收藏状态保存到 MySQL
* 刷新页面后收藏状态仍然保留
* 用户菜单中的“收藏会议”可以切换为只看收藏
* 未登录用户点击收藏会提示先登录

## 当前数据模型

MySQL 当前用于存储：

* 用户账号数据：`users`
* 用户收藏关系：`favorites`

会议数据仍以 YAML 文件保存在：

```text
conference/**/*.yml
```

公共会议 API 从 YAML 读取，后台管理表单会把新增数据写入 YAML。

## 安装依赖

在仓库根目录执行：

```powershell
npm install
npm --prefix server install
npm --prefix web install
```

说明：在 Windows PowerShell 下如果遇到 `npm.ps1` 被策略阻止，请改用 `npm.cmd`。

## 本地 MySQL 配置示例

在本地开发环境下，创建数据库和用户：

```sql
CREATE DATABASE paperddl CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'paperddl'@'localhost' IDENTIFIED BY 'paperddl_password';

GRANT ALL PRIVILEGES ON paperddl.* TO 'paperddl'@'localhost';

FLUSH PRIVILEGES;
```

初始化数据表：

```powershell
Get-Content server/migrations/001_auth.sql | mysql -u paperddl -p paperddl
Get-Content server/migrations/002_favorites.sql | mysql -u paperddl -p paperddl
```

或者在 MySQL 客户端中直接执行：

* `server/migrations/001_auth.sql`
* `server/migrations/002_favorites.sql`

其中：

* `001_auth.sql`：创建用户表
* `002_favorites.sql`：创建收藏表

## 服务端环境变量（`server/.env`）

如果没有 `server/.env`，可以复制 `server/.env.example` 并按需填写。

如果仓库中没有 `server/.env.example`，请手动新建 `server/.env`。

示例：

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

注意：

* `JWT_SECRET` 请替换为较长的随机字符串
* 本地开发环境下 `COOKIE_SECURE=false`
* 如果前端端口不是 `5173`，需要同步修改 `CORS_ORIGIN`

## 创建第一个管理员

MySQL 创建并应用迁移后，运行:

```powershell
npm --prefix server run auth:create-admin -- admin your_password
```

示例：

```powershell
npm --prefix server run auth:create-admin -- admin 123456
```

该命令会向 `users` 表中插入一个管理员账号，密码会以 bcrypt 哈希存储。

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

* 后端：[http://localhost:5000](http://localhost:5000)
* 前端：[http://localhost:5173](http://localhost:5173)
* 登录页：[http://localhost:5173/#/login](http://localhost:5173/#/login)
* 后台管理：[http://localhost:5173/#/admin](http://localhost:5173/#/admin)

如果使用 `run-dev.bat`，需要注意该脚本可能会尝试激活 conda 环境：

```bat
conda activate paperddl
```

如果本机没有该环境，建议直接使用上面的两个命令分别启动前后端。

## 登录相关 API

* `POST /api/auth/register`：注册普通用户
* `POST /api/auth/login`：校验用户名与密码，成功后把 JWT 写入 HttpOnly Cookie
* `GET /api/auth/me`：当 Cookie 有效时返回当前用户信息
* `POST /api/auth/logout`：清除认证 Cookie

未登录访问 `/#/admin` 会重定向到 `/#/login?redirect=/admin`，登录后会重定向回请求页面或默认到 `/#/admin`。

## 会议相关 API

以下 API 对所有请求者开放：

* `GET /api/health`
* `GET /api/categories`
* `GET /api/conferences`

以下接口需要管理员权限：

* `POST /api/conferences`

## 收藏相关 API

以下接口需要登录，但不需要管理员权限：

* `GET /api/favorites`：获取当前用户收藏的会议 ID
* `POST /api/favorites`：收藏会议
* `DELETE /api/favorites/:conferenceId`：取消收藏会议

示例请求体：

```json
{
  "conferenceId": "acl"
}
```

## 权限说明

只读接口：

* 所有人可访问
* 不需要登录

收藏接口：

* 需要普通登录用户
* 不需要管理员权限
* 只能操作当前登录用户自己的收藏

管理员接口：

* 需要登录
* 需要管理员角色