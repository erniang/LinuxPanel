#!/bin/bash

# 轻量级Linux面板一键安装脚本
# 作者: LinuxPanel开发团队
# 版本: 1.0.0

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

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}开始安装依赖...${NC}"
    
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
    apt-get install -y curl wget git build-essential
    
    # 安装Node.js
    echo -e "${BLUE}正在安装Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash - || {
        echo -e "${YELLOW}Node.js源添加失败，使用系统默认版本${NC}"
    }
    apt-get install -y nodejs
    
    # 安装MySQL或MariaDB (如果MySQL不可用，则使用MariaDB)
    echo -e "${BLUE}正在安装数据库...${NC}"
    if apt-cache show mysql-server &>/dev/null; then
        apt-get install -y mysql-server
        systemctl enable mysql.service
        systemctl start mysql.service
    else
        echo -e "${YELLOW}MySQL不可用，安装MariaDB作为替代${NC}"
        apt-get install -y mariadb-server
        systemctl enable mariadb.service
        systemctl start mariadb.service
    fi
    
    # 安装Nginx
    echo -e "${BLUE}正在安装Nginx...${NC}"
    apt-get install -y nginx
    systemctl enable nginx.service
    systemctl start nginx.service
    
    # 安装或升级Go
    echo -e "${BLUE}正在检查Go环境...${NC}"
    GO_VERSION=$(go version 2>/dev/null | grep -oP 'go\K[0-9.]+' || echo "0")
    if [[ "$(printf '%s\n' "1.15" "$GO_VERSION" | sort -V | head -n1)" != "1.15" ]]; then
        echo -e "${YELLOW}Go版本 $GO_VERSION 不满足要求，正在安装Go 1.15...${NC}"
        # 下载并安装Go 1.15
        wget https://dl.google.com/go/go1.15.15.linux-amd64.tar.gz -O /tmp/go1.15.15.linux-amd64.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go1.15.15.linux-amd64.tar.gz
        if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" /root/.bashrc; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
        fi
        export PATH=$PATH:/usr/local/go/bin
        rm -f /tmp/go1.15.15.linux-amd64.tar.gz
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

# 解决循环导入问题
fix_import_cycle() {
    echo -e "${BLUE}修复代码问题...${NC}"
    
    # 降低Go版本要求
    cd /opt/linuxpanel
    sed -i 's/go 1.21/go 1.15/' go.mod
    
    # 修改依赖版本
    sed -i 's/github.com\/gin-gonic\/gin v1.9.1/github.com\/gin-gonic\/gin v1.7.7/' go.mod
    sed -i 's/github.com\/mattn\/go-sqlite3 v1.14.22/github.com\/mattn\/go-sqlite3 v1.14.8/' go.mod
    sed -i 's/github.com\/shirou\/gopsutil\/v3 v3.24.1/github.com\/shirou\/gopsutil\/v3 v3.21.12/' go.mod
    sed -i 's/golang.org\/x\/crypto v0.9.0/golang.org\/x\/crypto v0.0.0-20210711020723-a769d52b0f97/' go.mod
    sed -i 's/gopkg.in\/yaml.v3 v3.0.1/gopkg.in\/yaml.v3 v3.0.0-20210107192922-496545a6307b/' go.mod
    
    # 创建pkg/types目录并移动共享类型
    mkdir -p /opt/linuxpanel/pkg/types
    
    # 创建common包并移动共享代码
    mkdir -p /opt/linuxpanel/pkg/common
    
    # 在pkg/common中创建middleware.go文件
    cat > /opt/linuxpanel/pkg/common/middleware.go <<EOL
package common

import (
	"net/http"
	"strings"
	
	"github.com/gin-gonic/gin"
	"github.com/erniang/LinuxPanel/pkg/auth"
)

// AuthMiddleware 认证中间件，验证用户是否登录
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		
		// 从Authorization头中获取token
		if token == "" {
			// 也可以从cookie中获取
			tokenCookie, _ := c.Cookie("token")
			token = tokenCookie
		}
		
		// 移除Bearer前缀（如果有）
		token = strings.TrimPrefix(token, "Bearer ")
		
		// 验证token
		if token == "" {
			c.JSON(http.StatusOK, gin.H{
				"code": 401,
				"msg":  "未授权，请先登录",
			})
			c.Abort()
			return
		}
		
		// 获取用户信息并存储到上下文
		user := auth.GetUserFromToken(token)
		c.Set("user", user)
		
		c.Next()
	}
}

// AdminOnly 仅管理员可访问
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusOK, gin.H{
				"code": 401,
				"msg":  "未授权，请先登录",
			})
			c.Abort()
			return
		}
		
		// 转换为用户类型
		u, ok := user.(*auth.User)
		if !ok || u.Role != auth.RoleAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code": 403,
				"msg":  "权限不足，需要管理员权限",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// OperatorOnly 仅运维或管理员可访问
func OperatorOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusOK, gin.H{
				"code": 401,
				"msg":  "未授权，请先登录",
			})
			c.Abort()
			return
		}
		
		// 转换为用户类型
		u, ok := user.(*auth.User)
		if !ok || (u.Role != auth.RoleAdmin && u.Role != auth.RoleOperator) {
			c.JSON(http.StatusOK, gin.H{
				"code": 403,
				"msg":  "权限不足，需要运维或管理员权限",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}
EOL

    # 在pkg/common中创建types.go文件
    cat > /opt/linuxpanel/pkg/common/types.go <<EOL
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

    # 创建数据库类型文件
    cat > /opt/linuxpanel/pkg/types/database.go <<EOL
package types

import (
    "time"
)

// Database 数据库类型
type Database struct {
    Name      string    \`json:"name"\`
    Charset   string    \`json:"charset"\`
    Collation string    \`json:"collation"\`
    Size      int64     \`json:"size"\`
    Tables    int       \`json:"tables"\`
    CreatedAt time.Time \`json:"created_at"\`
}

// DBUser 数据库用户
type DBUser struct {
    Username   string   \`json:"username"\`
    Host       string   \`json:"host"\`
    Databases  []string \`json:"databases"\`
    Privileges []string \`json:"privileges"\`
}
EOL

    # 修改pkg/api/middleware.go文件
    cat > /opt/linuxpanel/pkg/api/middleware.go <<EOL
// 这个文件不再使用，转而使用common包中的中间件
package api

// 中间件相关功能已移至common包
EOL

    # 替换import路径
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/api\.AuthMiddleware/common\.AuthMiddleware/g' {} \;
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/api\.AdminOnly/common\.AdminOnly/g' {} \;
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/api\.OperatorOnly/common\.OperatorOnly/g' {} \;
    
    # 替换系统类型引用
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/SystemInfo{/common.SystemInfo{/g' {} \;
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/SystemStatus{/common.SystemStatus{/g' {} \;
    
    # 更新导入语句
    find /opt/linuxpanel -type f -name "*.go" -exec grep -l "github.com/erniang/LinuxPanel/pkg/api" {} \; | xargs -I{} sed -i 's/import (/import (\n\t"github.com\/erniang\/LinuxPanel\/pkg\/common"/g' {}
    
    # 更新pkg/api/v1目录中的文件，使用common包
    find /opt/linuxpanel/pkg/api/v1 -type f -name "*.go" -exec sed -i 's/"github.com\/erniang\/LinuxPanel\/pkg\/api"/"github.com\/erniang\/LinuxPanel\/pkg\/common"/g' {} \;
    
    echo -e "${GREEN}代码问题修复完成${NC}"
}

# 编译后端
build_backend() {
    echo -e "${BLUE}开始编译后端...${NC}"
    
    cd /opt/linuxpanel
    
    # 设置代理
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
    
    # 安装依赖
    npm install
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}前端依赖安装失败${NC}"
        exit 1
    fi
    
    # 创建环境配置
    cat > .env.production <<EOL
VITE_APP_BASE_API=http://localhost:8080/api
EOL
    
    # 构建
    npm run build
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}前端构建失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}前端构建完成${NC}"
}

# 配置Nginx
configure_nginx() {
    echo -e "${BLUE}配置Nginx...${NC}"
    
    # 创建Nginx配置
    cat > /etc/nginx/conf.d/linuxpanel.conf <<EOL
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
EOL
    
    # 测试并重启Nginx
    nginx -t
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Nginx配置测试失败${NC}"
        exit 1
    fi
    
    # 重启Nginx
    systemctl restart nginx
    
    echo -e "${GREEN}Nginx配置完成${NC}"
}

# 创建配置文件
create_config() {
    echo -e "${BLUE}创建配置文件...${NC}"
    
    # 创建主配置文件
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

# 设置防火墙
configure_firewall() {
    echo -e "${BLUE}配置防火墙...${NC}"
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian
        ufw allow ssh
        ufw allow http
        ufw allow https
        
        # 如果防火墙未启用
        if ! ufw status | grep -q "Status: active"; then
            echo "y" | ufw enable
        fi
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
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
    echo -e "${BLUE}访问地址: http://$SERVER_IP${NC}"
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
}

# 主函数
main() {
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}       轻量级Linux面板一键安装脚本 v1.0.0            ${NC}"
    echo -e "${GREEN}====================================================${NC}"
    
    check_root
    check_os
    install_dependencies
    create_directories
    get_code
    fix_import_cycle
    build_backend
    build_frontend
    configure_nginx
    create_config
    create_service
    configure_firewall
    finish_install
}

# 执行主函数
main 