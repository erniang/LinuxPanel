<template>
  <div class="file-manager-container">
    <div class="header">
      <div class="title">
        <h2>文件管理</h2>
      </div>
      <div class="actions">
        <el-button type="primary" @click="handleUpload">
          <el-icon><Upload /></el-icon>上传文件
        </el-button>
        <el-button @click="createFolder">
          <el-icon><Folder /></el-icon>新建文件夹
        </el-button>
      </div>
    </div>

    <div class="navigation">
      <el-breadcrumb separator="/">
        <el-breadcrumb-item v-for="(item, index) in breadcrumb" :key="index">
          <span 
            class="breadcrumb-item" 
            @click="navigateTo(item.path)">{{ item.name }}</span>
        </el-breadcrumb-item>
      </el-breadcrumb>
    </div>

    <div class="file-list">
      <el-table
        :data="fileList"
        style="width: 100%"
        @row-dblclick="handleRowDblClick"
        v-loading="loading"
        highlight-current-row
      >
        <el-table-column width="60">
          <template #default="scope">
            <el-icon v-if="scope.row.type === 'directory'"><Folder /></el-icon>
            <el-icon v-else><Document /></el-icon>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" sortable />
        <el-table-column prop="size" label="大小" width="120" sortable>
          <template #default="scope">
            {{ scope.row.type === 'directory' ? '-' : formatFileSize(scope.row.size) }}
          </template>
        </el-table-column>
        <el-table-column prop="mod_time" label="修改时间" width="180" sortable>
          <template #default="scope">
            {{ formatDate(scope.row.mod_time) }}
          </template>
        </el-table-column>
        <el-table-column prop="permissions" label="权限" width="120" />
        <el-table-column label="操作" width="240">
          <template #default="scope">
            <el-button 
              v-if="scope.row.type !== 'directory'" 
              type="success" 
              size="small" 
              @click="downloadFile(scope.row)"
            >
              <el-icon><Download /></el-icon>下载
            </el-button>
            <el-button 
              type="primary" 
              size="small" 
              @click="renameFile(scope.row)"
            >
              <el-icon><Edit /></el-icon>重命名
            </el-button>
            <el-button 
              type="danger" 
              size="small" 
              @click="deleteFile(scope.row)"
            >
              <el-icon><Delete /></el-icon>删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 上传文件对话框 -->
    <el-dialog v-model="uploadDialogVisible" title="上传文件" width="500px">
      <el-upload
        class="upload-demo"
        drag
        multiple
        :action="uploadUrl"
        :headers="uploadHeaders"
        :on-success="uploadSuccess"
        :on-error="uploadError"
        :before-upload="beforeUpload"
      >
        <el-icon class="el-icon--upload"><upload-filled /></el-icon>
        <div class="el-upload__text">
          将文件拖到此处，或<em>点击上传</em>
        </div>
        <template #tip>
          <div class="el-upload__tip">
            文件大小不超过100MB
          </div>
        </template>
      </el-upload>
    </el-dialog>

    <!-- 创建文件夹对话框 -->
    <el-dialog v-model="folderDialogVisible" title="新建文件夹" width="400px">
      <el-form :model="folderForm">
        <el-form-item label="文件夹名称">
          <el-input v-model="folderForm.name" placeholder="请输入文件夹名称"></el-input>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="folderDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitCreateFolder">确认</el-button>
        </span>
      </template>
    </el-dialog>

    <!-- 重命名对话框 -->
    <el-dialog v-model="renameDialogVisible" title="重命名" width="400px">
      <el-form :model="renameForm">
        <el-form-item label="新名称">
          <el-input v-model="renameForm.newName" placeholder="请输入新名称"></el-input>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="renameDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitRename">确认</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useUserStore } from '@/stores/user'
import {
  Document,
  Folder,
  Delete,
  Download,
  Upload,
  Edit,
  UploadFilled
} from '@element-plus/icons-vue'
import request from '@/utils/request'

// 状态定义
const fileList = ref([])
const currentPath = ref('/')
const loading = ref(true)
const uploadDialogVisible = ref(false)
const folderDialogVisible = ref(false)
const renameDialogVisible = ref(false)
const breadcrumb = ref([{ name: '根目录', path: '/' }])
const folderForm = reactive({ name: '' })
const renameForm = reactive({ 
  newName: '',
  oldName: '',
  path: '',
  isDirectory: false
})
const userStore = useUserStore()
const uploadUrl = `${import.meta.env.VITE_APP_BASE_API}/file/upload?path=${encodeURIComponent(currentPath.value)}`
const uploadHeaders = {
  Authorization: userStore.token
}

// 生命周期
onMounted(() => {
  getFileList()
})

// 方法定义
const getFileList = async () => {
  loading.value = true
  try {
    const response = await request({
      url: '/file/list',
      method: 'get',
      params: { path: currentPath.value }
    })
    fileList.value = response.data
    loading.value = false
  } catch (error) {
    ElMessage.error('获取文件列表失败')
    loading.value = false
  }
}

const formatFileSize = (size) => {
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

const handleRowDblClick = (row) => {
  if (row.type === 'directory') {
    navigateToFolder(row.name)
  } else {
    // 可选：预览文件
    previewFile(row)
  }
}

const navigateToFolder = (folderName) => {
  let newPath
  if (currentPath.value === '/') {
    newPath = `/${folderName}`
  } else {
    newPath = `${currentPath.value}/${folderName}`
  }
  
  currentPath.value = newPath
  updateBreadcrumb()
  getFileList()
}

const navigateTo = (path) => {
  currentPath.value = path
  updateBreadcrumb()
  getFileList()
}

const updateBreadcrumb = () => {
  const paths = currentPath.value.split('/').filter(Boolean)
  breadcrumb.value = [{ name: '根目录', path: '/' }]
  
  let cumulativePath = ''
  paths.forEach(p => {
    cumulativePath += '/' + p
    breadcrumb.value.push({
      name: p,
      path: cumulativePath
    })
  })
}

const handleUpload = () => {
  uploadDialogVisible.value = true
}

const uploadSuccess = () => {
  ElMessage.success('上传成功')
  uploadDialogVisible.value = false
  getFileList()
}

const uploadError = () => {
  ElMessage.error('上传失败')
}

const beforeUpload = (file) => {
  const isLt100M = file.size / 1024 / 1024 < 100
  if (!isLt100M) {
    ElMessage.error('文件大小不能超过100MB')
  }
  return isLt100M
}

const createFolder = () => {
  folderForm.name = ''
  folderDialogVisible.value = true
}

const submitCreateFolder = async () => {
  if (!folderForm.name) {
    ElMessage.warning('请输入文件夹名称')
    return
  }
  
  try {
    await request({
      url: '/file/mkdir',
      method: 'post',
      data: {
        path: currentPath.value,
        name: folderForm.name
      }
    })
    ElMessage.success('创建文件夹成功')
    folderDialogVisible.value = false
    getFileList()
  } catch (error) {
    ElMessage.error('创建文件夹失败')
  }
}

const renameFile = (file) => {
  renameForm.newName = file.name
  renameForm.oldName = file.name
  renameForm.path = currentPath.value
  renameForm.isDirectory = file.type === 'directory'
  renameDialogVisible.value = true
}

const submitRename = async () => {
  if (!renameForm.newName) {
    ElMessage.warning('请输入新名称')
    return
  }
  
  try {
    await request({
      url: '/file/rename',
      method: 'post',
      data: {
        path: renameForm.path,
        old_name: renameForm.oldName,
        new_name: renameForm.newName,
        is_dir: renameForm.isDirectory
      }
    })
    ElMessage.success('重命名成功')
    renameDialogVisible.value = false
    getFileList()
  } catch (error) {
    ElMessage.error('重命名失败')
  }
}

const deleteFile = (file) => {
  ElMessageBox.confirm(
    `确定要删除 ${file.name} 吗？`,
    '警告',
    {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    }
  ).then(async () => {
    try {
      await request({
        url: '/file/delete',
        method: 'post',
        data: {
          path: currentPath.value + '/' + file.name,
          is_dir: file.type === 'directory'
        }
      })
      ElMessage.success('删除成功')
      getFileList()
    } catch (error) {
      ElMessage.error('删除失败')
    }
  }).catch(() => {})
}

const downloadFile = (file) => {
  const url = `${import.meta.env.VITE_APP_BASE_API}/file/download?path=${encodeURIComponent(currentPath.value + '/' + file.name)}`
  
  const link = document.createElement('a')
  link.href = url
  link.setAttribute('download', file.name)
  link.setAttribute('target', '_blank')
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}

const previewFile = (file) => {
  // 后端实现预览功能，这里只是占位
  // 可以根据文件类型打开不同的预览方式
  const previewUrl = `${import.meta.env.VITE_APP_BASE_API}/file/preview?path=${encodeURIComponent(currentPath.value + '/' + file.name)}`
  window.open(previewUrl, '_blank')
}
</script>

<style scoped>
.file-manager-container {
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

.navigation {
  background-color: #f5f7fa;
  padding: 10px;
  border-radius: 4px;
  margin-bottom: 20px;
}

.breadcrumb-item {
  cursor: pointer;
  color: #409eff;
}

.breadcrumb-item:hover {
  text-decoration: underline;
}

.file-list {
  flex: 1;
  overflow: auto;
}

.upload-demo {
  display: flex;
  justify-content: center;
}

.actions {
  display: flex;
  gap: 10px;
}
</style> 