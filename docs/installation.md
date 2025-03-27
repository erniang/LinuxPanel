# LinuxPanel 详细安装指南

本文档提供了LinuxPanel的详细安装步骤，包括环境准备、安装过程和故障排除。

## 目录

- [系统要求](#系统要求)
- [一键安装](#一键安装)
- [手动安装](#手动安装)
  - [准备环境](#准备环境)
  - [安装依赖](#安装依赖)
  - [获取源代码](#获取源代码)
  - [编译安装](#编译安装)
  - [配置服务](#配置服务)
- [从源码安装开发环境](#从源码安装开发环境)
- [升级指南](#升级指南)
- [常见问题排除](#常见问题排除)

## 系统要求

LinuxPanel支持大多数主流Linux发行版，推荐使用：

- Ubuntu 18.04/20.04/22.04 LTS
- Debian 10/11
- CentOS 7/8
- Rocky Linux 8/9
- AlmaLinux 8/9

硬件要求：
- CPU: 至少1核
- 内存: 至少1GB（推荐2GB以上）
- 硬盘: 至少10GB可用空间
- 网络: 具有公网IP或可通过内网访问的服务器

软件要求：
- Nginx (用于反向代理)
- MySQL/MariaDB (用于数据存储)
- Go 1.18+ (用于编译后端)
- Node.js 16+ 和 npm (用于编译前端)

## 一键安装

一键安装是最简单的方式，适合大多数用户。脚本会自动安装所有依赖并配置系统。

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/erniang/LinuxPanel/main/install.sh

# 给脚本添加执行权限
chmod +x install.sh

# 以root用户运行脚本
sudo ./install.sh
```

安装完成后，可以通过服务器IP直接访问面板：`http://YOUR_SERVER_IP`

> 注意：一键安装脚本需要使用root权限执行，脚本会自动安装以下组件：Go、Node.js、MySQL、Nginx

## 手动安装

如果您需要更细粒度的控制或一键安装脚本不适合您的环境，可以按照以下步骤手动安装。

### 准备环境

首先，确保您的系统已更新：

```bash
# Debian/Ubuntu
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

### 安装依赖

#### 基础工具

```bash
# Debian/Ubuntu
sudo apt install -y curl wget git build-essential

# CentOS/RHEL
sudo yum install -y curl wget git gcc gcc-c++ make
```

#### 安装Go

```bash
# 下载Go
wget https://golang.org/dl/go1.19.linux-amd64.tar.gz

# 解压到/usr/local
sudo tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz

# 设置环境变量
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
source /etc/profile.d/go.sh

# 验证安装
go version
```

#### 安装Node.js

```bash
# 使用NVM安装Node.js (推荐)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # 加载nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # 加载bash补全

# 安装Node.js 16
nvm install 16

# 验证安装
node -v
npm -v

# 或者直接从官方源安装
# Debian/Ubuntu:
# curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
# sudo apt install -y nodejs

# CentOS/RHEL:
# curl -fsSL https://rpm.nodesource.com/setup_16.x | sudo bash -
# sudo yum install -y nodejs
```

#### 安装MySQL

```bash
# Debian/Ubuntu
sudo apt install -y mysql-server

# 启动并启用服务
sudo systemctl start mysql
sudo systemctl enable mysql

# CentOS/RHEL
sudo yum install -y mysql-server

# 启动并启用服务
sudo systemctl start mysqld
sudo systemctl enable mysqld
```

#### 安装Nginx

```bash
# Debian/Ubuntu
sudo apt install -y nginx

# 启动并启用服务
sudo systemctl start nginx
sudo systemctl enable nginx

# CentOS/RHEL
sudo yum install -y nginx

# 启动并启用服务
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 获取源代码

```bash
# 克隆仓库
git clone https://github.com/erniang/LinuxPanel.git
cd LinuxPanel

# 如果您无法访问GitHub，可以使用以下命令下载源码包
# wget https://github.com/erniang/LinuxPanel/archive/refs/heads/main.tar.gz
# tar -xzf main.tar.gz
# cd LinuxPanel-main
```

### 编译安装

#### 编译后端

```bash
# 设置GOPROXY（国内用户推荐）
export GOPROXY=https://goproxy.cn,direct

# 下载依赖
go mod tidy

# 编译
go build -o linuxpanel
```

#### 编译前端

```bash
# 进入前端目录
cd ui

# 安装依赖
npm install

# 创建生产环境配置
cat > .env.production <<EOF
VITE_APP_BASE_API=http://localhost:8080/api
EOF

# 构建前端
npm run build

# 返回项目根目录
cd ..
```

### 配置服务

#### 创建目录结构

```bash
# 创建必要的目录
sudo mkdir -p /opt/linuxpanel
sudo mkdir -p /etc/linuxpanel
sudo mkdir -p /var/log/linuxpanel
sudo mkdir -p /var/lib/linuxpanel/data
sudo mkdir -p /var/lib/linuxpanel/configs
```

#### 复制文件

```bash
# 复制后端可执行文件
sudo cp linuxpanel /opt/linuxpanel/

# 复制前端文件
sudo mkdir -p /opt/linuxpanel/ui
sudo cp -r ui/dist /opt/linuxpanel/ui/
```

#### 创建配置文件

```bash
# 创建主配置文件
sudo bash -c 'cat > /etc/linuxpanel/config.yaml' <<EOF
server:
  port: 8080
  host: "0.0.0.0"
  
database:
  type: "mysql"
  host: "localhost"
  port: 3306
  user: "linuxpanel"
  password: "linuxpanel"
  name: "linuxpanel"
  
paths:
  data: "/var/lib/linuxpanel/data"
  logs: "/var/log/linuxpanel"
  websites: "/var/www"
  
security:
  jwt_secret: "$(openssl rand -base64 32)"
  session_timeout: 86400
EOF
```

#### 初始化数据库

```bash
# 创建数据库和用户
sudo mysql -e "CREATE DATABASE IF NOT EXISTS linuxpanel DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'linuxpanel'@'localhost' IDENTIFIED BY 'linuxpanel';"
sudo mysql -e "GRANT ALL PRIVILEGES ON linuxpanel.* TO 'linuxpanel'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
```

#### 配置Nginx

```bash
# 创建Nginx配置
sudo bash -c 'cat > /etc/nginx/conf.d/linuxpanel.conf' <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        root /opt/linuxpanel/ui/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 测试并重载Nginx配置
sudo nginx -t
sudo systemctl reload nginx
```

#### 创建系统服务

```bash
# 创建systemd服务文件
sudo bash -c 'cat > /etc/systemd/system/linuxpanel.service' <<EOF
[Unit]
Description=Linux Panel Service
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/linuxpanel
ExecStart=/opt/linuxpanel/linuxpanel
Restart=on-failure
RestartSec=5s
LimitNOFILE=1000000
Environment=CONFIG_FILE=/etc/linuxpanel/config.yaml

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd配置
sudo systemctl daemon-reload

# 启用并启动服务
sudo systemctl enable linuxpanel.service
sudo systemctl start linuxpanel.service
```

#### 创建初始管理员账户

```bash
# 创建用户目录
sudo mkdir -p /var/lib/linuxpanel/data/users

# 生成随机盐值
SALT=$(openssl rand -hex 8)

# 使用MD5+盐值生成密码
PASSWORD_HASH=$(echo -n "admin$SALT" | md5sum | cut -d ' ' -f 1)

# 创建用户配置文件
sudo bash -c "cat > /var/lib/linuxpanel/data/users/admin.json" <<EOF
{
    "username": "admin",
    "password_hash": "$PASSWORD_HASH",
    "salt": "$SALT",
    "role": "admin",
    "email": "admin@example.com",
    "created_at": "$(date +%s)",
    "last_login": "0"
}
EOF
```

#### 配置防火墙

```bash
# UFW (Ubuntu/Debian)
if command -v ufw &> /dev/null; then
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    
    # 如果防火墙未启用
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "y" | sudo ufw enable
    fi
fi

# Firewalld (CentOS/RHEL)
if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
fi
```

## 从源码安装开发环境

如果您是开发人员，想要设置开发环境，可以按照以下步骤操作：

### 后端开发环境

```bash
# 克隆仓库
git clone https://github.com/erniang/LinuxPanel.git
cd LinuxPanel

# 设置GOPROXY（国内用户推荐）
export GOPROXY=https://goproxy.cn,direct

# 安装依赖
go mod tidy

# 直接运行（开发模式）
go run main.go
```

### 前端开发环境

```bash
# 进入前端目录
cd ui

# 安装依赖
npm install

# 创建开发环境配置
cat > .env.development <<EOF
VITE_APP_BASE_API=http://localhost:8080/api
EOF

# 启动开发服务器
npm run dev
```

## 升级指南

### 使用安装脚本升级

```bash
# 下载最新的安装脚本
wget https://raw.githubusercontent.com/erniang/LinuxPanel/main/install.sh -O update.sh

# 添加执行权限
chmod +x update.sh

# 执行升级（添加upgrade参数）
sudo ./update.sh upgrade
```

### 手动升级

```bash
# 备份数据
sudo cp -r /var/lib/linuxpanel/data /var/lib/linuxpanel/data_backup_$(date +%Y%m%d)
sudo cp /etc/linuxpanel/config.yaml /etc/linuxpanel/config.yaml.backup

# 停止服务
sudo systemctl stop linuxpanel

# 进入工作目录
cd /opt/linuxpanel

# 获取最新代码
git fetch --all
git reset --hard origin/main

# 编译后端
export GOPROXY=https://goproxy.cn,direct
go mod tidy
go build -o linuxpanel

# 编译前端
cd ui
npm install
npm run build
cd ..

# 启动服务
sudo systemctl start linuxpanel
```

## 常见问题排除

### 服务无法启动

检查服务状态和日志：

```bash
# 检查服务状态
sudo systemctl status linuxpanel

# 查看日志
sudo journalctl -u linuxpanel -n 100 --no-pager
sudo tail -f /var/log/linuxpanel/error.log
```

### 前端无法访问

检查Nginx配置和状态：

```bash
# 检查Nginx配置
sudo nginx -t

# 检查Nginx状态
sudo systemctl status nginx

# 查看Nginx日志
sudo tail -f /var/log/nginx/error.log
```

### 数据库连接问题

验证数据库配置：

```bash
# 检查MySQL服务状态
sudo systemctl status mysql

# 验证数据库连接
mysql -u linuxpanel -p -e "USE linuxpanel; SELECT 1;"
```

### 防火墙问题

确保必要的端口已开放：

```bash
# 检查UFW状态（Ubuntu/Debian）
sudo ufw status

# 检查Firewalld状态（CentOS/RHEL）
sudo firewall-cmd --list-all
```

### 权限问题

确保目录和文件具有正确的权限：

```bash
# 设置关键目录权限
sudo chown -R root:root /opt/linuxpanel
sudo chown -R root:root /etc/linuxpanel
sudo chown -R root:root /var/lib/linuxpanel
sudo chmod -R 755 /opt/linuxpanel
sudo chmod -R 755 /etc/linuxpanel
sudo chmod -R 755 /var/lib/linuxpanel
```

如果您遇到其他问题，请查看[常见问题](faq.md)文档或在GitHub上提交Issue。 