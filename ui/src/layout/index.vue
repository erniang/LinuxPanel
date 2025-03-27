<template>
  <div class="app-wrapper">
    <!-- 侧边栏 -->
    <div class="sidebar-container" :class="{ 'is-collapse': isCollapse }">
      <div class="logo-container">
        <img src="../assets/logo.png" alt="Logo" class="logo" />
        <span v-if="!isCollapse" class="logo-text">轻量Linux面板</span>
      </div>
      
      <el-scrollbar>
        <el-menu 
          :default-active="activeMenu" 
          router 
          background-color="#304156" 
          text-color="#bfcbd9" 
          active-text-color="#409EFF" 
          :collapse="isCollapse"
        >
          <el-menu-item v-for="route in routes" :key="route.path" :index="route.path">
            <el-icon v-if="route.meta && route.meta.icon">
              <component :is="route.meta.icon" />
            </el-icon>
            <template #title>{{ route.meta.title }}</template>
          </el-menu-item>
        </el-menu>
      </el-scrollbar>
    </div>
    
    <!-- 主内容区 -->
    <div class="main-container">
      <!-- 顶部导航栏 -->
      <div class="navbar">
        <div class="navbar-left">
          <el-icon @click="toggleSidebar" style="cursor: pointer; font-size: 20px;">
            <Fold v-if="!isCollapse" />
            <Expand v-else />
          </el-icon>
          <el-breadcrumb separator="/" class="breadcrumb">
            <el-breadcrumb-item :to="{ path: '/dashboard' }">首页</el-breadcrumb-item>
            <el-breadcrumb-item>{{ currentRouteName }}</el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        
        <div class="navbar-right">
          <el-dropdown trigger="click">
            <div class="user-info">
              <el-avatar :size="32" class="user-avatar">
                {{ firstChar }}
              </el-avatar>
              <div class="user-name">{{ username }}</div>
              <el-icon><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item @click="$router.push('/settings')">
                  <el-icon><Setting /></el-icon>
                  <span>个人设置</span>
                </el-dropdown-item>
                <el-dropdown-item @click="handleChangePassword">
                  <el-icon><Key /></el-icon>
                  <span>修改密码</span>
                </el-dropdown-item>
                <el-dropdown-item divided @click="handleLogout">
                  <el-icon><SwitchButton /></el-icon>
                  <span>退出登录</span>
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
      
      <!-- 内容区 -->
      <div class="app-main">
        <router-view v-slot="{ Component }">
          <transition name="fade-transform" mode="out-in">
            <keep-alive>
              <component :is="Component" />
            </keep-alive>
          </transition>
        </router-view>
      </div>
    </div>
    
    <!-- 修改密码对话框 -->
    <el-dialog title="修改密码" v-model="passwordDialogVisible" width="400px">
      <el-form :model="passwordForm" label-width="80px" :rules="passwordRules" ref="passwordFormRef">
        <el-form-item label="旧密码" prop="oldPassword">
          <el-input v-model="passwordForm.oldPassword" type="password" show-password />
        </el-form-item>
        <el-form-item label="新密码" prop="newPassword">
          <el-input v-model="passwordForm.newPassword" type="password" show-password />
        </el-form-item>
        <el-form-item label="确认密码" prop="confirmPassword">
          <el-input v-model="passwordForm.confirmPassword" type="password" show-password />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="passwordDialogVisible = false">取 消</el-button>
          <el-button type="primary" @click="submitChangePassword" :loading="passwordLoading">确 定</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import { computed, ref, reactive, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '../store/user'
import { changePassword } from '../api/user'
import { ElMessage, ElMessageBox } from 'element-plus'

export default {
  name: 'Layout',
  setup() {
    const userStore = useUserStore()
    const route = useRoute()
    const router = useRouter()
    
    // 侧边栏收起状态
    const isCollapse = ref(false)
    
    // 活动菜单
    const activeMenu = computed(() => route.path)
    
    // 当前路由名称
    const currentRouteName = computed(() => {
      return route.meta.title || ''
    })
    
    // 用户名
    const username = computed(() => userStore.username)
    
    // 用户名首字符
    const firstChar = computed(() => {
      return username.value ? username.value.charAt(0).toUpperCase() : 'U'
    })
    
    // 可访问的路由
    const routes = computed(() => {
      return router.options.routes.find(route => route.path === '/').children.filter(route => {
        if (route.meta && route.meta.admin) {
          return userStore.isAdmin
        }
        return true
      })
    })
    
    // 切换侧边栏
    const toggleSidebar = () => {
      isCollapse.value = !isCollapse.value
    }
    
    // 修改密码相关
    const passwordDialogVisible = ref(false)
    const passwordLoading = ref(false)
    const passwordFormRef = ref(null)
    
    const passwordForm = reactive({
      oldPassword: '',
      newPassword: '',
      confirmPassword: ''
    })
    
    const passwordRules = {
      oldPassword: [
        { required: true, message: '请输入旧密码', trigger: 'blur' }
      ],
      newPassword: [
        { required: true, message: '请输入新密码', trigger: 'blur' },
        { min: 6, message: '密码长度不能小于6位', trigger: 'blur' }
      ],
      confirmPassword: [
        { required: true, message: '请再次输入新密码', trigger: 'blur' },
        { 
          validator: (rule, value, callback) => {
            if (value !== passwordForm.newPassword) {
              callback(new Error('两次输入密码不一致'))
            } else {
              callback()
            }
          }, 
          trigger: 'blur' 
        }
      ]
    }
    
    // 打开修改密码对话框
    const handleChangePassword = () => {
      passwordDialogVisible.value = true
      if (passwordFormRef.value) {
        passwordFormRef.value.resetFields()
      }
    }
    
    // 提交修改密码
    const submitChangePassword = async () => {
      if (!passwordFormRef.value) return
      
      try {
        await passwordFormRef.value.validate()
        
        passwordLoading.value = true
        await changePassword({
          old_password: passwordForm.oldPassword,
          new_password: passwordForm.newPassword
        })
        
        ElMessage.success('密码修改成功')
        passwordDialogVisible.value = false
      } catch (error) {
        console.error('修改密码失败:', error)
        if (error.message) {
          ElMessage.error(error.message)
        }
      } finally {
        passwordLoading.value = false
      }
    }
    
    // 登出
    const handleLogout = () => {
      ElMessageBox.confirm('确认退出登录吗?', '提示', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }).then(async () => {
        try {
          await userStore.logout()
          router.push('/login')
          ElMessage.success('退出登录成功')
        } catch (error) {
          console.error('退出登录失败:', error)
        }
      }).catch(() => {})
    }
    
    return {
      isCollapse,
      activeMenu,
      currentRouteName,
      username,
      firstChar,
      routes,
      toggleSidebar,
      passwordDialogVisible,
      passwordLoading,
      passwordForm,
      passwordRules,
      passwordFormRef,
      handleChangePassword,
      submitChangePassword,
      handleLogout
    }
  }
}
</script>

<style lang="scss" scoped>
.app-wrapper {
  position: relative;
  height: 100%;
  width: 100%;
  display: flex;
}

.sidebar-container {
  background-color: #304156;
  width: 210px;
  height: 100%;
  position: fixed;
  top: 0;
  bottom: 0;
  left: 0;
  z-index: 1001;
  transition: width 0.28s;
  overflow: hidden;
  
  &.is-collapse {
    width: 64px;
  }
  
  .logo-container {
    height: 60px;
    padding: 10px 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #263445;
    
    .logo {
      width: 32px;
      height: 32px;
      margin-right: 8px;
    }
    
    .logo-text {
      color: #fff;
      font-size: 18px;
      font-weight: bold;
      white-space: nowrap;
    }
  }
}

.main-container {
  margin-left: 210px;
  min-height: 100%;
  position: relative;
  background-color: #f5f7fa;
  transition: margin-left 0.28s;
  
  .sidebar-container.is-collapse + & {
    margin-left: 64px;
  }
}

.navbar {
  height: 60px;
  overflow: hidden;
  position: relative;
  background: #fff;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px;
  
  .navbar-left {
    display: flex;
    align-items: center;
    
    .breadcrumb {
      margin-left: 20px;
    }
  }
  
  .navbar-right {
    display: flex;
    align-items: center;
  }
  
  .user-info {
    display: flex;
    align-items: center;
    cursor: pointer;
    
    .user-avatar {
      background-color: #409EFF;
      margin-right: 8px;
    }
    
    .user-name {
      font-size: 14px;
      margin-right: 5px;
    }
  }
}

.app-main {
  padding: 20px;
  min-height: calc(100vh - 60px);
}

// 过渡动画
.fade-transform-enter-active,
.fade-transform-leave-active {
  transition: all 0.3s;
}

.fade-transform-enter-from {
  opacity: 0;
  transform: translateX(-30px);
}

.fade-transform-leave-to {
  opacity: 0;
  transform: translateX(30px);
}

// 下拉菜单项图标
:deep(.el-dropdown-menu__item) {
  display: flex;
  align-items: center;
  
  .el-icon {
    margin-right: 8px;
  }
}
</style> 