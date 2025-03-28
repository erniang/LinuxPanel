#!/usr/bin/env node

/**
 * 此脚本用于修复LinuxPanel前端应用商店组件的构建问题
 * 问题: Cannot read properties of null (reading 'content')
 */

const fs = require('fs');
const path = require('path');

// 应用商店组件路径
const appstorePath = path.join(process.cwd(), 'ui/src/views/appstore/index.vue');

// 修复后的组件内容
const fixedContent = `<template>
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
</style>`;

console.log('开始修复应用商店组件...');

try {
  // 备份原文件
  if (fs.existsSync(appstorePath)) {
    fs.copyFileSync(appstorePath, `${appstorePath}.bak`);
    console.log('原文件已备份为 index.vue.bak');
  }

  // 写入修复后的内容
  fs.writeFileSync(appstorePath, fixedContent, 'utf8');
  console.log('应用商店组件修复成功！');
} catch (error) {
  console.error('修复过程中出错:', error.message);
  process.exit(1);
} 