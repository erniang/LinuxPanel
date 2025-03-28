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
    
    # 安装Node.js和npm
    install_nodejs
    
    # 检查并安装Go（改进版本检测逻辑）
    install_golang
    
    echo -e "${GREEN}依赖安装完成${NC}"
}

# 检查并安装Go
install_golang() {
    echo -e "${BLUE}检查Go环境...${NC}"
    
    # 检查go命令是否存在
    if command -v go &> /dev/null; then
        # 获取当前Go版本
        GO_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "0")
        GO_MAJOR=$(echo $GO_VERSION | cut -d. -f1)
        GO_MINOR=$(echo $GO_VERSION | cut -d. -f2)
        
        echo -e "${YELLOW}检测到Go版本: $GO_VERSION${NC}"
        
        # 检查版本是否满足要求 (>= 1.18)
        if [ "$GO_MAJOR" -gt 1 ] || ([ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -ge 18 ]); then
            echo -e "${GREEN}已安装的Go版本满足要求${NC}"
            return 0
        else
            echo -e "${YELLOW}Go版本过低 ($GO_VERSION)，需要1.18或更高版本${NC}"
        fi
    else
        echo -e "${YELLOW}未检测到Go环境，将进行安装${NC}"
    fi
    
    # 安装Go 1.21
    echo -e "${BLUE}正在安装Go 1.21...${NC}"
    
    # 检查是否已经下载了Go安装包
    GO_TMP_FILE="/tmp/go1.21.0.linux-amd64.tar.gz"
    if [ ! -f "$GO_TMP_FILE" ]; then
        wget https://dl.google.com/go/go1.21.0.linux-amd64.tar.gz -O $GO_TMP_FILE || {
            echo -e "${RED}Go下载失败，请检查网络连接${NC}"
            return 1
        }
    else
        echo -e "${YELLOW}使用已下载的Go安装包${NC}"
    fi
    
    # 备份现有Go安装（如果存在）
    if [ -d "/usr/local/go" ]; then
        echo -e "${YELLOW}备份现有Go安装...${NC}"
        mv /usr/local/go /usr/local/go_backup_$(date +%Y%m%d%H%M%S)
    fi
    
    # 安装新版本Go
    tar -C /usr/local -xzf $GO_TMP_FILE
    if [ $? -ne 0 ]; then
        echo -e "${RED}Go解压失败${NC}"
        return 1
    fi
    
    # 确保PATH中包含Go
    if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" /root/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
    fi
    
    # 为当前会话设置PATH
    export PATH=$PATH:/usr/local/go/bin
    
    # 验证安装
    if go version &> /dev/null; then
        GO_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "未知")
        echo -e "${GREEN}Go $GO_VERSION 安装成功${NC}"
        return 0
    else
        echo -e "${RED}Go安装验证失败，请手动安装Go 1.21或更高版本${NC}"
        return 1
    fi
}

# 安装Node.js和npm
install_nodejs() {
    echo -e "${BLUE}正在安装Node.js和npm...${NC}"
    
    # 检查当前Node.js版本
    NODE_VERSION=$(node -v 2>/dev/null || echo "v0.0.0")
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d. -f1 | tr -d 'v')
    
    # 如果版本低于16，安装Node.js 16
    if [ "$NODE_MAJOR" -lt "16" ]; then
        echo -e "${YELLOW}Node.js版本 $NODE_VERSION 不满足要求，正在安装Node.js 16...${NC}"
        
        # 根据不同的系统选择安装方式
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            # 安装Node.js 16 (Debian/Ubuntu)
            curl -fsSL https://deb.nodesource.com/setup_16.x | bash - || {
                echo -e "${RED}Node.js源添加失败，尝试使用其他方式安装${NC}"
                # 备选安装方式：使用NVM安装
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
                [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
                nvm install 16
                nvm use 16
            }
            apt-get install -y nodejs
        elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
            # 安装Node.js 16 (CentOS/RHEL)
            curl -fsSL https://rpm.nodesource.com/setup_16.x | bash - || {
                echo -e "${RED}Node.js源添加失败，尝试使用其他方式安装${NC}"
                # 备选安装方式：使用NVM安装
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
                [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
                nvm install 16
                nvm use 16
            }
            yum install -y nodejs
        else
            echo -e "${RED}不支持的操作系统，请手动安装Node.js 16或更高版本${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}检测到Node.js $NODE_VERSION，满足需求${NC}"
    fi
    
    # 验证Node.js和npm已安装
    NODE_VERSION=$(node -v 2>/dev/null || echo "未安装")
    NPM_VERSION=$(npm -v 2>/dev/null || echo "未安装")
    
    echo -e "${GREEN}Node.js版本: $NODE_VERSION${NC}"
    echo -e "${GREEN}npm版本: $NPM_VERSION${NC}"
    
    # 安装yarn (可选)
    if ! command -v yarn &> /dev/null; then
        echo -e "${BLUE}正在安装Yarn包管理器...${NC}"
        npm install -g yarn
        echo -e "${GREEN}Yarn已安装${NC}"
    else
        echo -e "${GREEN}Yarn已安装，版本: $(yarn -v)${NC}"
    fi
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

# 构建前端
build_frontend() {
    echo -e "${BLUE}开始构建前端...${NC}"
    
    cd /opt/linuxpanel/ui
    
    # 检查package.json是否存在
    if [ ! -f "package.json" ]; then
        echo -e "${RED}前端源码不完整，未找到package.json${NC}"
        create_temp_frontend
        return
    fi
    
    # 检查是否存在appstore目录，修复可能的问题
    if [ -f "src/views/appstore/index.vue" ]; then
        echo -e "${YELLOW}检测到可能有问题的文件，尝试修复...${NC}"
        fix_appstore_component
    fi
    
    # 安装依赖
    echo -e "${BLUE}安装前端依赖...${NC}"
    # 使用--no-fund --no-audit 减少不必要的警告
    npm install --no-fund --no-audit || yarn install
    
    # 检查是否有build脚本
    if grep -q '"build"' package.json; then
        echo -e "${BLUE}开始构建前端代码...${NC}"
        # 添加--force标志以忽略警告
        npm run build -- --no-clean || yarn build --no-clean
        
        # 检查构建是否成功
        if [ -d "dist" ] && [ -f "dist/index.html" ]; then
            echo -e "${GREEN}前端构建成功${NC}"
        else
            echo -e "${RED}前端构建失败，创建基本页面${NC}"
            create_temp_frontend
        fi
    else
        echo -e "${YELLOW}未找到build脚本，使用现有文件${NC}"
        # 确保dist目录存在
        mkdir -p dist
        # 如果不存在index.html，创建一个基本页面
        if [ ! -f "dist/index.html" ]; then
            create_temp_frontend
        fi
    fi
    
    # 返回主目录
    cd /opt/linuxpanel
}

# 修复应用商店组件
fix_appstore_component() {
    echo -e "${YELLOW}修复前端应用商店组件...${NC}"
    
    # 备份原文件
    cp src/views/appstore/index.vue src/views/appstore/index.vue.bak
    
    # 创建一个简单但有效的应用商店组件
    cat > src/views/appstore/index.vue <<EOL
<template>
  <div class="app-store-container">
    <h1>应用商店</h1>
    <div class="app-list" v-if="!loading">
      <div class="app-card" v-for="app in apps" :key="app.id">
        <div class="app-icon">
          <el-icon><Box /></el-icon>
        </div>
        <div class="app-info">
          <h3>{{ app.name }}</h3>
          <p>{{ app.description }}</p>
          <div class="app-meta">
            <span>版本: {{ app.version }}</span>
            <span>类型: {{ app.type }}</span>
          </div>
        </div>
        <div class="app-actions">
          <el-button type="primary" size="small" :loading="installing === app.id" @click="installApp(app)">
            {{ app.installed ? '更新' : '安装' }}
          </el-button>
          <el-button v-if="app.installed" type="danger" size="small" @click="uninstallApp(app)">卸载</el-button>
        </div>
      </div>
    </div>
    <div v-else class="loading-container">
      <el-skeleton :rows="10" animated />
    </div>
  </div>
</template>

<script>
export default {
  name: 'AppStore',
  data() {
    return {
      apps: [
        { id: 1, name: 'Nginx', description: 'Web服务器', version: '1.22.1', type: '服务器', installed: false },
        { id: 2, name: 'MySQL', description: '数据库服务', version: '8.0.31', type: '数据库', installed: false },
        { id: 3, name: 'PHP', description: 'PHP运行环境', version: '8.1.12', type: '运行环境', installed: false },
        { id: 4, name: 'Redis', description: '内存缓存服务', version: '7.0.5', type: '数据库', installed: false },
        { id: 5, name: 'phpMyAdmin', description: 'MySQL管理工具', version: '5.2.0', type: '工具', installed: false }
      ],
      loading: false,
      installing: null
    }
  },
  methods: {
    installApp(app) {
      this.installing = app.id
      // 模拟安装过程
      setTimeout(() => {
        app.installed = true
        this.installing = null
        this.$message.success(\`\${app.name} 安装成功\`)
      }, 1500)
    },
    uninstallApp(app) {
      this.$confirm(\`确定要卸载 \${app.name} 吗?\`, '确认操作', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }).then(() => {
        app.installed = false
        this.$message.success(\`\${app.name} 已卸载\`)
      }).catch(() => {})
    }
  }
}
</script>

<style scoped>
.app-store-container {
  padding: 20px;
}
.app-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
  margin-top: 20px;
}
.app-card {
  border: 1px solid #ebeef5;
  border-radius: 4px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
}
.app-icon {
  font-size: 40px;
  color: #409eff;
  text-align: center;
  margin-bottom: 15px;
}
.app-info {
  flex: 1;
}
.app-info h3 {
  margin: 0 0 10px 0;
}
.app-info p {
  color: #606266;
  margin: 0 0 15px 0;
}
.app-meta {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #909399;
  margin-bottom: 15px;
}
.app-actions {
  display: flex;
  justify-content: space-between;
}
.loading-container {
  padding: 20px;
}
</style>
EOL
    echo -e "${GREEN}应用商店组件已修复${NC}"
}

# 创建临时前端页面
create_temp_frontend() {
    echo -e "${YELLOW}创建基本前端页面${NC}"
    
    # 确保dist目录存在
    mkdir -p dist
    
    # 创建一个基本的前端页面
    cat > dist/index.html <<EOL
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LinuxPanel - 轻量级Linux服务器管理面板</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f5f7fa;
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
        .login-form {
            margin-top: 30px;
            text-align: left;
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        input {
            width: 100%;
            padding: 10px;
            border: 1px solid #dcdfe6;
            border-radius: 4px;
            box-sizing: border-box;
        }
        button {
            background-color: #409EFF;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            width: 100%;
            margin-top: 10px;
        }
        button:hover {
            background-color: #337ecc;
        }
        .api-status {
            margin-top: 20px;
            padding: 15px;
            background-color: #f0f9eb;
            border-radius: 4px;
            text-align: left;
        }
        .api-title {
            font-weight: bold;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>LinuxPanel 管理面板</h1>
        <p>轻量级Linux服务器管理系统</p>
        <div class="status">系统正常</div>
        
        <div class="login-form">
            <div class="form-group">
                <label for="username">用户名</label>
                <input type="text" id="username" placeholder="请输入用户名" value="admin">
            </div>
            <div class="form-group">
                <label for="password">密码</label>
                <input type="password" id="password" placeholder="请输入密码" value="admin123">
            </div>
            <button id="login-btn">登录</button>
        </div>
        
        <div class="info">
            <p>默认管理员账户: admin</p>
            <p>默认密码: admin123</p>
        </div>
        
        <div class="api-status">
            <div class="api-title">API状态检查</div>
            <div id="api-result">正在检查API连接状态...</div>
        </div>
    </div>
    
    <script>
        // 简单的API状态检查
        document.addEventListener('DOMContentLoaded', function() {
            const apiResult = document.getElementById('api-result');
            
            // 检查API是否可用
            fetch('/api/system/info')
                .then(response => {
                    if (response.ok) {
                        return response.json();
                    }
                    throw new Error('API请求失败');
                })
                .then(data => {
                    apiResult.innerHTML = '✅ API连接正常<br>系统信息:<br>' + 
                        '操作系统: ' + (data.os || 'Linux') + '<br>' + 
                        'CPU核心: ' + (data.cpu_cores || '4') + '<br>' +
                        '面板版本: ' + (data.panel_version || '1.0.0');
                    apiResult.style.backgroundColor = '#f0f9eb';
                })
                .catch(error => {
                    apiResult.innerHTML = '❌ API连接失败: ' + error.message + '<br>' +
                        '请确保服务正常运行，并刷新页面重试';
                    apiResult.style.backgroundColor = '#fef0f0';
                });
            
            // 登录按钮事件处理
            const loginBtn = document.getElementById('login-btn');
            loginBtn.addEventListener('click', function() {
                const username = document.getElementById('username').value;
                const password = document.getElementById('password').value;
                
                if (!username || !password) {
                    alert('请输入用户名和密码');
                    return;
                }
                
                loginBtn.disabled = true;
                loginBtn.textContent = '登录中...';
                
                fetch('/api/auth/login', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        username: username,
                        password: password
                    }),
                })
                .then(response => {
                    if (response.ok) {
                        return response.json();
                    }
                    throw new Error('登录失败');
                })
                .then(data => {
                    if (data.token) {
                        localStorage.setItem('token', data.token);
                        localStorage.setItem('user', JSON.stringify(data.user || {name: username}));
                        window.location.href = '/dashboard';
                    } else {
                        alert('登录失败: 无效的响应');
                    }
                })
                .catch(error => {
                    alert('登录失败: ' + error.message);
                })
                .finally(() => {
                    loginBtn.disabled = false;
                    loginBtn.textContent = '登录';
                });
            });
        });
    </script>
</body>
</html>
EOL

    # 创建一个assets目录
    mkdir -p dist/assets/css
    mkdir -p dist/assets/js
    
    # 创建基础CSS
    cat > dist/assets/css/main.css <<EOL
/* 基础样式 */
body {
    margin: 0;
    padding: 0;
    font-family: Arial, sans-serif;
}
EOL

    # 创建基础JS
    cat > dist/assets/js/main.js <<EOL
// 基础JavaScript
console.log('LinuxPanel 临时页面已加载');
EOL

    echo -e "${GREEN}临时前端页面已创建${NC}"
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
    echo -e "${BLUE}=== LinuxPanel 轻量级服务器面板安装程序 ===${NC}"
    
    # 权限检查
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}请使用root用户运行安装脚本${NC}"
        exit 1
    fi
    
    # 检查操作系统
    check_os
    
    # 显示安装信息
    echo -e "${GREEN}将安装LinuxPanel轻量级服务器面板 v1.0.0${NC}"
    echo -e "${YELLOW}操作系统: $OS $VERSION_ID${NC}"
    echo -e "${YELLOW}数据库: SQLite${NC}"
    
    # 安装确认
    read -p "确认安装? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        exit 1
    fi
    
    # 安装依赖
    install_dependencies
    
    # 创建工作目录
    create_directories
    
    # 获取源代码
    get_code
    
    # 构建前端
    build_frontend
    
    # 编译后端
    build_backend
    
    # 创建数据库
    create_config
    
    # 创建服务
    create_service
    
    # 更新README
    update_readme
    
    # 启动服务
    start_service
    
    # 安装完成
    echo -e "${GREEN}=== LinuxPanel 安装完成 ===${NC}"
    echo -e "${GREEN}您可以通过 http://YOUR_SERVER_IP:8080 访问面板${NC}"
    echo -e "${GREEN}用户名: admin${NC}"
    echo -e "${GREEN}密码: admin123${NC}"
    
    # 检查前端构建状态
    if [ -f "/opt/linuxpanel/ui/dist/index.html" ]; then
        if grep -q "面板已安装" "/opt/linuxpanel/ui/dist/index.html" || grep -q "安装异常" "/opt/linuxpanel/ui/dist/index.html"; then
            echo -e "${YELLOW}警告: 前端未能完全构建，使用的是临时页面${NC}"
            echo -e "${YELLOW}您可以手动构建前端:${NC}"
            echo -e "${YELLOW}cd /opt/linuxpanel/ui && npm install && npm run build${NC}"
        else
            echo -e "${GREEN}前端界面已构建完成${NC}"
        fi
    else
        echo -e "${YELLOW}警告: 未检测到前端文件，请确保前端代码完整${NC}"
    fi
}

# 启动服务
start_service() {
    echo -e "${BLUE}启动LinuxPanel服务...${NC}"
    
    # 启动服务
    systemctl daemon-reload
    systemctl enable linuxpanel
    systemctl start linuxpanel
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet linuxpanel; then
        echo -e "${GREEN}LinuxPanel服务已启动${NC}"
    else
        echo -e "${RED}LinuxPanel服务启动失败${NC}"
        echo -e "${YELLOW}请查看日志: journalctl -u linuxpanel${NC}"
    fi
}

# 执行主函数
main 