<template>
  <div class="database-container">
    <div class="header">
      <div class="title">
        <h2>数据库管理</h2>
      </div>
      <div class="actions">
        <el-button type="primary" @click="createDatabase">
          <el-icon><Plus /></el-icon>创建数据库
        </el-button>
        <el-button @click="refreshDatabases">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
      </div>
    </div>

    <div class="database-list">
      <el-tabs v-model="activeTab" class="demo-tabs">
        <el-tab-pane label="数据库列表" name="database">
          <el-table
            :data="databaseList"
            style="width: 100%"
            v-loading="loading"
            highlight-current-row
          >
            <el-table-column prop="name" label="数据库名" sortable />
            <el-table-column prop="charset" label="字符集" width="120" />
            <el-table-column prop="size" label="大小" width="120">
              <template #default="scope">
                {{ formatSize(scope.row.size) }}
              </template>
            </el-table-column>
            <el-table-column prop="tables" label="表数量" width="100" />
            <el-table-column prop="created_at" label="创建时间" width="180">
              <template #default="scope">
                {{ formatDate(scope.row.created_at) }}
              </template>
            </el-table-column>
            <el-table-column label="操作" width="300">
              <template #default="scope">
                <el-button type="primary" size="small" @click="openDatabase(scope.row)">
                  <el-icon><Connection /></el-icon>打开
                </el-button>
                <el-button type="success" size="small" @click="backupDatabase(scope.row)">
                  <el-icon><Download /></el-icon>备份
                </el-button>
                <el-button type="warning" size="small" @click="recoverDatabase(scope.row)">
                  <el-icon><Upload /></el-icon>恢复
                </el-button>
                <el-button type="danger" size="small" @click="deleteDatabase(scope.row)">
                  <el-icon><Delete /></el-icon>删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
        <el-tab-pane label="数据库用户" name="user">
          <div class="user-header">
            <el-button type="primary" @click="createUser">
              <el-icon><Plus /></el-icon>创建用户
            </el-button>
          </div>
          <el-table
            :data="userList"
            style="width: 100%"
            v-loading="userLoading"
            highlight-current-row
          >
            <el-table-column prop="username" label="用户名" sortable />
            <el-table-column prop="host" label="主机" />
            <el-table-column prop="databases" label="可访问数据库">
              <template #default="scope">
                <el-tag v-for="db in scope.row.databases" :key="db" class="mx-1">{{ db }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="200">
              <template #default="scope">
                <el-button type="primary" size="small" @click="editUserPermissions(scope.row)">
                  <el-icon><Setting /></el-icon>权限
                </el-button>
                <el-button type="warning" size="small" @click="changePassword(scope.row)">
                  <el-icon><Key /></el-icon>修改密码
                </el-button>
                <el-button type="danger" size="small" @click="deleteUser(scope.row)">
                  <el-icon><Delete /></el-icon>删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- 创建数据库对话框 -->
    <el-dialog v-model="databaseDialogVisible" title="创建数据库" width="500px">
      <el-form :model="databaseForm" :rules="databaseRules" ref="databaseFormRef" label-width="120px">
        <el-form-item label="数据库名称" prop="name">
          <el-input v-model="databaseForm.name" placeholder="请输入数据库名称"></el-input>
        </el-form-item>
        <el-form-item label="字符集" prop="charset">
          <el-select v-model="databaseForm.charset" placeholder="请选择字符集" style="width: 100%">
            <el-option label="utf8mb4" value="utf8mb4" />
            <el-option label="utf8" value="utf8" />
            <el-option label="latin1" value="latin1" />
          </el-select>
        </el-form-item>
        <el-form-item label="排序规则" prop="collation">
          <el-select v-model="databaseForm.collation" placeholder="请选择排序规则" style="width: 100%">
            <el-option label="utf8mb4_general_ci" value="utf8mb4_general_ci" />
            <el-option label="utf8mb4_unicode_ci" value="utf8mb4_unicode_ci" />
            <el-option label="utf8_general_ci" value="utf8_general_ci" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="databaseDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitCreateDatabase">创建</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 创建用户对话框 -->
    <el-dialog v-model="userDialogVisible" title="创建数据库用户" width="500px">
      <el-form :model="userForm" :rules="userRules" ref="userFormRef" label-width="120px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="userForm.username" placeholder="请输入用户名"></el-input>
        </el-form-item>
        <el-form-item label="主机" prop="host">
          <el-input v-model="userForm.host" placeholder="允许连接的主机 (如: localhost, % 表示任意)"></el-input>
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="userForm.password" type="password" placeholder="请输入密码" show-password></el-input>
        </el-form-item>
        <el-form-item label="确认密码" prop="confirmPassword">
          <el-input v-model="userForm.confirmPassword" type="password" placeholder="请确认密码" show-password></el-input>
        </el-form-item>
        <el-form-item label="授权数据库">
          <el-select v-model="userForm.databases" multiple placeholder="请选择授权的数据库" style="width: 100%">
            <el-option
              v-for="db in databaseList"
              :key="db.name"
              :label="db.name"
              :value="db.name"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="userDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitCreateUser">创建</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 权限管理对话框 -->
    <el-dialog v-model="permissionDialogVisible" title="用户权限管理" width="600px">
      <el-form :model="permissionForm" label-width="120px">
        <el-form-item label="用户名">
          <el-input v-model="permissionForm.username" disabled></el-input>
        </el-form-item>
        <el-form-item label="授权数据库">
          <el-select v-model="permissionForm.databases" multiple placeholder="请选择授权的数据库" style="width: 100%">
            <el-option
              v-for="db in databaseList"
              :key="db.name"
              :label="db.name"
              :value="db.name"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="权限">
          <el-checkbox-group v-model="permissionForm.privileges">
            <el-checkbox label="SELECT">SELECT</el-checkbox>
            <el-checkbox label="INSERT">INSERT</el-checkbox>
            <el-checkbox label="UPDATE">UPDATE</el-checkbox>
            <el-checkbox label="DELETE">DELETE</el-checkbox>
            <el-checkbox label="CREATE">CREATE</el-checkbox>
            <el-checkbox label="DROP">DROP</el-checkbox>
            <el-checkbox label="ALTER">ALTER</el-checkbox>
            <el-checkbox label="INDEX">INDEX</el-checkbox>
            <el-checkbox label="ALL PRIVILEGES">ALL PRIVILEGES</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="permissionDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitUpdatePermissions">保存</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 修改密码对话框 -->
    <el-dialog v-model="passwordDialogVisible" title="修改密码" width="500px">
      <el-form :model="passwordForm" :rules="passwordRules" ref="passwordFormRef" label-width="120px">
        <el-form-item label="用户名">
          <el-input v-model="passwordForm.username" disabled></el-input>
        </el-form-item>
        <el-form-item label="新密码" prop="password">
          <el-input v-model="passwordForm.password" type="password" placeholder="请输入新密码" show-password></el-input>
        </el-form-item>
        <el-form-item label="确认密码" prop="confirmPassword">
          <el-input v-model="passwordForm.confirmPassword" type="password" placeholder="请确认新密码" show-password></el-input>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="passwordDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitChangePassword">保存</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 备份恢复对话框 -->
    <el-dialog v-model="backupDialogVisible" title="数据库备份" width="500px">
      <div v-loading="backupLoading">
        <p>数据库名称: {{ backupForm.name }}</p>
        <p>备份包括表结构和数据。</p>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="backupDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitBackupDatabase" :loading="backupLoading">开始备份</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 恢复数据库对话框 -->
    <el-dialog v-model="recoverDialogVisible" title="恢复数据库" width="500px">
      <div v-loading="recoverLoading">
        <p>数据库名称: {{ recoverForm.name }}</p>
        <el-upload
          class="upload-demo"
          drag
          action=""
          :auto-upload="false"
          :on-change="handleFileChange"
        >
          <el-icon class="el-icon--upload"><upload-filled /></el-icon>
          <div class="el-upload__text">
            将备份文件拖到此处，或<em>点击上传</em>
          </div>
          <template #tip>
            <div class="el-upload__tip">
              支持 .sql 或 .sql.gz 格式的数据库备份文件
            </div>
          </template>
        </el-upload>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="recoverDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitRecoverDatabase" :loading="recoverLoading" :disabled="!recoverForm.file">开始恢复</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useUserStore } from '@/stores/user'
import {
  Plus,
  Refresh,
  Connection,
  Download,
  Upload,
  Delete,
  Setting,
  Key,
  UploadFilled
} from '@element-plus/icons-vue'
import request from '@/utils/request'

// 状态定义
const activeTab = ref('database')
const loading = ref(true)
const userLoading = ref(false)
const databaseList = ref([])
const userList = ref([])
const databaseDialogVisible = ref(false)
const userDialogVisible = ref(false)
const permissionDialogVisible = ref(false)
const passwordDialogVisible = ref(false)
const backupDialogVisible = ref(false)
const recoverDialogVisible = ref(false)
const backupLoading = ref(false)
const recoverLoading = ref(false)
const databaseFormRef = ref(null)
const userFormRef = ref(null)
const passwordFormRef = ref(null)

// 表单数据
const databaseForm = reactive({
  name: '',
  charset: 'utf8mb4',
  collation: 'utf8mb4_general_ci'
})

const userForm = reactive({
  username: '',
  host: 'localhost',
  password: '',
  confirmPassword: '',
  databases: []
})

const permissionForm = reactive({
  username: '',
  host: '',
  databases: [],
  privileges: []
})

const passwordForm = reactive({
  username: '',
  host: '',
  password: '',
  confirmPassword: ''
})

const backupForm = reactive({
  name: '',
  id: null
})

const recoverForm = reactive({
  name: '',
  id: null,
  file: null
})

// 表单验证规则
const databaseRules = {
  name: [
    { required: true, message: '请输入数据库名称', trigger: 'blur' },
    { pattern: /^[a-zA-Z0-9_]+$/, message: '数据库名称只能包含字母、数字和下划线', trigger: 'blur' }
  ],
  charset: [
    { required: true, message: '请选择字符集', trigger: 'change' }
  ],
  collation: [
    { required: true, message: '请选择排序规则', trigger: 'change' }
  ]
}

const userRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { pattern: /^[a-zA-Z0-9_]+$/, message: '用户名只能包含字母、数字和下划线', trigger: 'blur' }
  ],
  host: [
    { required: true, message: '请输入主机', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码长度不能少于6个字符', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value !== userForm.password) {
          callback(new Error('两次输入的密码不一致'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}

const passwordRules = {
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码长度不能少于6个字符', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value !== passwordForm.password) {
          callback(new Error('两次输入的密码不一致'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}

// 生命周期
onMounted(() => {
  getDatabases()
})

// 方法定义
const getDatabases = async () => {
  loading.value = true
  try {
    const response = await request({
      url: '/database/list',
      method: 'get'
    })
    databaseList.value = response.data
    loading.value = false
  } catch (error) {
    ElMessage.error('获取数据库列表失败')
    loading.value = false
  }
}

const getUsers = async () => {
  userLoading.value = true
  try {
    const response = await request({
      url: '/database/user/list',
      method: 'get'
    })
    userList.value = response.data
    userLoading.value = false
  } catch (error) {
    ElMessage.error('获取用户列表失败')
    userLoading.value = false
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

const formatDate = (dateString) => {
  const date = new Date(dateString)
  return date.toLocaleString()
}

const refreshDatabases = () => {
  if (activeTab.value === 'database') {
    getDatabases()
  } else {
    getUsers()
  }
}

const createDatabase = () => {
  databaseForm.name = ''
  databaseForm.charset = 'utf8mb4'
  databaseForm.collation = 'utf8mb4_general_ci'
  databaseDialogVisible.value = true
}

const submitCreateDatabase = async () => {
  if (!databaseFormRef.value) return

  try {
    await databaseFormRef.value.validate()
    
    await request({
      url: '/database/create',
      method: 'post',
      data: databaseForm
    })
    
    ElMessage.success('数据库创建成功')
    databaseDialogVisible.value = false
    getDatabases()
  } catch (error) {
    console.error(error)
    ElMessage.error('数据库创建失败')
  }
}

const createUser = () => {
  userForm.username = ''
  userForm.host = 'localhost'
  userForm.password = ''
  userForm.confirmPassword = ''
  userForm.databases = []
  userDialogVisible.value = true
}

const submitCreateUser = async () => {
  if (!userFormRef.value) return

  try {
    await userFormRef.value.validate()
    
    await request({
      url: '/database/user/create',
      method: 'post',
      data: {
        username: userForm.username,
        host: userForm.host,
        password: userForm.password,
        databases: userForm.databases
      }
    })
    
    ElMessage.success('数据库用户创建成功')
    userDialogVisible.value = false
    getUsers()
  } catch (error) {
    console.error(error)
    ElMessage.error('数据库用户创建失败')
  }
}

const editUserPermissions = (user) => {
  permissionForm.username = user.username
  permissionForm.host = user.host
  permissionForm.databases = user.databases || []
  permissionForm.privileges = user.privileges || []
  permissionDialogVisible.value = true
}

const submitUpdatePermissions = async () => {
  try {
    await request({
      url: '/database/user/permissions',
      method: 'post',
      data: permissionForm
    })
    
    ElMessage.success('权限更新成功')
    permissionDialogVisible.value = false
    getUsers()
  } catch (error) {
    console.error(error)
    ElMessage.error('权限更新失败')
  }
}

const changePassword = (user) => {
  passwordForm.username = user.username
  passwordForm.host = user.host
  passwordForm.password = ''
  passwordForm.confirmPassword = ''
  passwordDialogVisible.value = true
}

const submitChangePassword = async () => {
  if (!passwordFormRef.value) return

  try {
    await passwordFormRef.value.validate()
    
    await request({
      url: '/database/user/password',
      method: 'post',
      data: {
        username: passwordForm.username,
        host: passwordForm.host,
        password: passwordForm.password
      }
    })
    
    ElMessage.success('密码修改成功')
    passwordDialogVisible.value = false
  } catch (error) {
    console.error(error)
    ElMessage.error('密码修改失败')
  }
}

const deleteUser = (user) => {
  ElMessageBox.confirm(
    `确定要删除用户 ${user.username}@${user.host} 吗？`,
    '警告',
    {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    }
  ).then(async () => {
    try {
      await request({
        url: '/database/user/delete',
        method: 'post',
        data: {
          username: user.username,
          host: user.host
        }
      })
      
      ElMessage.success('用户删除成功')
      getUsers()
    } catch (error) {
      ElMessage.error('用户删除失败')
    }
  }).catch(() => {})
}

const openDatabase = (database) => {
  // 可以打开phpMyAdmin等工具，或者实现一个简单的数据库管理界面
  const url = `${import.meta.env.VITE_APP_BASE_API}/database/phpmyadmin?db=${database.name}`
  window.open(url, '_blank')
}

const backupDatabase = (database) => {
  backupForm.name = database.name
  backupForm.id = database.id
  backupDialogVisible.value = true
}

const submitBackupDatabase = async () => {
  backupLoading.value = true
  try {
    const response = await request({
      url: '/database/backup',
      method: 'post',
      data: {
        name: backupForm.name
      },
      responseType: 'blob'
    })
    
    // 下载备份文件
    const blob = new Blob([response.data])
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    link.download = `${backupForm.name}_backup_${new Date().toISOString().slice(0, 10)}.sql.gz`
    link.click()
    URL.revokeObjectURL(link.href)
    
    ElMessage.success('数据库备份成功')
    backupDialogVisible.value = false
    backupLoading.value = false
  } catch (error) {
    console.error(error)
    ElMessage.error('数据库备份失败')
    backupLoading.value = false
  }
}

const recoverDatabase = (database) => {
  recoverForm.name = database.name
  recoverForm.id = database.id
  recoverForm.file = null
  recoverDialogVisible.value = true
}

const handleFileChange = (file) => {
  recoverForm.file = file.raw
}

const submitRecoverDatabase = async () => {
  if (!recoverForm.file) {
    ElMessage.warning('请选择备份文件')
    return
  }
  
  recoverLoading.value = true
  
  const formData = new FormData()
  formData.append('name', recoverForm.name)
  formData.append('file', recoverForm.file)
  
  try {
    await request({
      url: '/database/recover',
      method: 'post',
      data: formData,
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
    
    ElMessage.success('数据库恢复成功')
    recoverDialogVisible.value = false
    getDatabases()
    recoverLoading.value = false
  } catch (error) {
    console.error(error)
    ElMessage.error('数据库恢复失败')
    recoverLoading.value = false
  }
}

const deleteDatabase = (database) => {
  ElMessageBox.confirm(
    `确定要删除数据库 ${database.name} 吗？此操作不可恢复！`,
    '警告',
    {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    }
  ).then(async () => {
    try {
      await request({
        url: '/database/delete',
        method: 'post',
        data: {
          name: database.name
        }
      })
      
      ElMessage.success('数据库删除成功')
      getDatabases()
    } catch (error) {
      ElMessage.error('数据库删除失败')
    }
  }).catch(() => {})
}

// 监听标签页切换
const watchTabChange = () => {
  if (activeTab.value === 'user' && userList.value.length === 0) {
    getUsers()
  }
}
</script>

<style scoped>
.database-container {
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

.database-list {
  flex: 1;
  overflow: auto;
}

.actions {
  display: flex;
  gap: 10px;
}

.user-header {
  margin-bottom: 15px;
}

.el-tag {
  margin-right: 5px;
  margin-bottom: 5px;
}

:deep(.el-checkbox-group) {
  display: flex;
  flex-wrap: wrap;
}

:deep(.el-checkbox) {
  margin-right: 15px;
  margin-bottom: 10px;
}
</style> 