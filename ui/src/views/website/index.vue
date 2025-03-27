<template>
  <div class="website-manager page-container">
    <div class="page-header">
      <h2 class="page-title">网站管理</h2>
      <el-button type="primary" @click="openCreateDialog">
        <el-icon><Plus /></el-icon>
        添加网站
      </el-button>
    </div>
    
    <!-- 网站列表 -->
    <el-card shadow="never" class="website-list">
      <el-table 
        :data="websites" 
        style="width: 100%" 
        v-loading="loading"
        row-key="id"
      >
        <el-table-column label="ID" prop="id" width="80" />
        <el-table-column label="网站名称" prop="name" min-width="120" />
        <el-table-column label="域名" prop="domain" min-width="180" />
        <el-table-column label="路径" prop="path" min-width="180" />
        <el-table-column label="PHP版本" prop="phpVersion" width="120" />
        <el-table-column label="状态" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.status === 1 ? 'success' : 'info'">
              {{ scope.row.status === 1 ? '运行中' : '已停止' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="180">
          <template #default="scope">
            {{ formatDate(scope.row.createTime) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="260">
          <template #default="scope">
            <el-button size="small" @click="viewWebsite(scope.row)">
              设置
            </el-button>
            <el-button 
              size="small" 
              :type="scope.row.status === 1 ? 'danger' : 'success'"
              @click="handleControlWebsite(scope.row)"
            >
              {{ scope.row.status === 1 ? '停止' : '启动' }}
            </el-button>
            <el-popconfirm 
              title="确定要删除此网站吗？" 
              @confirm="handleDeleteWebsite(scope.row.id)"
            >
              <template #reference>
                <el-button size="small" type="danger">
                  删除
                </el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
    
    <!-- 创建网站对话框 -->
    <el-dialog
      v-model="createDialogVisible"
      title="创建网站"
      width="600px"
    >
      <el-form 
        ref="websiteFormRef"
        :model="websiteForm"
        :rules="websiteRules"
        label-width="100px"
      >
        <el-form-item label="网站名称" prop="name">
          <el-input v-model="websiteForm.name" placeholder="请输入网站名称" />
        </el-form-item>
        
        <el-form-item label="域名" prop="domain">
          <el-input v-model="websiteForm.domain" placeholder="请输入域名" />
        </el-form-item>
        
        <el-form-item label="PHP版本" prop="phpVersion">
          <el-select v-model="websiteForm.phpVersion" placeholder="请选择">
            <el-option label="PHP 5.6" value="5.6" />
            <el-option label="PHP 7.3" value="7.3" />
            <el-option label="PHP 7.4" value="7.4" />
            <el-option label="PHP 8.0" value="8.0" />
            <el-option label="PHP 8.1" value="8.1" />
            <el-option label="PHP 8.2" value="8.2" />
          </el-select>
        </el-form-item>
        
        <el-form-item label="SSL设置">
          <el-switch v-model="websiteForm.ssl.enabled" />
        </el-form-item>
        
        <el-form-item v-if="websiteForm.ssl.enabled" label="SSL类型">
          <el-radio-group v-model="websiteForm.ssl.type">
            <el-radio label="self">自签名</el-radio>
            <el-radio label="custom">自定义</el-radio>
            <el-radio label="lets-encrypt">Let's Encrypt</el-radio>
          </el-radio-group>
        </el-form-item>
        
        <template v-if="websiteForm.ssl.enabled && websiteForm.ssl.type === 'custom'">
          <el-form-item label="证书路径">
            <el-input v-model="websiteForm.ssl.certPath" placeholder="请输入证书路径" />
          </el-form-item>
          <el-form-item label="密钥路径">
            <el-input v-model="websiteForm.ssl.keyPath" placeholder="请输入密钥路径" />
          </el-form-item>
        </template>
        
        <el-form-item label="数据库">
          <el-switch v-model="databaseEnabled" />
        </el-form-item>
        
        <template v-if="databaseEnabled">
          <el-form-item label="数据库类型">
            <el-select v-model="websiteForm.database.type">
              <el-option label="MySQL" value="mysql" />
              <el-option label="MariaDB" value="mariadb" />
            </el-select>
          </el-form-item>
          <el-form-item label="数据库名">
            <el-input v-model="websiteForm.database.name" />
          </el-form-item>
          <el-form-item label="用户名">
            <el-input v-model="websiteForm.database.user" />
          </el-form-item>
          <el-form-item label="密码">
            <el-input v-model="websiteForm.database.password" type="password" />
          </el-form-item>
        </template>
        
        <el-form-item label="描述">
          <el-input 
            v-model="websiteForm.description" 
            type="textarea" 
            :rows="2" 
            placeholder="请输入网站描述（可选）"
          />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="createDialogVisible = false">取 消</el-button>
          <el-button 
            type="primary" 
            @click="handleCreateWebsite" 
            :loading="submitting"
          >
            创 建
          </el-button>
        </div>
      </template>
    </el-dialog>
    
    <!-- 网站设置对话框 -->
    <el-dialog
      v-model="settingsDialogVisible"
      :title="`${activeWebsite.name || ''} - 网站设置`"
      width="600px"
    >
      <el-tabs v-model="activeSettingsTab">
        <el-tab-pane label="基本设置" name="basic">
          <el-form :model="websiteEditForm" label-width="100px">
            <el-form-item label="网站名称">
              <el-input v-model="websiteEditForm.name" />
            </el-form-item>
            <el-form-item label="域名">
              <el-input v-model="websiteEditForm.domain" />
            </el-form-item>
            <el-form-item label="PHP版本">
              <el-select v-model="websiteEditForm.phpVersion">
                <el-option label="PHP 5.6" value="5.6" />
                <el-option label="PHP 7.3" value="7.3" />
                <el-option label="PHP 7.4" value="7.4" />
                <el-option label="PHP 8.0" value="8.0" />
                <el-option label="PHP 8.1" value="8.1" />
                <el-option label="PHP 8.2" value="8.2" />
              </el-select>
            </el-form-item>
            <el-form-item label="描述">
              <el-input 
                v-model="websiteEditForm.description" 
                type="textarea" 
                :rows="2" 
              />
            </el-form-item>
          </el-form>
        </el-tab-pane>
        
        <el-tab-pane label="SSL设置" name="ssl">
          <el-form :model="websiteEditForm.ssl" label-width="100px">
            <el-form-item label="启用SSL">
              <el-switch v-model="websiteEditForm.ssl.enabled" />
            </el-form-item>
            
            <template v-if="websiteEditForm.ssl.enabled">
              <el-form-item label="SSL类型">
                <el-radio-group v-model="websiteEditForm.ssl.type">
                  <el-radio label="self">自签名</el-radio>
                  <el-radio label="custom">自定义</el-radio>
                  <el-radio label="lets-encrypt">Let's Encrypt</el-radio>
                </el-radio-group>
              </el-form-item>
              
              <template v-if="websiteEditForm.ssl.type === 'custom'">
                <el-form-item label="证书路径">
                  <el-input v-model="websiteEditForm.ssl.certPath" />
                </el-form-item>
                <el-form-item label="密钥路径">
                  <el-input v-model="websiteEditForm.ssl.keyPath" />
                </el-form-item>
              </template>
            </template>
          </el-form>
        </el-tab-pane>
        
        <el-tab-pane label="数据库" name="database">
          <el-form :model="websiteEditForm.database" label-width="100px">
            <el-form-item v-if="!websiteEditForm.database.name" label="数据库">
              <el-alert
                title="此网站未配置数据库"
                type="info"
                :closable="false"
              />
              <div style="margin-top: 15px;">
                <el-button 
                  type="primary" 
                  @click="websiteEditForm.database = { type: 'mysql', name: '', user: '', password: '' }"
                >
                  添加数据库
                </el-button>
              </div>
            </el-form-item>
            
            <template v-if="websiteEditForm.database.name">
              <el-form-item label="数据库类型">
                <el-select v-model="websiteEditForm.database.type">
                  <el-option label="MySQL" value="mysql" />
                  <el-option label="MariaDB" value="mariadb" />
                </el-select>
              </el-form-item>
              <el-form-item label="数据库名">
                <el-input v-model="websiteEditForm.database.name" disabled />
              </el-form-item>
              <el-form-item label="用户名">
                <el-input v-model="websiteEditForm.database.user" />
              </el-form-item>
              <el-form-item label="密码">
                <el-input v-model="websiteEditForm.database.password" type="password" />
                <div class="form-tip">留空表示不修改密码</div>
              </el-form-item>
            </template>
          </el-form>
        </el-tab-pane>
      </el-tabs>
      
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="settingsDialogVisible = false">取 消</el-button>
          <el-button 
            type="primary" 
            @click="handleUpdateWebsite" 
            :loading="submitting"
          >
            保 存
          </el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import { ref, reactive, onMounted, computed } from 'vue'
import { 
  getWebsiteList, 
  getWebsiteDetail, 
  createWebsite, 
  updateWebsite, 
  deleteWebsite, 
  controlWebsite 
} from '../../api/website'
import { formatDate } from '../../utils/format'
import { ElMessage, ElMessageBox } from 'element-plus'

export default {
  name: 'WebsiteManager',
  setup() {
    // 网站列表
    const websites = ref([])
    const loading = ref(false)
    
    // 创建网站
    const createDialogVisible = ref(false)
    const websiteFormRef = ref(null)
    const submitting = ref(false)
    const databaseEnabled = ref(false)
    
    // 网站表单
    const websiteForm = reactive({
      name: '',
      domain: '',
      phpVersion: '7.4',
      ssl: {
        enabled: false,
        type: 'self',
        certPath: '',
        keyPath: ''
      },
      database: {
        type: 'mysql',
        name: '',
        user: '',
        password: '',
        host: 'localhost',
        port: 3306,
        charset: 'utf8mb4'
      },
      description: ''
    })
    
    // 表单验证规则
    const websiteRules = {
      name: [
        { required: true, message: '请输入网站名称', trigger: 'blur' }
      ],
      domain: [
        { required: true, message: '请输入域名', trigger: 'blur' },
        { 
          pattern: /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$/,
          message: '请输入有效的域名',
          trigger: 'blur'
        }
      ],
      phpVersion: [
        { required: true, message: '请选择PHP版本', trigger: 'change' }
      ]
    }
    
    // 网站设置
    const settingsDialogVisible = ref(false)
    const activeSettingsTab = ref('basic')
    const activeWebsite = ref({})
    
    // 编辑表单
    const websiteEditForm = reactive({
      id: 0,
      name: '',
      domain: '',
      phpVersion: '',
      ssl: {
        enabled: false,
        type: 'self',
        certPath: '',
        keyPath: ''
      },
      database: {
        type: 'mysql',
        name: '',
        user: '',
        password: '',
        host: 'localhost',
        port: 3306,
        charset: 'utf8mb4'
      },
      description: ''
    })
    
    // 打开创建对话框
    const openCreateDialog = () => {
      createDialogVisible.value = true
      databaseEnabled.value = false
      
      // 重置表单
      Object.assign(websiteForm, {
        name: '',
        domain: '',
        phpVersion: '7.4',
        ssl: {
          enabled: false,
          type: 'self',
          certPath: '',
          keyPath: ''
        },
        database: {
          type: 'mysql',
          name: '',
          user: '',
          password: '',
          host: 'localhost',
          port: 3306,
          charset: 'utf8mb4'
        },
        description: ''
      })
      
      if (websiteFormRef.value) {
        websiteFormRef.value.resetFields()
      }
    }
    
    // 创建网站
    const handleCreateWebsite = () => {
      if (!websiteFormRef.value) return
      
      websiteFormRef.value.validate(async (valid) => {
        if (!valid) return
        
        // 如果未启用数据库，则清空数据库信息
        if (!databaseEnabled.value) {
          websiteForm.database = null
        }
        
        submitting.value = true
        
        try {
          const res = await createWebsite(websiteForm)
          ElMessage.success('网站创建成功')
          createDialogVisible.value = false
          fetchWebsites() // 刷新列表
        } catch (error) {
          console.error('创建网站失败:', error)
          ElMessage.error(error.message || '创建网站失败，请稍后重试')
        } finally {
          submitting.value = false
        }
      })
    }
    
    // 获取网站列表
    const fetchWebsites = async () => {
      loading.value = true
      
      try {
        const res = await getWebsiteList()
        websites.value = res.data || []
      } catch (error) {
        console.error('获取网站列表失败:', error)
        ElMessage.error(error.message || '获取网站列表失败')
      } finally {
        loading.value = false
      }
    }
    
    // 查看网站设置
    const viewWebsite = async (website) => {
      try {
        const res = await getWebsiteDetail(website.id)
        activeWebsite.value = res.data
        
        // 复制数据到编辑表单
        Object.assign(websiteEditForm, res.data)
        
        // 打开设置对话框
        settingsDialogVisible.value = true
        activeSettingsTab.value = 'basic'
      } catch (error) {
        console.error('获取网站详情失败:', error)
        ElMessage.error(error.message || '获取网站详情失败')
      }
    }
    
    // 更新网站设置
    const handleUpdateWebsite = async () => {
      submitting.value = true
      
      try {
        await updateWebsite(websiteEditForm)
        ElMessage.success('网站设置已更新')
        settingsDialogVisible.value = false
        fetchWebsites() // 刷新列表
      } catch (error) {
        console.error('更新网站设置失败:', error)
        ElMessage.error(error.message || '更新网站设置失败')
      } finally {
        submitting.value = false
      }
    }
    
    // 控制网站状态
    const handleControlWebsite = async (website) => {
      const enable = website.status !== 1
      const action = enable ? '启动' : '停止'
      
      try {
        ElMessageBox.confirm(`确定要${action}网站 "${website.name}" 吗？`, '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        }).then(async () => {
          loading.value = true
          
          try {
            await controlWebsite(website.id, enable)
            ElMessage.success(`${action}网站成功`)
            fetchWebsites() // 刷新列表
          } catch (error) {
            console.error(`${action}网站失败:`, error)
            ElMessage.error(error.message || `${action}网站失败`)
          } finally {
            loading.value = false
          }
        })
      } catch (error) {
        // 取消操作，不做处理
      }
    }
    
    // 删除网站
    const handleDeleteWebsite = async (id) => {
      loading.value = true
      
      try {
        await deleteWebsite(id)
        ElMessage.success('网站已删除')
        fetchWebsites() // 刷新列表
      } catch (error) {
        console.error('删除网站失败:', error)
        ElMessage.error(error.message || '删除网站失败')
      } finally {
        loading.value = false
      }
    }
    
    // 初始化
    onMounted(() => {
      fetchWebsites()
    })
    
    return {
      websites,
      loading,
      createDialogVisible,
      settingsDialogVisible,
      activeSettingsTab,
      websiteForm,
      websiteRules,
      websiteFormRef,
      websiteEditForm,
      activeWebsite,
      submitting,
      databaseEnabled,
      formatDate,
      openCreateDialog,
      handleCreateWebsite,
      viewWebsite,
      handleUpdateWebsite,
      handleControlWebsite,
      handleDeleteWebsite
    }
  }
}
</script>

<style lang="scss" scoped>
.website-manager {
  .page-title {
    margin-top: 0;
    margin-bottom: 0;
    font-size: 20px;
    font-weight: 600;
  }
  
  .website-list {
    margin-top: 20px;
  }
  
  .form-tip {
    font-size: 12px;
    color: #909399;
    margin-top: 5px;
  }
}
</style> 