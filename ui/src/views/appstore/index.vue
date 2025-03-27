<template>
  <div class="app-store-container">
    <div class="header">
      <div class="title">
        <h2>应用商店</h2>
      </div>
      <div class="search">
        <el-input
          v-model="searchQuery"
          placeholder="搜索应用"
          class="search-input"
          clearable
          @clear="handleClear"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
      </div>
    </div>

    <div class="categories">
      <el-radio-group v-model="activeCategory" @change="handleCategoryChange">
        <el-radio-button label="all">全部</el-radio-button>
        <el-radio-button label="web">Web服务</el-radio-button>
        <el-radio-button label="database">数据库</el-radio-button>
        <el-radio-button label="dev">开发工具</el-radio-button>
        <el-radio-button label="system">系统工具</el-radio-button>
        <el-radio-button label="other">其他</el-radio-button>
      </el-radio-group>
    </div>

    <div class="app-list" v-loading="loading">
      <el-row :gutter="20">
        <el-col :xs="24" :sm="12" :md="8" :lg="6" v-for="app in filteredApps" :key="app.id">
          <el-card class="app-card" shadow="hover">
            <div class="app-icon">
              <el-image :src="app.icon" fit="contain" class="app-image">
                <template #error>
                  <div class="image-placeholder">
                    <el-icon><Picture /></el-icon>
                  </div>
                </template>
              </el-image>
            </div>
            <div class="app-info">
              <h3 class="app-name">{{ app.name }}</h3>
              <div class="app-version">版本: {{ app.version }}</div>
              <div class="app-desc">{{ app.description }}</div>
              <div class="app-meta">
                <span class="app-category">{{ getCategoryName(app.category) }}</span>
                <span class="app-size">{{ formatSize(app.size) }}</span>
              </div>
              <div class="app-rating">
                <el-rate v-model="app.rating" disabled text-color="#ff9900" />
                <span class="download-count">{{ app.downloads }}次下载</span>
              </div>
            </div>
            <div class="app-actions">
              <el-button 
                v-if="app.installed" 
                type="danger" 
                @click="uninstallApp(app)"
                :loading="app.loading"
              >卸载</el-button>
              <template v-else>
                <el-button 
                  type="primary" 
                  @click="installApp(app)"
                  :loading="app.loading"
                >安装</el-button>
                <el-button 
                  @click="showAppDetail(app)"
                >详情</el-button>
              </template>
            </div>
          </el-card>
        </el-col>
      </el-row>

      <div class="empty-result" v-if="filteredApps.length === 0 && !loading">
        <el-empty description="没有找到相关应用" />
      </div>
    </div>

    <!-- 应用详情对话框 -->
    <el-dialog v-model="appDetailVisible" :title="currentApp.name" width="600px" destroy-on-close>
      <div class="app-detail" v-if="currentApp.id">
        <div class="app-detail-header">
          <div class="app-detail-icon">
            <el-image :src="currentApp.icon" fit="contain" class="detail-image">
              <template #error>
                <div class="image-placeholder">
                  <el-icon><Picture /></el-icon>
                </div>
              </template>
            </el-image>
          </div>
          <div class="app-detail-info">
            <h2>{{ currentApp.name }} <span class="version">v{{ currentApp.version }}</span></h2>
            <div class="app-detail-meta">
              <span class="category">{{ getCategoryName(currentApp.category) }}</span>
              <span class="size">{{ formatSize(currentApp.size) }}</span>
              <span class="downloads">{{ currentApp.downloads }}次下载</span>
            </div>
            <div class="app-detail-rating">
              <el-rate v-model="currentApp.rating" disabled text-color="#ff9900" />
              <span>{{ currentApp.rating.toFixed(1) }}分</span>
            </div>
          </div>
        </div>

        <div class="app-detail-body">
          <el-tabs>
            <el-tab-pane label="应用介绍">
              <div class="app-description">
                {{ currentApp.fullDescription || currentApp.description }}
              </div>
              <div class="app-screenshots" v-if="currentApp.screenshots && currentApp.screenshots.length > 0">
                <h4>应用截图</h4>
                <el-carousel :interval="4000" type="card" height="200px">
                  <el-carousel-item v-for="(screenshot, index) in currentApp.screenshots" :key="index">
                    <el-image :src="screenshot" fit="cover" class="screenshot-image" />
                  </el-carousel-item>
                </el-carousel>
              </div>
            </el-tab-pane>
            <el-tab-pane label="版本历史">
              <div class="version-history">
                <el-timeline>
                  <el-timeline-item
                    v-for="(version, index) in currentApp.versionHistory"
                    :key="index"
                    :timestamp="version.date"
                    :type="index === 0 ? 'primary' : ''"
                  >
                    <h4>{{ version.version }}</h4>
                    <p v-for="(change, changeIndex) in version.changes" :key="changeIndex">
                      {{ change }}
                    </p>
                  </el-timeline-item>
                </el-timeline>
              </div>
            </el-tab-pane>
            <el-tab-pane label="用户评价">
              <div class="user-reviews">
                <div v-if="currentApp.reviews && currentApp.reviews.length > 0">
                  <div class="review-item" v-for="(review, index) in currentApp.reviews" :key="index">
                    <div class="review-header">
                      <span class="reviewer">{{ review.user }}</span>
                      <el-rate v-model="review.rating" disabled text-color="#ff9900" />
                      <span class="review-date">{{ review.date }}</span>
                    </div>
                    <div class="review-content">
                      {{ review.content }}
                    </div>
                  </div>
                </div>
                <el-empty v-else description="暂无评价" />
              </div>
            </el-tab-pane>
          </el-tabs>
        </div>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="appDetailVisible = false">关闭</el-button>
          <el-button 
            v-if="currentApp.installed" 
            type="danger" 
            @click="uninstallApp(currentApp)"
            :loading="currentApp.loading"
          >卸载</el-button>
          <el-button 
            v-else 
            type="primary" 
            @click="installApp(currentApp)"
            :loading="currentApp.loading"
          >安装</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 安装进度对话框 -->
    <el-dialog v-model="installProgressVisible" title="应用安装" width="500px" :close-on-click-modal="false" :show-close="false">
      <div class="install-progress">
        <div class="progress-status">
          <p>正在安装: {{ installApp.name }}</p>
          <p>{{ installStatus }}</p>
        </div>
        <el-progress :percentage="installPercentage" :status="installPercentage === 100 ? 'success' : ''" />
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button :disabled="installPercentage < 100" @click="installProgressVisible = false">关闭</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Picture } from '@element-plus/icons-vue'
import request from '@/utils/request'

// 状态定义
const loading = ref(true)
const appList = ref([])
const searchQuery = ref('')
const activeCategory = ref('all')
const appDetailVisible = ref(false)
const installProgressVisible = ref(false)
const currentApp = ref({})
const installApp = ref({})
const installPercentage = ref(0)
const installStatus = ref('')

// 计算属性
const filteredApps = computed(() => {
  let result = appList.value

  // 分类过滤
  if (activeCategory.value !== 'all') {
    result = result.filter(app => app.category === activeCategory.value)
  }

  // 搜索过滤
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    result = result.filter(app => 
      app.name.toLowerCase().includes(query) || 
      app.description.toLowerCase().includes(query) ||
      app.tags?.some(tag => tag.toLowerCase().includes(query))
    )
  }

  return result
})

// 生命周期钩子
onMounted(() => {
  getApps()
})

// 方法定义
const getApps = async () => {
  loading.value = true
  try {
    const response = await request({
      url: '/appstore/list',
      method: 'get'
    })
    appList.value = response.data.map(app => ({
      ...app,
      loading: false
    }))
    loading.value = false
  } catch (error) {
    ElMessage.error('获取应用列表失败')
    loading.value = false
  }
}

const formatSize = (size) => {
  if (size < 1024) {
    return size + ' B'
  } else if (size < 1024 * 1024) {
    return (size / 1024).toFixed(2) + ' KB'
  } else if (size < 1024 * 1024 * 1024) {
    return (size / (1024 * 1024)).toFixed(2) + ' MB'
  } else {
    return (size / (1024 * 1024 * 1024)).toFixed(2) + ' GB'
  }
}

const getCategoryName = (category) => {
  const categoryMap = {
    web: 'Web服务',
    database: '数据库',
    dev: '开发工具',
    system: '系统工具',
    other: '其他'
  }
  return categoryMap[category] || '未分类'
}

const handleCategoryChange = () => {
  // 可以在这里添加额外的逻辑处理
}

const handleClear = () => {
  searchQuery.value = ''
}

const installApp = async (app) => {
  try {
    ElMessageBox.confirm(
      `确定要安装 ${app.name} 吗？`,
      '安装确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'info'
      }
    ).then(async () => {
      app.loading = true
      installApp.value = app
      installProgressVisible.value = true
      installPercentage.value = 0
      installStatus.value = '正在下载...'
      
      // 模拟安装进度
      simulateInstallProgress()
      
      try {
        await request({
          url: '/appstore/install',
          method: 'post',
          data: {
            id: app.id
          }
        })
        
        // 更新应用状态
        app.installed = true
        app.loading = false
        installStatus.value = '安装完成！'
        installPercentage.value = 100
        
        // 关闭详情对话框
        appDetailVisible.value = false
        
        ElMessage.success(`${app.name} 安装成功`)
      } catch (error) {
        app.loading = false
        installStatus.value = '安装失败！'
        installPercentage.value = 0
        ElMessage.error(`${app.name} 安装失败: ${error.message || '未知错误'}`)
      }
    }).catch(() => {
      // 用户取消安装
    })
  } catch (error) {
    ElMessage.error('操作失败')
  }
}

const uninstallApp = async (app) => {
  try {
    ElMessageBox.confirm(
      `确定要卸载 ${app.name} 吗？卸载将清除所有相关数据。`,
      '卸载确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    ).then(async () => {
      app.loading = true
      
      try {
        await request({
          url: '/appstore/uninstall',
          method: 'post',
          data: {
            id: app.id
          }
        })
        
        // 更新应用状态
        app.installed = false
        app.loading = false
        
        // 关闭详情对话框
        appDetailVisible.value = false
        
        ElMessage.success(`${app.name} 卸载成功`)
      } catch (error) {
        app.loading = false
        ElMessage.error(`${app.name} 卸载失败: ${error.message || '未知错误'}`)
      }
    }).catch(() => {
      // 用户取消卸载
    })
  } catch (error) {
    ElMessage.error('操作失败')
  }
}

const showAppDetail = async (app) => {
  try {
    loading.value = true
    
    // 获取应用详情
    const response = await request({
      url: `/appstore/detail/${app.id}`,
      method: 'get'
    })
    
    currentApp.value = { ...response.data, loading: app.loading, installed: app.installed }
    appDetailVisible.value = true
    loading.value = false
  } catch (error) {
    loading.value = false
    ElMessage.error('获取应用详情失败')
  }
}

// 模拟安装进度
const simulateInstallProgress = () => {
  let progress = 0
  const interval = setInterval(() => {
    progress += Math.floor(Math.random() * 10)
    if (progress >= 100) {
      progress = 99 // 停在99%，等待后端实际完成
      clearInterval(interval)
      installStatus.value = '正在完成安装...'
    } else if (progress >= 80) {
      installStatus.value = '正在配置中...'
    } else if (progress >= 50) {
      installStatus.value = '正在解压安装包...'
    } else if (progress >= 30) {
      installStatus.value = '下载完成，准备安装...'
    }
    installPercentage.value = progress
  }, 300)
}
</script>

<style scoped>
.app-store-container {
  padding: 20px;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.search {
  width: 300px;
}

.categories {
  margin-bottom: 20px;
}

.app-list {
  flex: 1;
  overflow: auto;
  margin-top: 20px;
}

.app-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  margin-bottom: 20px;
  transition: transform 0.3s;
}

.app-card:hover {
  transform: translateY(-5px);
}

.app-icon {
  text-align: center;
  margin-bottom: 15px;
}

.app-image {
  width: 80px;
  height: 80px;
}

.image-placeholder {
  width: 80px;
  height: 80px;
  display: flex;
  justify-content: center;
  align-items: center;
  background-color: #f5f7fa;
  font-size: 24px;
  color: #909399;
}

.app-info {
  flex: 1;
}

.app-name {
  margin-top: 0;
  margin-bottom: 5px;
  font-size: 16px;
  font-weight: bold;
}

.app-version {
  font-size: 12px;
  color: #909399;
  margin-bottom: 10px;
}

.app-desc {
  font-size: 14px;
  color: #606266;
  margin-bottom: 15px;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.app-meta {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #909399;
  margin-bottom: 10px;
}

.app-rating {
  display: flex;
  align-items: center;
  margin-bottom: 15px;
}

.download-count {
  margin-left: 10px;
  font-size: 12px;
  color: #909399;
}

.app-actions {
  display: flex;
  justify-content: space-between;
  margin-top: auto;
}

.empty-result {
  padding: 40px 0;
}

/* 详情样式 */
.app-detail-header {
  display: flex;
  margin-bottom: 20px;
}

.app-detail-icon {
  margin-right: 20px;
}

.detail-image {
  width: 100px;
  height: 100px;
}

.app-detail-info {
  flex: 1;
}

.app-detail-info h2 {
  margin-top: 0;
  margin-bottom: 10px;
}

.version {
  font-size: 14px;
  font-weight: normal;
  color: #909399;
}

.app-detail-meta {
  display: flex;
  gap: 15px;
  font-size: 14px;
  color: #606266;
  margin-bottom: 10px;
}

.app-detail-rating {
  display: flex;
  align-items: center;
}

.app-detail-rating span {
  margin-left: 10px;
}

.app-description {
  margin-bottom: 20px;
  line-height: 1.6;
}

.app-screenshots {
  margin-top: 20px;
}

.screenshot-image {
  width: 100%;
  height: 100%;
}

.version-history {
  padding: 10px 0;
}

.review-item {
  margin-bottom: 15px;
  padding-bottom: 15px;
  border-bottom: 1px solid #ebeef5;
}

.review-header {
  display: flex;
  align-items: center;
  margin-bottom: 5px;
}

.reviewer {
  font-weight: bold;
  margin-right: 10px;
}

.review-date {
  margin-left: 10px;
  font-size: 12px;
  color: #909399;
}

.review-content {
  line-height: 1.5;
}

.install-progress {
  padding: 10px 0;
}

.progress-status {
  margin-bottom: 20px;
}
</style> 