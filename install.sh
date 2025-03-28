#!/bin/bash

# 轻量级Linux面板一键安装脚本
# 作者: LinuxPanel开发团队
# 版本: 2.0.0

# 设置颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测是否为root用户
check_root() {
    if [ $(id -u) -ne 0 ]; then
        echo -e "${RED}错误: 请使用root用户运行此脚本${NC}"
        exit 1
    fi
}

# 检测Linux发行版
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        echo -e "检测到操作系统: ${YELLOW}$OS $VERSION${NC}"
    else
        echo -e "${RED}无法确定操作系统类型${NC}"
        exit 1
    fi
}

# 安装基础依赖
install_dependencies() {
    echo -e "${BLUE}开始安装基础依赖...${NC}"
    
    # 修复Debian 11安全源
    if [ "$OS" = "debian" ] && [ "$VERSION_ID" = "11" ]; then
        # 备份sources.list
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        
        # 更新为最新的源地址
        cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
    fi
    
    # 更新软件包列表
    apt-get update -y
    
    # 安装基本依赖
    apt-get install -y curl wget git build-essential sqlite3
    
    # 安装Node.js
    echo -e "${BLUE}正在安装Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash - || {
        echo -e "${YELLOW}Node.js源添加失败，使用系统默认版本${NC}"
    }
    apt-get install -y nodejs
    
    # 安装或升级Go
    echo -e "${BLUE}正在安装Go 1.21...${NC}"
    GO_VERSION=$(go version 2>/dev/null | grep -oP 'go\K[0-9.]+' || echo "0")
    if [[ "$(printf '%s\n' "1.21" "$GO_VERSION" | sort -V | head -n1)" != "1.21" ]]; then
        echo -e "${YELLOW}Go版本 $GO_VERSION 不满足要求，正在安装Go 1.21...${NC}"
        # 下载并安装Go 1.21
        wget https://dl.google.com/go/go1.21.0.linux-amd64.tar.gz -O /tmp/go1.21.0.linux-amd64.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go1.21.0.linux-amd64.tar.gz
        if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" /root/.bashrc; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
        fi
        export PATH=$PATH:/usr/local/go/bin
        rm -f /tmp/go1.21.0.linux-amd64.tar.gz
    fi
    
    echo -e "${GREEN}依赖安装完成${NC}"
}

# 创建工作目录
create_directories() {
    echo -e "${BLUE}创建工作目录...${NC}"
    
    # 创建必要的目录
    mkdir -p /opt/linuxpanel
    mkdir -p /etc/linuxpanel
    mkdir -p /var/lib/linuxpanel/data
    mkdir -p /var/log/linuxpanel
    mkdir -p /var/www
    
    echo -e "${GREEN}工作目录创建完成${NC}"
}

# 获取代码
get_code() {
    echo -e "${BLUE}获取代码...${NC}"
    
    # 进入工作目录
    cd /opt/linuxpanel
    
    # 清空目录以避免冲突
    find . -maxdepth 1 -not -path . -not -path './.git*' -exec rm -rf {} \;
    
    # 尝试克隆仓库
    if git clone --depth=1 https://github.com/erniang/LinuxPanel.git . 2>/dev/null; then
        echo -e "${GREEN}代码获取完成${NC}"
    else
        echo -e "${YELLOW}代码获取失败，尝试使用镜像源...${NC}"
        # 尝试使用压缩包下载
        wget https://github.com/erniang/LinuxPanel/archive/refs/heads/main.tar.gz -O /tmp/linuxpanel.tar.gz
        
        # 解压到临时目录
        mkdir -p /tmp/linuxpanel
        tar -xzf /tmp/linuxpanel.tar.gz -C /tmp/linuxpanel --strip-components=1
        
        # 复制文件到目标目录（而非移动，避免由于目录非空导致的错误）
        cp -rf /tmp/linuxpanel/* /opt/linuxpanel/
        
        # 清理临时文件
        rm -rf /tmp/linuxpanel /tmp/linuxpanel.tar.gz
        
        echo -e "${GREEN}代码获取完成${NC}"
    fi
}

# 创建必要的目录结构
create_project_structure() {
    echo -e "${BLUE}创建项目目录结构...${NC}"
    
    cd /opt/linuxpanel
    
    # 创建必要的目录
    mkdir -p pkg/database
    mkdir -p pkg/common
    mkdir -p pkg/types
    mkdir -p configs
    mkdir -p ui/dist
    
    echo -e "${GREEN}项目目录结构创建完成${NC}"
}

# 更新Go依赖和版本
update_go_dependencies() {
    echo -e "${BLUE}更新Go依赖和版本...${NC}"
    
    cd /opt/linuxpanel
    
    # 更新go.mod文件以使用Go 1.21
    cat > go.mod <<EOL
module github.com/erniang/LinuxPanel

go 1.21

require (
	github.com/gin-gonic/gin v1.9.1
	github.com/mattn/go-sqlite3 v1.14.17
	github.com/shirou/gopsutil/v3 v3.23.7
	golang.org/x/crypto v0.14.0
	gopkg.in/yaml.v3 v3.0.1
)
EOL
    
    # 设置代理以加速下载
    export GOPROXY=https://goproxy.cn,direct
    
    # 更新依赖
    go mod tidy
    
    echo -e "${GREEN}Go依赖更新完成${NC}"
}

# 创建必要的代码文件
create_code_files() {
    echo -e "${BLUE}创建必要的代码文件...${NC}"
    
    cd /opt/linuxpanel
    
    # 创建SQLite数据库处理文件
    cat > pkg/database/sqlite.go <<EOL
package database

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

// DB 数据库连接
var DB *sql.DB

// Init 初始化数据库连接
func Init(dbPath string) error {
	// 确保目录存在
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	var err error
	DB, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		return err
	}

	// 测试连接
	if err = DB.Ping(); err != nil {
		return err
	}

	log.Println("数据库连接成功")
	
	// 初始化表结构
	if err = initTables(); err != nil {
		return err
	}

	return nil
}

// Close 关闭数据库连接
func Close() {
	if DB != nil {
		DB.Close()
	}
}

// 初始化表结构
func initTables() error {
	// 用户表
	_, err := DB.Exec(\`
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT NOT NULL UNIQUE,
		password TEXT NOT NULL,
		role TEXT NOT NULL,
		email TEXT,
		real_name TEXT,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		last_login TIMESTAMP
	);\`)
	if err != nil {
		return err
	}

	// 网站表
	_, err = DB.Exec(\`
	CREATE TABLE IF NOT EXISTS websites (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		domain TEXT NOT NULL,
		path TEXT NOT NULL,
		port INTEGER,
		status INTEGER DEFAULT 1,
		php_version TEXT,
		ssl_enabled INTEGER DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);\`)
	if err != nil {
		return err
	}

	// 检查是否需要初始化管理员账户
	var count int
	err = DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if err != nil {
		return err
	}

	// 如果没有用户，创建默认管理员
	if count == 0 {
		_, err = DB.Exec(\`INSERT INTO users (username, password, role) VALUES ('admin', '$2a$10$uIBEsK0BbGQ6Lr.2oHjy0uKBFbXzS9YBjaoBd1tYYb8JkjWVZzWQ6', 'admin');\`)
		if err != nil {
			return err
		}
		log.Println("已创建默认管理员账户: admin/admin123")
	}

	return nil
}
EOL

    # 创建通用类型文件
    cat > pkg/common/types.go <<EOL
package common

import (
	"time"
)

// SystemInfo 系统信息
type SystemInfo struct {
	Hostname    string    \`json:"hostname"\`
	OS          string    \`json:"os"\`
	Platform    string    \`json:"platform"\`
	KernelVer   string    \`json:"kernel_version"\`
	Arch        string    \`json:"arch"\`
	GoVersion   string    \`json:"go_version"\`
	CPUCores    int       \`json:"cpu_cores"\`
	Memory      uint64    \`json:"memory"\`
	Uptime      uint64    \`json:"uptime"\`
	BootTime    time.Time \`json:"boot_time"\`
	ServerTime  time.Time \`json:"server_time"\`
	PanelVer    string    \`json:"panel_version"\`
	PanelUptime time.Time \`json:"panel_uptime"\`
}

// SystemStatus 系统状态
type SystemStatus struct {
	CPUUsage    float64 \`json:"cpu_usage"\`
	MemoryUsage float64 \`json:"memory_usage"\`
	MemoryFree  uint64  \`json:"memory_free"\`
	MemoryTotal uint64  \`json:"memory_total"\`
	DiskUsage   float64 \`json:"disk_usage"\`
	DiskFree    uint64  \`json:"disk_free"\`
	DiskTotal   uint64  \`json:"disk_total"\`
	Load1       float64 \`json:"load1"\`
	Load5       float64 \`json:"load5"\`
	Load15      float64 \`json:"load15"\`
}
EOL

    # 创建配置文件
    cat > configs/config.yaml <<EOL
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
  jwt_secret: "linuxpanel-secret-key-change-in-production"
  session_timeout: 86400
EOL

    # 创建前端package.json
    cat > ui/package.json <<EOL
{
  "name": "linuxpanel-ui",
  "version": "1.0.0",
  "description": "LinuxPanel前端界面",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.5.0",
    "chart.js": "^4.3.3",
    "element-plus": "^2.3.12",
    "pinia": "^2.1.6",
    "vue": "^3.3.4",
    "vue-router": "^4.2.4"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^4.3.4",
    "sass": "^1.66.1",
    "vite": "^4.4.9"
  }
}
EOL

    echo -e "${GREEN}代码文件创建完成${NC}"
}

# 编译后端
build_backend() {
    echo -e "${BLUE}开始编译后端...${NC}"
    
    cd /opt/linuxpanel
    
    # 设置代理以加速下载
    export GOPROXY=https://goproxy.cn,direct
    
    # 下载依赖
    go mod tidy
    
    # 编译
    go build -o linuxpanel
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}后端编译失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}后端编译完成${NC}"
}

# 创建前端占位
create_frontend_placeholder() {
    echo -e "${BLUE}创建前端占位目录...${NC}"
    
    mkdir -p /opt/linuxpanel/ui/dist
    
    # 创建占位页面
    cat > /opt/linuxpanel/ui/dist/index.html <<EOL
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LinuxPanel</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f6f9;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            color: #333;
        }
        .container {
            text-align: center;
            background-color: white;
            border-radius: 10px;
            padding: 40px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
            max-width: 600px;
        }
        h1 {
            color: #409EFF;
            margin-bottom: 20px;
        }
        p {
            line-height: 1.6;
            margin-bottom: 20px;
        }
        .status {
            display: inline-block;
            background-color: #67C23A;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-weight: bold;
        }
        .info {
            margin-top: 30px;
            font-size: 0.9em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>LinuxPanel 面板已成功安装</h1>
        <p>面板后端服务正常运行中</p>
        <div class="status">运行中</div>
        <div class="info">
            <p>您可以通过应用商店安装Nginx、MySQL和PHP等服务</p>
            <p>默认管理员账户: admin</p>
            <p>默认密码: admin123</p>
            <p>API地址: http://localhost:8080/api</p>
        </div>
    </div>
</body>
</html>
EOL
    
    echo -e "${GREEN}前端占位创建完成${NC}"
}

# 创建配置文件
create_config() {
    echo -e "${BLUE}创建配置文件...${NC}"
    
    # 创建主配置文件 - 使用SQLite
    cat > /etc/linuxpanel/config.yaml <<EOL
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
  jwt_secret: "$(openssl rand -base64 32)"
  session_timeout: 86400
EOL
    
    # 确保SQLite数据库目录存在
    mkdir -p /var/lib/linuxpanel/data
    
    echo -e "${GREEN}配置文件创建完成${NC}"
}

# 创建systemd服务
create_service() {
    echo -e "${BLUE}创建系统服务...${NC}"
    
    # 创建systemd服务文件
    cat > /etc/systemd/system/linuxpanel.service <<EOL
[Unit]
Description=Linux Panel Service
After=network.target

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
EOL
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用并启动服务
    systemctl enable linuxpanel.service
    systemctl start linuxpanel.service
    
    echo -e "${GREEN}系统服务创建完成${NC}"
}

# 更新README文档
update_readme() {
    echo -e "${BLUE}更新README文档...${NC}"
    
    cat > /opt/linuxpanel/README.md <<EOL
# LinuxPanel - 轻量级Linux服务器管理面板

LinuxPanel是一个轻量级的Linux服务器管理面板，提供直观的Web界面来管理您的Linux服务器，采用模块化设计，支持通过应用商店按需安装所需的组件。

## 功能特性

### 核心功能
- 系统信息监控
- 模块化设计
- 基于SQLite的数据存储
- 轻量级资源占用

### 可选模块（通过应用商店安装）
- Nginx网站管理
- MySQL/MariaDB数据库管理
- PHP运行环境
- 文件管理
- 防火墙配置
- SSL证书申请

## 系统要求

- Linux操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 10+)
- 最小配置：1核CPU，512MB内存，5GB硬盘空间
- 推荐配置：2核CPU，1GB内存，10GB+硬盘空间

## 快速安装

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/erniang/LinuxPanel/main/install.sh

# 给脚本添加执行权限
chmod +x install.sh

# 以root用户运行安装脚本
sudo ./install.sh
```

## 使用指南

安装完成后，通过浏览器访问服务器IP地址（或配置域名），默认监听8080端口：

```
http://YOUR_SERVER_IP:8080
```

初始登录凭证：
- 用户名：admin
- 密码：admin123

**重要提示：** 首次登录后请立即修改默认密码！

## 配置文件

主配置文件位于 \`/etc/linuxpanel/config.yaml\`

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

## 许可证

本项目采用GPL-3.0 License
EOL
    
    echo -e "${GREEN}README文档更新完成${NC}"
}

# 设置防火墙
configure_firewall() {
    echo -e "${BLUE}配置防火墙...${NC}"
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian
        ufw allow ssh
        ufw allow 8080/tcp
        
        # 如果防火墙未启用
        if ! ufw status | grep -q "Status: active"; then
            echo "y" | ufw enable
        fi
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --reload
    else
        echo -e "${YELLOW}未检测到防火墙，请手动配置防火墙规则${NC}"
    fi
    
    echo -e "${GREEN}防火墙配置完成${NC}"
}

# 完成安装
finish_install() {
    # 获取服务器IP
    SERVER_IP=$(ip -4 addr | grep inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}轻量级Linux面板安装完成！${NC}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${BLUE}访问地址: http://$SERVER_IP:8080${NC}"
    echo -e "${BLUE}默认用户名: admin${NC}"
    echo -e "${BLUE}默认密码: admin123${NC}"
    echo -e "${YELLOW}请立即登录并修改默认密码！${NC}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${BLUE}服务管理命令:${NC}"
    echo -e "  启动: ${YELLOW}systemctl start linuxpanel${NC}"
    echo -e "  停止: ${YELLOW}systemctl stop linuxpanel${NC}"
    echo -e "  重启: ${YELLOW}systemctl restart linuxpanel${NC}"
    echo -e "  状态: ${YELLOW}systemctl status linuxpanel${NC}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${BLUE}日志位置: /var/log/linuxpanel${NC}"
    echo -e "${BLUE}配置文件: /etc/linuxpanel/config.yaml${NC}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${YELLOW}提示: 您可以通过应用商店安装Nginx、MySQL和PHP等服务${NC}"
    echo -e "${GREEN}====================================================${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}       轻量级Linux面板一键安装脚本 v2.0.0            ${NC}"
    echo -e "${GREEN}====================================================${NC}"
    
    check_root
    check_os
    install_dependencies
    create_directories
    get_code
    create_project_structure
    update_go_dependencies
    create_code_files
    build_backend
    create_frontend_placeholder
    create_config
    create_service
    configure_firewall
    update_readme
    finish_install
}

# 执行主函数
main 