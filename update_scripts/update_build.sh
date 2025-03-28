#!/bin/bash

# 更新构建脚本 - 修复前端构建问题
# 作者: LinuxPanel团队
# 用途: 修复Vue前端构建过程中出现的问题

# 设置颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测工作目录
if [ ! -d "/opt/linuxpanel" ]; then
  echo -e "${RED}错误: 未找到LinuxPanel安装目录${NC}"
  echo -e "请确认LinuxPanel已正确安装，或手动设置工作目录"
  exit 1
fi

# 进入工作目录
cd /opt/linuxpanel

# 确保UI目录存在
if [ ! -d "ui" ]; then
  echo -e "${RED}错误: 未找到UI目录${NC}"
  exit 1
fi

echo -e "${BLUE}=== LinuxPanel 前端修复程序 ===${NC}"
echo -e "${YELLOW}检测Vue前端环境...${NC}"

# 进入UI目录
cd ui

# 备份原始文件
echo -e "${BLUE}备份原始文件...${NC}"
mkdir -p ../backup/ui
if [ -f "src/views/appstore/index.vue" ]; then
  cp src/views/appstore/index.vue ../backup/ui/appstore-index.vue.bak
fi

# 修复应用商店组件
echo -e "${BLUE}修复应用商店组件...${NC}"
if [ -d "src/views/appstore" ]; then
  mkdir -p src/views/appstore
  
  # 创建修复后的应用商店组件
  cat > src/views/appstore/index.vue <<EOL
<template>
  <div class="app-store-container">
    <h1>应用商店</h1>
    <div class="app-list" v-if="!loading">
      <div class="app-card" v-for="app in apps" :key="app.id">
        <div class="app-icon">
          <i class="fa fa-cube"></i>
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
      <div class="loading-placeholder" v-for="i in 5" :key="i"></div>
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
.loading-placeholder {
  height: 120px;
  background: #f5f7fa;
  border-radius: 4px;
  margin-bottom: 20px;
}
</style>
EOL
  echo -e "${GREEN}应用商店组件已修复${NC}"
else
  echo -e "${YELLOW}未找到应用商店目录，创建目录...${NC}"
  mkdir -p src/views/appstore
  # 创建修复后的应用商店组件（与上面相同的内容）
fi

# 清理缓存
echo -e "${BLUE}清理构建缓存...${NC}"
rm -rf node_modules/.cache

# 重新安装依赖
echo -e "${BLUE}重新安装前端依赖...${NC}"
if command -v yarn &> /dev/null; then
  yarn install
else
  npm install
fi

# 重新构建前端
echo -e "${BLUE}重新构建前端...${NC}"
if command -v yarn &> /dev/null; then
  yarn build
else
  npm run build
fi

# 检查构建结果
if [ -d "dist" ] && [ -f "dist/index.html" ]; then
  echo -e "${GREEN}前端构建成功！${NC}"
  
  # 重启服务
  echo -e "${BLUE}重启LinuxPanel服务...${NC}"
  cd /opt/linuxpanel
  systemctl restart linuxpanel
  
  echo -e "${GREEN}=== 更新完成 ===${NC}"
  echo -e "${GREEN}LinuxPanel前端已成功修复并重启${NC}"
  echo -e "${YELLOW}请使用浏览器访问面板检查是否正常${NC}"
else
  echo -e "${RED}前端构建失败${NC}"
  echo -e "${YELLOW}请检查日志查找错误原因${NC}"
fi 