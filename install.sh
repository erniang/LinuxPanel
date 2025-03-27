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
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误：请使用root用户运行此脚本${NC}"
        exit 1
    fi
}

# 检测Linux发行版
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}无法检测到操作系统类型${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}检测到操作系统: $OS $VERSION${NC}"
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}开始安装依赖...${NC}"
    
    case $OS in
        "ubuntu"|"debian")
            apt update -y
            apt install -y curl wget git build-essential
            
            # 安装Go
            if ! command -v go &> /dev/null; then
                echo -e "${YELLOW}正在安装Go...${NC}"
                wget https://golang.org/dl/go1.19.linux-amd64.tar.gz
                tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz
                echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
                source /etc/profile.d/go.sh
                rm -f go1.19.linux-amd64.tar.gz
            fi
            
            # 安装Node.js
            if ! command -v node &> /dev/null; then
                echo -e "${YELLOW}正在安装Node.js...${NC}"
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
                apt install -y nodejs
            fi
            
            # 安装MySQL
            if ! command -v mysql &> /dev/null; then
                echo -e "${YELLOW}正在安装MySQL...${NC}"
                apt install -y mysql-server
                systemctl start mysql
                systemctl enable mysql
            fi
            
            # 安装Nginx
            if ! command -v nginx &> /dev/null; then
                echo -e "${YELLOW}正在安装Nginx...${NC}"
                apt install -y nginx
                systemctl start nginx
                systemctl enable nginx
            fi
            ;;
            
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            yum update -y
            yum install -y curl wget git gcc gcc-c++ make
            
            # 安装Go
            if ! command -v go &> /dev/null; then
                echo -e "${YELLOW}正在安装Go...${NC}"
                wget https://golang.org/dl/go1.19.linux-amd64.tar.gz
                tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz
                echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
                source /etc/profile.d/go.sh
                rm -f go1.19.linux-amd64.tar.gz
            fi
            
            # 安装Node.js
            if ! command -v node &> /dev/null; then
                echo -e "${YELLOW}正在安装Node.js...${NC}"
                curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
                yum install -y nodejs
            fi
            
            # 安装MySQL
            if ! command -v mysql &> /dev/null; then
                echo -e "${YELLOW}正在安装MySQL...${NC}"
                yum install -y mysql-server
                systemctl start mysqld
                systemctl enable mysqld
            fi
            
            # 安装Nginx
            if ! command -v nginx &> /dev/null; then
                echo -e "${YELLOW}正在安装Nginx...${NC}"
                yum install -y nginx
                systemctl start nginx
                systemctl enable nginx
            fi
            ;;
            
        *)
            echo -e "${RED}不支持的操作系统: $OS${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}依赖安装完成${NC}"
}

# 创建工作目录
create_directories() {
    echo -e "${BLUE}创建工作目录...${NC}"
    
    # 创建主要目录
    mkdir -p /opt/linuxpanel
    mkdir -p /etc/linuxpanel
    mkdir -p /var/log/linuxpanel
    mkdir -p /var/lib/linuxpanel/data
    mkdir -p /var/lib/linuxpanel/configs
    
    echo -e "${GREEN}工作目录创建完成${NC}"
}

# 获取代码
get_code() {
    echo -e "${BLUE}获取代码...${NC}"
    
    cd /opt/linuxpanel
    
    # 克隆代码仓库
    git clone https://github.com/erniang/LinuxPanel.git .
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}代码获取失败，尝试使用镜像源...${NC}"
        # 备用下载方式
        wget -O linuxpanel.tar.gz https://github.com/erniang/LinuxPanel/archive/refs/heads/main.tar.gz
        tar -xzf linuxpanel.tar.gz
        mv LinuxPanel-main/* .
        rm -rf LinuxPanel-main linuxpanel.tar.gz
    fi
    
    echo -e "${GREEN}代码获取完成${NC}"
}

# 解决循环导入问题
fix_import_cycle() {
    echo -e "${BLUE}修复代码问题...${NC}"
    
    # 创建pkg/types目录并移动共享类型
    mkdir -p /opt/linuxpanel/pkg/types
    
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

    # 修改database.go导入
    cd /opt/linuxpanel
    sed -i 's/type Database struct {/\/\/ 导入共享类型\nimport (\n\t"github.com\/erniang\/LinuxPanel\/pkg\/types"\n)\n\n\/\/ 使用types.Database/g' pkg/api/v1/database.go
    sed -i 's/type DBUser struct {/\/\/ 使用types.DBUser/g' pkg/api/v1/database.go
    
    # 替换其他引用
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/api\.v1\.Database/types.Database/g' {} \;
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/api\.v1\.DBUser/types.DBUser/g' {} \;
    
    # 替换导入路径
    find /opt/linuxpanel -type f -name "*.go" -exec sed -i 's/github.com\/yourusername\/linuxpanel/github.com\/erniang\/LinuxPanel/g' {} \;
    
    echo -e "${GREEN}代码问题修复完成${NC}"
}

# 编译后端
build_backend() {
    echo -e "${BLUE}开始编译后端...${NC}"
    
    cd /opt/linuxpanel
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
  type: "mysql"
  host: "localhost"
  port: 3306
  user: "root"
  password: ""
  name: "linuxpanel"
  
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
EOL
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用并启动服务
    systemctl enable linuxpanel.service
    systemctl start linuxpanel.service
    
    echo -e "${GREEN}系统服务创建完成${NC}"
}

# 初始化数据库
init_database() {
    echo -e "${BLUE}初始化数据库...${NC}"
    
    # 创建数据库和用户
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS linuxpanel DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    mysql -u root -e "CREATE USER IF NOT EXISTS 'linuxpanel'@'localhost' IDENTIFIED BY 'linuxpanel';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON linuxpanel.* TO 'linuxpanel'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"
    
    # 更新配置文件中的数据库密码
    sed -i 's/password: ""/password: "linuxpanel"/g' /etc/linuxpanel/config.yaml
    sed -i 's/user: "root"/user: "linuxpanel"/g' /etc/linuxpanel/config.yaml
    
    echo -e "${GREEN}数据库初始化完成${NC}"
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

# 创建初始管理员账户
create_admin() {
    echo -e "${BLUE}创建初始管理员账户...${NC}"
    
    # 创建admin用户相关目录和文件
    mkdir -p /var/lib/linuxpanel/data/users
    
    # 生成随机盐值
    SALT=$(openssl rand -hex 8)
    
    # 使用MD5+盐值生成密码（在实际应用中应使用更安全的哈希算法）
    PASSWORD_HASH=$(echo -n "admin$SALT" | md5sum | cut -d ' ' -f 1)
    
    # 创建用户配置文件
    cat > /var/lib/linuxpanel/data/users/admin.json <<EOL
{
    "username": "admin",
    "password_hash": "$PASSWORD_HASH",
    "salt": "$SALT",
    "role": "admin",
    "email": "admin@example.com",
    "created_at": "$(date +%s)",
    "last_login": "0"
}
EOL
    
    echo -e "${GREEN}管理员账户创建完成${NC}"
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
    echo -e "${BLUE}默认密码: admin${NC}"
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
    init_database
    create_service
    create_admin
    configure_firewall
    finish_install
}

# 执行主函数
main 