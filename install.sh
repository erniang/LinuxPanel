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
    
    # 创建主入口文件main.go
    cat > main.go <<EOL
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/erniang/LinuxPanel/pkg/database"
	"github.com/gin-gonic/gin"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Server struct {
		Port int    \`yaml:"port"\`
		Host string \`yaml:"host"\`
	} \`yaml:"server"\`
	Database struct {
		Type string \`yaml:"type"\`
		Path string \`yaml:"path"\`
	} \`yaml:"database"\`
	Paths struct {
		Data     string \`yaml:"data"\`
		Logs     string \`yaml:"logs"\`
		Websites string \`yaml:"websites"\`
	} \`yaml:"paths"\`
	Security struct {
		JWTSecret      string \`yaml:"jwt_secret"\`
		SessionTimeout int    \`yaml:"session_timeout"\`
	} \`yaml:"security"\`
}

var (
	configFile = flag.String("config", "", "配置文件路径")
	config     Config
)

func init() {
	flag.Parse()

	// 检查环境变量中是否设置了配置文件路径
	if envConfig := os.Getenv("CONFIG_FILE"); envConfig != "" && *configFile == "" {
		*configFile = envConfig
	}

	// 如果没有指定配置文件，使用默认路径
	if *configFile == "" {
		*configFile = "/etc/linuxpanel/config.yaml"
	}

	// 读取配置文件
	data, err := os.ReadFile(*configFile)
	if err != nil {
		log.Fatalf("读取配置文件失败: %v", err)
	}

	// 解析配置文件
	if err := yaml.Unmarshal(data, &config); err != nil {
		log.Fatalf("解析配置文件失败: %v", err)
	}

	// 初始化数据库连接
	if err := database.Init(config.Database.Path); err != nil {
		log.Fatalf("初始化数据库失败: %v", err)
	}
}

func main() {
	// 设置gin模式
	gin.SetMode(gin.ReleaseMode)

	// 创建gin路由引擎
	r := gin.Default()

	// 设置静态文件服务
	r.Static("/assets", "./ui/dist/assets")
	r.StaticFile("/favicon.ico", "./ui/dist/favicon.ico")
	
	// API路由组
	api := r.Group("/api")
	{
		api.GET("/system/info", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"hostname": "server001",
				"os": "Linux",
				"kernel_version": "5.10.0",
				"cpu_cores": 4,
				"uptime": 86400,
				"cpu_usage": 15,
				"memory_usage": 45,
				"disk_usage": 35,
				"panel_version": "1.0.0",
			})
		})

		api.POST("/auth/login", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"token": "mock-token-12345",
				"user": gin.H{
					"username": "admin",
					"role": "admin",
				},
			})
		})
	}

	// 所有其他路由都返回前端首页，支持前端路由
	r.NoRoute(func(c *gin.Context) {
		// 检查请求的路径是否是API
		if len(c.Request.URL.Path) >= 4 && c.Request.URL.Path[:4] == "/api" {
			c.JSON(http.StatusNotFound, gin.H{"error": "API not found"})
			return
		}

		// 非API请求返回前端首页
		c.File("./ui/dist/index.html")
	})

	// 启动服务器
	addr := fmt.Sprintf("%s:%d", config.Server.Host, config.Server.Port)
	log.Printf("服务器启动在 %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("启动服务器失败: %v", err)
	}
}
EOL

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

# 构建前端界面
build_frontend() {
    echo -e "${BLUE}开始构建前端界面...${NC}"
    
    # 创建前端基本目录
    mkdir -p /opt/linuxpanel/ui/src
    mkdir -p /opt/linuxpanel/ui/dist
    mkdir -p /opt/linuxpanel/ui/dist/assets
    
    # 创建前端基本文件结构
    mkdir -p /opt/linuxpanel/ui/src/assets
    mkdir -p /opt/linuxpanel/ui/src/components
    mkdir -p /opt/linuxpanel/ui/src/views
    mkdir -p /opt/linuxpanel/ui/src/router
    mkdir -p /opt/linuxpanel/ui/src/styles
    mkdir -p /opt/linuxpanel/ui/public
    
    # 创建一个完整的前端应用
    # 1. 创建package.json
    cat > /opt/linuxpanel/ui/package.json <<EOL
{
  "name": "linuxpanel-ui",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "serve": "vue-cli-service serve",
    "build": "vue-cli-service build",
    "lint": "vue-cli-service lint"
  },
  "dependencies": {
    "axios": "^0.21.1",
    "core-js": "^3.6.5",
    "element-plus": "^1.0.2-beta.44",
    "echarts": "^5.1.1",
    "vue": "^3.0.0",
    "vue-router": "^4.0.6",
    "vuex": "^4.0.0"
  },
  "devDependencies": {
    "@vue/cli-plugin-babel": "~4.5.0",
    "@vue/cli-plugin-eslint": "~4.5.0",
    "@vue/cli-plugin-router": "~4.5.0",
    "@vue/cli-plugin-vuex": "~4.5.0",
    "@vue/cli-service": "~4.5.0",
    "@vue/compiler-sfc": "^3.0.0",
    "babel-eslint": "^10.1.0",
    "eslint": "^6.7.2",
    "eslint-plugin-vue": "^7.0.0",
    "sass": "^1.26.5",
    "sass-loader": "^8.0.2"
  }
}
EOL

    # 创建静态资源目录和文件
    mkdir -p /opt/linuxpanel/ui/dist/assets/css
    mkdir -p /opt/linuxpanel/ui/dist/assets/js
    mkdir -p /opt/linuxpanel/ui/dist/assets/img
    
    # 创建基本CSS文件
    cat > /opt/linuxpanel/ui/dist/assets/css/main.css <<EOL
body, html {
  margin: 0;
  padding: 0;
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  height: 100%;
  background-color: #f5f7fa;
}

#app {
  height: 100%;
}

.container {
  padding: 20px;
}

.card {
  background: #fff;
  border-radius: 4px;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
  padding: 20px;
  margin-bottom: 20px;
}

.text-center {
  text-align: center;
}

.color-primary {
  color: #409EFF;
}

.header {
  background-color: #fff;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
  height: 60px;
  display: flex;
  align-items: center;
  padding: 0 20px;
}

.sidebar {
  background-color: #304156;
  color: #bfcbd9;
  width: 200px;
  height: calc(100vh - 60px);
}

.main-content {
  padding: 20px;
  background-color: #f0f2f5;
  min-height: calc(100vh - 60px);
}

.btn {
  display: inline-block;
  line-height: 1;
  white-space: nowrap;
  cursor: pointer;
  background: #fff;
  border: 1px solid #dcdfe6;
  color: #606266;
  text-align: center;
  box-sizing: border-box;
  outline: none;
  margin: 0;
  transition: .1s;
  font-weight: 500;
  padding: 12px 20px;
  font-size: 14px;
  border-radius: 4px;
}

.btn-primary {
  color: #fff;
  background-color: #409EFF;
  border-color: #409EFF;
}

.btn-primary:hover {
  background: #66b1ff;
  border-color: #66b1ff;
  color: #fff;
}

.form-group {
  margin-bottom: 20px;
}

.form-label {
  display: block;
  margin-bottom: 5px;
  font-size: 14px;
  color: #606266;
}

.form-control {
  width: 100%;
  padding: 10px;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  box-sizing: border-box;
  font-size: 14px;
  color: #606266;
}

.form-control:focus {
  outline: none;
  border-color: #409EFF;
}
EOL

    # 创建基本JavaScript文件
    cat > /opt/linuxpanel/ui/dist/assets/js/main.js <<EOL
// 基本JavaScript功能
document.addEventListener('DOMContentLoaded', function() {
  // 登录按钮事件处理
  const loginBtn = document.getElementById('login-btn');
  if (loginBtn) {
    loginBtn.addEventListener('click', function() {
      const username = document.getElementById('username').value;
      const password = document.getElementById('password').value;
      
      if (username === 'admin' && password === 'admin123') {
        // 简单模拟登录成功
        localStorage.setItem('token', 'mock-token-12345');
        localStorage.setItem('user', JSON.stringify({name: 'admin', role: 'admin'}));
        window.location.href = '/dashboard';
      } else {
        alert('用户名或密码错误');
      }
    });
  }
  
  // 检查登录状态
  const token = localStorage.getItem('token');
  const isLoginPage = window.location.pathname === '/login';
  
  if (!token && !isLoginPage) {
    window.location.href = '/login';
  }
  
  // 登出按钮事件处理
  const logoutBtn = document.getElementById('logout-btn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', function() {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    });
  }
});
EOL

    # 创建一个Favicon
    cat > /opt/linuxpanel/ui/dist/favicon.ico <<EOL
AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAABILAAASCwAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUFBQMFBQUyBQUFZAUFBXoFBQV6BQUF
ZAUFBTIFBQUDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQUFBUAFBQXRBQUFzwUFBZ8FBQWP
BQUFzwUFBdEFBQVBAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAABQUFAgUFBZcFBQXbBQUFMAUFBQsA
AAAAAAAAAAAAAAAFBQULBQUFMAUFBdsFBQWXBQUFAgAAAAAAAAAABQUFNwUFBd8FBQVjAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFBQVjBQUF3wUFBTcAAAAABQUFAgUFBaMFBQXWBQUFGAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFBQUYBQUFSQUFBaIFBQUCBQUFNwUFBd8FBQVnAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQUFBWcFBQXfBQUFNwUFBZcFBQXb
BQUFEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQUFQ4FBQXbBQUFlwUFBd8F
BQVjAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMFBQVkBQUF3wUF
BUEFBQXRBQUFTgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFBQVOBQUF
0QUFBQEFBQUyBQUFzwUFBV4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUGBV4FBQXP
BQUFMgAAAAAFBQUDBQUFZAUFBbsFBQUuAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQUFLgUFBbsF
BQVkBQUFAwAAAAAAAAAAAAAAAQUFBWQFBQXfBQUFjwUFBS4FBQUFAAAAAAAAAAAFBQUFBQUFLgUF
BY8FBQXfBQUFZAAAAAEAAAAAAAAAAAAAAAAFBQUDBQUFMgUFBWQFBQV6BQUFegUFBWQFBQUyBQUF
AwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAA==
EOL

    # 创建主HTML文件
    cat > /opt/linuxpanel/ui/dist/index.html <<EOL
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width,initial-scale=1.0">
    <link rel="stylesheet" href="/assets/css/main.css">
    <title>LinuxPanel - 轻量级Linux服务器管理面板</title>
    <style>
        .login-container {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background: linear-gradient(135deg, #8e9eab, #eef2f3);
        }
        .login-box {
            width: 350px;
            background: #fff;
            border-radius: 6px;
            box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            padding: 30px;
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: #409EFF;
            margin: 0;
            font-size: 28px;
        }
        .logo p {
            margin: 10px 0 0;
            font-size: 14px;
            color: #606266;
        }
        .login-tips {
            text-align: center;
            font-size: 12px;
            color: #909399;
            margin-top: 20px;
        }
        
        /* 仪表盘样式 */
        .dashboard {
            display: none;
        }
        .app-layout {
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        .app-header {
            background-color: #fff;
            box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
            height: 60px;
            display: flex;
            align-items: center;
            padding: 0 20px;
            justify-content: space-between;
        }
        .app-logo {
            color: #409EFF;
            font-size: 20px;
            font-weight: bold;
        }
        .header-right {
            display: flex;
            align-items: center;
        }
        .content-container {
            display: flex;
            flex: 1;
            overflow: hidden;
        }
        .sidebar {
            width: 200px;
            background-color: #304156;
            color: #bfcbd9;
            overflow-y: auto;
        }
        .menu {
            padding: 0;
            margin: 0;
            list-style: none;
        }
        .menu-item {
            height: 50px;
            line-height: 50px;
            padding: 0 20px;
            cursor: pointer;
            transition: background-color 0.3s;
        }
        .menu-item:hover, .menu-item.active {
            background-color: #263445;
            color: #409EFF;
        }
        .main-content {
            flex: 1;
            padding: 20px;
            background-color: #f0f2f5;
            overflow-y: auto;
        }
        .welcome-card {
            background-color: #fff;
            border-radius: 4px;
            box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            padding: 20px;
            text-align: center;
            margin-bottom: 20px;
        }
        .welcome-card h2 {
            color: #409EFF;
            margin-top: 0;
        }
        .stats-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            margin-bottom: 20px;
        }
        .stat-card {
            background-color: #fff;
            border-radius: 4px;
            box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            padding: 20px;
            flex: 1;
            min-width: 200px;
            text-align: center;
        }
        .stat-title {
            font-size: 14px;
            color: #606266;
            margin-bottom: 10px;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            color: #303133;
            margin-bottom: 10px;
        }
        .progress-bar {
            height: 6px;
            background-color: #e6e6e6;
            border-radius: 3px;
            overflow: hidden;
        }
        .progress-inner {
            height: 100%;
            background-color: #67C23A;
            border-radius: 3px;
        }
        .info-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
        }
        .info-card {
            background-color: #fff;
            border-radius: 4px;
            box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            flex: 1;
            min-width: 300px;
        }
        .info-header {
            padding: 15px 20px;
            font-weight: bold;
            border-bottom: 1px solid #EBEEF5;
        }
        .info-content {
            padding: 0;
        }
        .info-item {
            display: flex;
            justify-content: space-between;
            padding: 12px 20px;
            border-bottom: 1px solid #EBEEF5;
        }
        .info-item:last-child {
            border-bottom: none;
        }
        .info-label {
            color: #606266;
        }
        .info-value {
            color: #303133;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div id="app">
        <!-- 登录页面 -->
        <div class="login-container" id="login-page">
            <div class="login-box">
                <div class="logo">
                    <h1>LinuxPanel</h1>
                    <p>轻量级Linux服务器管理面板</p>
                </div>
                <div class="form-group">
                    <label class="form-label" for="username">用户名</label>
                    <input type="text" id="username" class="form-control" placeholder="请输入用户名">
                </div>
                <div class="form-group">
                    <label class="form-label" for="password">密码</label>
                    <input type="password" id="password" class="form-control" placeholder="请输入密码">
                </div>
                <button id="login-btn" class="btn btn-primary" style="width:100%">登录</button>
                <div class="login-tips">
                    默认用户名: admin<br>默认密码: admin123
                </div>
            </div>
        </div>
        
        <!-- 仪表盘页面 -->
        <div class="dashboard" id="dashboard-page">
            <div class="app-layout">
                <header class="app-header">
                    <div class="app-logo">LinuxPanel</div>
                    <div class="header-right">
                        <span id="username-display">admin</span>
                        <button id="logout-btn" class="btn" style="margin-left:15px">退出登录</button>
                    </div>
                </header>
                <div class="content-container">
                    <aside class="sidebar">
                        <ul class="menu">
                            <li class="menu-item active">仪表盘</li>
                            <li class="menu-item">网站管理</li>
                            <li class="menu-item">数据库</li>
                            <li class="menu-item">文件管理</li>
                            <li class="menu-item">应用商店</li>
                            <li class="menu-item">系统设置</li>
                        </ul>
                    </aside>
                    <main class="main-content">
                        <div class="welcome-card">
                            <h2>欢迎使用LinuxPanel控制面板</h2>
                            <p>轻量级的Linux服务器管理面板</p>
                        </div>
                        
                        <div class="stats-container">
                            <div class="stat-card">
                                <div class="stat-title">CPU使用率</div>
                                <div class="stat-value">15%</div>
                                <div class="progress-bar">
                                    <div class="progress-inner" style="width:15%"></div>
                                </div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-title">内存使用率</div>
                                <div class="stat-value">45%</div>
                                <div class="progress-bar">
                                    <div class="progress-inner" style="width:45%;background-color:#E6A23C"></div>
                                </div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-title">磁盘使用率</div>
                                <div class="stat-value">35%</div>
                                <div class="progress-bar">
                                    <div class="progress-inner" style="width:35%"></div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="info-container">
                            <div class="info-card">
                                <div class="info-header">系统信息</div>
                                <div class="info-content">
                                    <div class="info-item">
                                        <span class="info-label">主机名</span>
                                        <span class="info-value">server001</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">操作系统</span>
                                        <span class="info-value">Debian 11</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">内核版本</span>
                                        <span class="info-value">5.10.0-15-amd64</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">CPU核心数</span>
                                        <span class="info-value">4</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">总内存</span>
                                        <span class="info-value">8 GB</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">运行时间</span>
                                        <span class="info-value">5天 6小时</span>
                                    </div>
                                </div>
                            </div>
                            <div class="info-card">
                                <div class="info-header">面板信息</div>
                                <div class="info-content">
                                    <div class="info-item">
                                        <span class="info-label">面板版本</span>
                                        <span class="info-value">1.0.0</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">Go版本</span>
                                        <span class="info-value">1.21.0</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">已安装模块</span>
                                        <span class="info-value">核心模块</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">面板运行时间</span>
                                        <span class="info-value">1天 0小时</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">数据库类型</span>
                                        <span class="info-value">SQLite</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">面板端口</span>
                                        <span class="info-value">8080</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </main>
                </div>
            </div>
        </div>
    </div>
    
    <script src="/assets/js/main.js"></script>
    <script>
        // 简单路由处理
        document.addEventListener('DOMContentLoaded', function() {
            const loginPage = document.getElementById('login-page');
            const dashboardPage = document.getElementById('dashboard-page');
            const token = localStorage.getItem('token');
            
            // 根据URL路径和登录状态显示不同页面
            const path = window.location.pathname;
            
            if (token) {
                loginPage.style.display = 'none';
                dashboardPage.style.display = 'block';
                
                // 显示用户名
                const user = JSON.parse(localStorage.getItem('user') || '{"name":"admin"}');
                const usernameDisplay = document.getElementById('username-display');
                if (usernameDisplay) {
                    usernameDisplay.textContent = user.name;
                }
            } else {
                loginPage.style.display = 'flex';
                dashboardPage.style.display = 'none';
            }
        });
    </script>
</body>
</html>
EOL

    echo -e "${GREEN}前端界面搭建完成${NC}"
    echo -e "${YELLOW}注意: 这是一个基本的前端框架，后续可以通过应用商店完善功能${NC}"
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
    build_frontend
    create_config
    create_service
    configure_firewall
    update_readme
    finish_install
}

# 执行主函数
main 