# LinuxPanel - 轻量级Linux服务器管理面板

<div align="center">
    <img src="./ui/src/assets/logo.png" alt="LinuxPanel Logo" width="200">
</div>

![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)
![Go Version](https://img.shields.io/badge/go-%3E%3D1.21-blue.svg)
![Node Version](https://img.shields.io/badge/node-%3E%3D16-green.svg)

LinuxPanel是一个轻量级的Linux服务器管理面板，提供直观的Web界面来管理您的Linux服务器。采用模块化设计，核心组件占用资源极少，可通过应用商店按需安装网站部署、文件管理、数据库管理等功能。项目使用Go语言作为后端，Vue.js作为前端，设计轻量、高效且易于使用。

## 功能特性

### 核心系统（默认安装）
- 实时监控CPU、内存、磁盘使用率
- 显示系统基本信息（操作系统、内核版本等）
- 运行时间和系统负载监控
- 轻量级SQLite数据存储
- 模块化应用商店

### 可选模块（应用商店安装）
#### 网站管理
- 轻松创建和管理网站
- Nginx服务器配置
- 多种PHP版本支持
- SSL证书管理

#### 文件管理
- 直观的文件浏览器界面
- 文件上传下载
- 文件编辑器（支持代码高亮）
- 文件权限管理

#### 数据库管理
- MySQL/MariaDB数据库创建和管理
- 数据库用户管理
- 数据库备份和恢复

#### 应用部署
- 一键安装常用应用（WordPress、Discuz、NextCloud等）
- 应用版本管理
- 自定义应用源

#### 安全中心
- 防火墙规则管理
- SSH安全设置
- 系统更新管理

## 系统要求

- Linux操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 10+)
- 最小配置：1核CPU，512MB内存，5GB硬盘空间
- 推荐配置：2核CPU，1GB内存，10GB+硬盘空间

## 快速安装

### 方法一：一键安装脚本（推荐）

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/erniang/LinuxPanel/main/install.sh

# 给脚本添加执行权限
chmod +x install.sh

# 以root用户运行安装脚本
sudo ./install.sh
```

### 方法二：手动安装

#### 1. 安装依赖

```bash
# Debian/Ubuntu
apt update
apt install -y curl wget git build-essential sqlite3

# CentOS/RHEL
yum update
yum install -y curl wget git gcc gcc-c++ make sqlite
```

#### 2. 安装Go (1.21+)

```bash
wget https://golang.org/dl/go1.21.0.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
source /etc/profile.d/go.sh
```

#### 3. 安装Node.js (16+)

```bash
# 使用NVM安装
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source ~/.bashrc
nvm install 16
```

#### 4. 获取代码

```bash
git clone https://github.com/erniang/LinuxPanel.git
cd LinuxPanel
```

#### 5. 编译后端

```bash
go mod tidy
go build -o linuxpanel
```

#### 6. 创建必要目录和配置

```bash
# 创建工作目录
mkdir -p /opt/linuxpanel
mkdir -p /etc/linuxpanel
mkdir -p /var/log/linuxpanel
mkdir -p /var/lib/linuxpanel/data

# 复制文件
cp linuxpanel /opt/linuxpanel/
cp -r ui/dist /opt/linuxpanel/ui/
cp -r configs /etc/linuxpanel/
```

完整的手动安装步骤请参考[详细安装文档](docs/installation.md)。

## 使用指南

安装完成后，通过浏览器访问服务器IP地址，默认端口为8080：

```
http://YOUR_SERVER_IP:8080
```

初始登录凭证：
- 用户名：admin
- 密码：admin123

**重要提示：** 首次登录后请立即修改默认密码！

## 配置文件

主配置文件位于 `/etc/linuxpanel/config.yaml`，包含以下主要配置项：

```yaml
server:
  port: 8080
  host: "0.0.0.0"
  
database:
  type: "sqlite"
  path: "/var/lib/linuxpanel/data/panel.db"
  
paths:
  data: "/var/lib/linuxpanel/data"
  logs: "/var/log/linuxpanel"
  websites: "/var/www"
  
security:
  jwt_secret: "your_generated_secret"
  session_timeout: 86400
```

## 服务管理

LinuxPanel作为系统服务运行，可以使用以下命令管理：

```bash
# 启动服务
systemctl start linuxpanel

# 停止服务
systemctl stop linuxpanel

# 重启服务
systemctl restart linuxpanel

# 查看服务状态
systemctl status linuxpanel

# 设置开机自启
systemctl enable linuxpanel
```

## 常见问题

### 1. 面板安装后无法访问
- 检查服务是否正常运行：`systemctl status linuxpanel`
- 确认8080端口是否开放：`netstat -tunlp | grep 8080`
- 检查防火墙设置：`ufw status` 或 `firewall-cmd --list-all`

### 2. 如何更改监听端口？
编辑配置文件 `/etc/linuxpanel/config.yaml`，修改 `server.port` 值，然后重启服务。

### 3. 默认密码无法登录
如果忘记密码，可以通过以下命令重置管理员密码：
```bash
sqlite3 /var/lib/linuxpanel/data/panel.db "UPDATE users SET password='$2a$10$uIBEsK0BbGQ6Lr.2oHjy0uKBFbXzS9YBjaoBd1tYYb8JkjWVZzWQ6' WHERE username='admin';"
```
重置后密码为：admin123

## 开发指南

如果您想参与开发，请查看[开发文档](docs/development.md)。

### 后端结构

```
pkg/
├── api/          # API路由和处理器
├── auth/         # 身份验证
├── common/       # 公共组件和类型
├── config/       # 配置处理
├── database/     # 数据库操作
├── logger/       # 日志系统
├── models/       # 数据模型
├── system/       # 系统信息和操作
├── types/        # 类型定义
└── web/          # 网站部署管理
```

### 前端结构

```
ui/
├── public/       # 静态资源
└── src/
    ├── api/      # API请求
    ├── assets/   # 资源文件
    ├── components/ # 通用组件
    ├── layout/   # 布局组件
    ├── router/   # 路由配置
    ├── store/    # 状态管理
    ├── styles/   # 样式文件
    ├── utils/    # 工具函数
    └── views/    # 页面视图
```

## 贡献

欢迎提交问题报告、功能请求和Pull Request。在提交Pull Request之前，请确保您的代码符合项目的编码规范。

## 许可证

本项目采用[GPL-3.0 License](LICENSE)。

## 常见问题

1. **面板无法访问怎么办？**
   - 检查防火墙设置，确保80和8080端口已开放
   - 检查服务状态：`systemctl status linuxpanel`
   - 查看日志：`tail -f /var/log/linuxpanel/error.log`

2. **如何备份面板数据？**
   - 备份主要数据目录：`/var/lib/linuxpanel/data`
   - 备份配置文件：`/etc/linuxpanel/config.yaml`
   - 备份MySQL数据库：`mysqldump -u root -p linuxpanel > linuxpanel_backup.sql`

3. **如何修改面板访问端口？**
   - 修改Nginx配置文件：`/etc/nginx/conf.d/linuxpanel.conf`
   - 重启Nginx：`systemctl restart nginx`

更多问题请参阅[常见问题文档](docs/faq.md)。

## 联系方式

- GitHub Issues: [https://github.com/erniang/LinuxPanel/issues](https://github.com/erniang/LinuxPanel/issues)
- 邮箱：admin@example.com

## 致谢

LinuxPanel的开发受到了以下开源项目的启发：

- [宝塔面板](https://www.bt.cn/)
- [Cockpit](https://cockpit-project.org/)
- [Webmin](http://www.webmin.com/)

感谢所有贡献者和用户的支持！ 