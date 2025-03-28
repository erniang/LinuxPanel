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

# 构建前端界面
build_frontend() {
    echo -e "${BLUE}开始构建前端界面...${NC}"
    
    # 创建前端基本目录
    mkdir -p /opt/linuxpanel/ui/src
    
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

    # 2. 创建主HTML文件
    cat > /opt/linuxpanel/ui/public/index.html <<EOL
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width,initial-scale=1.0">
    <link rel="icon" href="<%= BASE_URL %>favicon.ico">
    <title>LinuxPanel - 轻量级Linux服务器管理面板</title>
</head>
<body>
    <noscript>
        <strong>很抱歉，LinuxPanel需要启用JavaScript才能正常工作。请启用它继续。</strong>
    </noscript>
    <div id="app"></div>
    <!-- built files will be auto injected -->
</body>
</html>
EOL

    # 3. 创建主入口文件
    cat > /opt/linuxpanel/ui/src/main.js <<EOL
import { createApp } from 'vue'
import ElementPlus from 'element-plus'
import 'element-plus/lib/theme-chalk/index.css'
import App from './App.vue'
import router from './router'
import store from './store'
import './styles/global.css'

createApp(App)
    .use(ElementPlus)
    .use(store)
    .use(router)
    .mount('#app')
EOL

    # 4. 创建根组件
    cat > /opt/linuxpanel/ui/src/App.vue <<EOL
<template>
  <router-view />
</template>

<style>
body {
  margin: 0;
  padding: 0;
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
</style>
EOL

    # 5. 创建路由配置
    cat > /opt/linuxpanel/ui/src/router/index.js <<EOL
import { createRouter, createWebHistory } from 'vue-router'
import Login from '../views/Login.vue'
import Layout from '../views/Layout.vue'
import Dashboard from '../views/Dashboard.vue'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: Login
  },
  {
    path: '/',
    component: Layout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: Dashboard
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes
})

// 简单的路由守卫
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  if (to.path !== '/login' && !token) {
    next('/login')
  } else {
    next()
  }
})

export default router
EOL

    # 6. 创建状态管理
    mkdir -p /opt/linuxpanel/ui/src/store
    cat > /opt/linuxpanel/ui/src/store/index.js <<EOL
import { createStore } from 'vuex'

export default createStore({
  state: {
    user: JSON.parse(localStorage.getItem('user')) || null,
    token: localStorage.getItem('token') || '',
    systemInfo: {}
  },
  mutations: {
    SET_USER(state, user) {
      state.user = user
      localStorage.setItem('user', JSON.stringify(user))
    },
    SET_TOKEN(state, token) {
      state.token = token
      localStorage.setItem('token', token)
    },
    SET_SYSTEM_INFO(state, info) {
      state.systemInfo = info
    },
    LOGOUT(state) {
      state.user = null
      state.token = ''
      localStorage.removeItem('user')
      localStorage.removeItem('token')
    }
  },
  actions: {
    login({ commit }, { user, token }) {
      commit('SET_USER', user)
      commit('SET_TOKEN', token)
    },
    logout({ commit }) {
      commit('LOGOUT')
    }
  },
  modules: {
  }
})
EOL

    # 7. 创建登录页
    cat > /opt/linuxpanel/ui/src/views/Login.vue <<EOL
<template>
  <div class="login-container">
    <div class="login-box">
      <div class="logo">
        <h1>LinuxPanel</h1>
        <p>轻量级Linux服务器管理面板</p>
      </div>
      <el-form ref="loginForm" :model="loginForm" :rules="loginRules" class="login-form">
        <el-form-item prop="username">
          <el-input v-model="loginForm.username" placeholder="用户名" prefix-icon="el-icon-user" />
        </el-form-item>
        <el-form-item prop="password">
          <el-input v-model="loginForm.password" type="password" placeholder="密码" prefix-icon="el-icon-lock" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handleLogin" style="width: 100%">登录</el-button>
        </el-form-item>
      </el-form>
      <div class="login-tips">
        默认用户名: admin<br>默认密码: admin123
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Login',
  data() {
    return {
      loginForm: {
        username: '',
        password: ''
      },
      loginRules: {
        username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
        password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
      },
      loading: false
    }
  },
  methods: {
    handleLogin() {
      this.$refs.loginForm.validate(valid => {
        if (valid) {
          this.loading = true
          // 模拟登录请求
          setTimeout(() => {
            if (this.loginForm.username === 'admin' && this.loginForm.password === 'admin123') {
              const user = { name: 'admin', role: 'admin' }
              const token = 'mock-token-12345'
              this.$store.dispatch('login', { user, token })
              this.$router.push('/')
            } else {
              this.$message.error('用户名或密码错误')
            }
            this.loading = false
          }, 1000)
        }
      })
    }
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background: linear-gradient(135deg, #8e9eab, #eef2f3);
}
.login-box {
  width: 360px;
  padding: 30px;
  background: #fff;
  border-radius: 6px;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
}
.logo {
  text-align: center;
  margin-bottom: 30px;
}
.logo h1 {
  margin: 0;
  font-size: 28px;
  color: #409EFF;
}
.logo p {
  margin: 10px 0 0;
  font-size: 14px;
  color: #606266;
}
.login-form {
  margin-bottom: 20px;
}
.login-tips {
  text-align: center;
  font-size: 12px;
  color: #909399;
}
</style>
EOL

    # 8. 创建布局组件
    cat > /opt/linuxpanel/ui/src/views/Layout.vue <<EOL
<template>
  <div class="layout">
    <el-container>
      <el-aside width="200px">
        <div class="sidebar">
          <div class="logo">LinuxPanel</div>
          <el-menu 
            :default-active="activeMenu" 
            class="sidebar-menu"
            background-color="#304156"
            text-color="#bfcbd9"
            active-text-color="#409EFF"
            router
          >
            <el-menu-item index="/dashboard">
              <i class="el-icon-monitor"></i>
              <span>仪表盘</span>
            </el-menu-item>
            <el-menu-item index="/websites">
              <i class="el-icon-s-platform"></i>
              <span>网站管理</span>
            </el-menu-item>
            <el-menu-item index="/databases">
              <i class="el-icon-s-data"></i>
              <span>数据库</span>
            </el-menu-item>
            <el-menu-item index="/files">
              <i class="el-icon-folder"></i>
              <span>文件管理</span>
            </el-menu-item>
            <el-menu-item index="/store">
              <i class="el-icon-shopping-bag-1"></i>
              <span>应用商店</span>
            </el-menu-item>
            <el-menu-item index="/settings">
              <i class="el-icon-setting"></i>
              <span>系统设置</span>
            </el-menu-item>
          </el-menu>
        </div>
      </el-aside>
      <el-container>
        <el-header>
          <div class="header-right">
            <el-dropdown @command="handleCommand">
              <span class="el-dropdown-link">
                管理员 <i class="el-icon-arrow-down"></i>
              </span>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">个人信息</el-dropdown-item>
                  <el-dropdown-item command="password">修改密码</el-dropdown-item>
                  <el-dropdown-item command="logout">退出登录</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
        </el-header>
        <el-main>
          <router-view />
        </el-main>
      </el-container>
    </el-container>
  </div>
</template>

<script>
export default {
  name: 'Layout',
  computed: {
    activeMenu() {
      return this.$route.path
    }
  },
  methods: {
    handleCommand(command) {
      if (command === 'logout') {
        this.$store.dispatch('logout')
        this.$router.push('/login')
      }
    }
  }
}
</script>

<style scoped>
.layout {
  height: 100vh;
}
.el-aside {
  background-color: #304156;
  color: #fff;
  height: 100%;
}
.sidebar {
  height: 100%;
  overflow-y: auto;
}
.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  font-size: 20px;
  font-weight: bold;
  color: #409EFF;
  background-color: #2b3b4e;
}
.sidebar-menu {
  border-right: none;
}
.el-header {
  background-color: #fff;
  color: #333;
  line-height: 60px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
}
.header-right {
  margin-right: 20px;
}
.el-dropdown-link {
  cursor: pointer;
  color: #409EFF;
}
.el-main {
  background-color: #f0f2f5;
  padding: 20px;
  height: calc(100vh - 60px);
  overflow-y: auto;
}
</style>
EOL

    # 9. 创建仪表盘
    cat > /opt/linuxpanel/ui/src/views/Dashboard.vue <<EOL
<template>
  <div class="dashboard">
    <el-row :gutter="20">
      <el-col :span="24">
        <el-card class="welcome-card">
          <h2>欢迎使用LinuxPanel控制面板</h2>
          <p>轻量级的Linux服务器管理面板</p>
        </el-card>
      </el-col>
    </el-row>
    
    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="8">
        <el-card class="metric-card">
          <div class="metric-title">CPU使用率</div>
          <div class="metric-value">{{ systemInfo.cpuUsage || 0 }}%</div>
          <el-progress :percentage="systemInfo.cpuUsage || 0" :color="getStatusColor(systemInfo.cpuUsage || 0)"></el-progress>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="metric-card">
          <div class="metric-title">内存使用率</div>
          <div class="metric-value">{{ systemInfo.memoryUsage || 0 }}%</div>
          <el-progress :percentage="systemInfo.memoryUsage || 0" :color="getStatusColor(systemInfo.memoryUsage || 0)"></el-progress>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="metric-card">
          <div class="metric-title">磁盘使用率</div>
          <div class="metric-value">{{ systemInfo.diskUsage || 0 }}%</div>
          <el-progress :percentage="systemInfo.diskUsage || 0" :color="getStatusColor(systemInfo.diskUsage || 0)"></el-progress>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>系统信息</span>
            </div>
          </template>
          <div class="info-item">
            <span class="info-label">主机名</span>
            <span class="info-value">{{ systemInfo.hostname || '未知' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">操作系统</span>
            <span class="info-value">{{ systemInfo.os || '未知' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">内核版本</span>
            <span class="info-value">{{ systemInfo.kernelVersion || '未知' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">CPU核心数</span>
            <span class="info-value">{{ systemInfo.cpuCores || 0 }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">总内存</span>
            <span class="info-value">{{ formatBytes(systemInfo.memoryTotal) }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">运行时间</span>
            <span class="info-value">{{ formatUptime(systemInfo.uptime) }}</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>面板信息</span>
            </div>
          </template>
          <div class="info-item">
            <span class="info-label">面板版本</span>
            <span class="info-value">{{ systemInfo.panelVersion || '1.0.0' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Go版本</span>
            <span class="info-value">{{ systemInfo.goVersion || '1.21.0' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">已安装模块</span>
            <span class="info-value">核心模块</span>
          </div>
          <div class="info-item">
            <span class="info-label">面板运行时间</span>
            <span class="info-value">{{ formatUptime(systemInfo.panelUptime) || '未知' }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">数据库类型</span>
            <span class="info-value">SQLite</span>
          </div>
          <div class="info-item">
            <span class="info-label">面板端口</span>
            <span class="info-value">8080</span>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script>
export default {
  name: 'Dashboard',
  data() {
    return {
      systemInfo: {
        cpuUsage: 15,
        memoryUsage: 45,
        diskUsage: 35,
        hostname: 'server001',
        os: 'Debian 11',
        kernelVersion: '5.10.0-15-amd64',
        cpuCores: 4,
        memoryTotal: 8589934592, // 8GB in bytes
        uptime: 422400, // 5 days in seconds
        panelVersion: '1.0.0',
        goVersion: '1.21.0',
        panelUptime: 86400 // 1 day in seconds
      }
    }
  },
  mounted() {
    // 这里应该获取真实的系统信息
    this.getSystemInfo()
  },
  methods: {
    getSystemInfo() {
      // 这里应该是真实的API调用
      // fetch('/api/system/info')...
    },
    getStatusColor(value) {
      if (value < 60) return '#67C23A' // 绿色
      if (value < 80) return '#E6A23C' // 黄色
      return '#F56C6C' // 红色
    },
    formatBytes(bytes) {
      if (!bytes) return '0 B'
      const k = 1024
      const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    },
    formatUptime(seconds) {
      if (!seconds) return '未知'
      const days = Math.floor(seconds / 86400)
      const hours = Math.floor((seconds % 86400) / 3600)
      const minutes = Math.floor(((seconds % 86400) % 3600) / 60)
      
      let result = ''
      if (days > 0) result += days + '天 '
      if (hours > 0) result += hours + '小时 '
      if (minutes > 0) result += minutes + '分钟'
      
      return result || '刚刚启动'
    }
  }
}
</script>

<style scoped>
.dashboard {
  padding: 20px;
}
.welcome-card {
  text-align: center;
  padding: 20px;
}
.welcome-card h2 {
  color: #409EFF;
  margin-top: 0;
}
.metric-card {
  text-align: center;
  padding: 20px;
}
.metric-title {
  font-size: 16px;
  margin-bottom: 10px;
  color: #606266;
}
.metric-value {
  font-size: 28px;
  font-weight: bold;
  margin-bottom: 10px;
  color: #303133;
}
.info-card {
  margin-bottom: 20px;
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.info-item {
  display: flex;
  justify-content: space-between;
  padding: 10px 0;
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
EOL

    # 10. 创建全局样式
    cat > /opt/linuxpanel/ui/src/styles/global.css <<EOL
html, body {
  margin: 0;
  padding: 0;
  height: 100%;
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', Arial, sans-serif;
}

.el-card {
  border-radius: 4px;
  border: none;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
}

.el-card__header {
  padding: 15px 20px;
  font-weight: bold;
  border-bottom: 1px solid #EBEEF5;
}

.el-card__body {
  padding: 20px;
}
EOL

    # 创建一个打包好的前端dist目录
    mkdir -p /opt/linuxpanel/ui/dist
    
    # 复制基本HTML到dist目录
    cat > /opt/linuxpanel/ui/dist/index.html <<EOL
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width,initial-scale=1.0">
    <title>LinuxPanel - 轻量级Linux服务器管理面板</title>
    <style>
        html, body {
            margin: 0;
            padding: 0;
            height: 100%;
            font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', Arial, sans-serif;
        }
        #app {
            height: 100%;
        }
        .loading-container {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            height: 100%;
            background-color: #f5f7fa;
        }
        .loading-title {
            font-size: 24px;
            color: #409EFF;
            margin-bottom: 20px;
        }
        .loading-subtitle {
            font-size: 16px;
            color: #606266;
            margin-bottom: 30px;
        }
        .spinner {
            width: 50px;
            height: 50px;
            border: 5px solid #f3f3f3;
            border-top: 5px solid #409EFF;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .login-form {
            width: 350px;
            padding: 30px;
            background-color: #fff;
            border-radius: 5px;
            box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            margin-top: 30px;
        }
        .form-title {
            text-align: center;
            font-size: 20px;
            color: #303133;
            margin-bottom: 25px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-size: 14px;
            color: #606266;
        }
        input {
            width: 100%;
            padding: 10px;
            border: 1px solid #dcdfe6;
            border-radius: 4px;
            box-sizing: border-box;
            font-size: 14px;
            color: #606266;
        }
        input:focus {
            outline: none;
            border-color: #409EFF;
        }
        button {
            width: 100%;
            padding: 12px;
            background-color: #409EFF;
            border: none;
            border-radius: 4px;
            color: white;
            font-size: 14px;
            cursor: pointer;
            transition: background-color 0.3s;
        }
        button:hover {
            background-color: #66b1ff;
        }
        .form-footer {
            text-align: center;
            font-size: 12px;
            color: #909399;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div id="app">
        <div class="loading-container">
            <div class="loading-title">LinuxPanel</div>
            <div class="loading-subtitle">轻量级Linux服务器管理面板</div>
            <div class="login-form">
                <div class="form-title">用户登录</div>
                <div class="form-group">
                    <label for="username">用户名</label>
                    <input type="text" id="username" placeholder="请输入用户名">
                </div>
                <div class="form-group">
                    <label for="password">密码</label>
                    <input type="password" id="password" placeholder="请输入密码">
                </div>
                <button id="login-btn">登录</button>
                <div class="form-footer">
                    默认用户名: admin<br>默认密码: admin123
                </div>
            </div>
        </div>
    </div>
    <script>
        document.getElementById('login-btn').addEventListener('click', function() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            
            if (username === 'admin' && password === 'admin123') {
                alert('登录成功！实际面板正在开发中，这是临时登录页面。');
            } else {
                alert('用户名或密码错误');
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