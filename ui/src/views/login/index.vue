<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <div class="logo">
          <img src="../../assets/logo.png" alt="Logo" />
          <span>轻量Linux面板</span>
        </div>
        <div class="slogan">安全、高效、易用的服务器面板</div>
      </div>
      
      <el-form 
        ref="loginFormRef" 
        :model="loginForm" 
        :rules="loginRules" 
        class="login-form"
      >
        <el-form-item prop="username">
          <el-input 
            v-model="loginForm.username" 
            placeholder="用户名" 
            size="large"
            prefix-icon="User"
          />
        </el-form-item>
        
        <el-form-item prop="password">
          <el-input 
            v-model="loginForm.password" 
            placeholder="密码" 
            type="password" 
            show-password
            size="large"
            prefix-icon="Lock"
            @keyup.enter="handleLogin"
          />
        </el-form-item>
        
        <el-form-item>
          <el-checkbox v-model="loginForm.remember">记住我</el-checkbox>
        </el-form-item>
        
        <el-form-item>
          <el-button 
            type="primary" 
            :loading="loading" 
            class="login-button" 
            @click="handleLogin"
          >
            登录
          </el-button>
        </el-form-item>
      </el-form>
      
      <div class="login-footer">
        <p>© 2023 轻量Linux面板 - 保护服务器安全</p>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '../../store/user'
import { ElMessage } from 'element-plus'

export default {
  name: 'Login',
  setup() {
    const router = useRouter()
    const userStore = useUserStore()
    
    // 登录表单
    const loginFormRef = ref(null)
    const loading = ref(false)
    
    const loginForm = reactive({
      username: '',
      password: '',
      remember: false
    })
    
    // 表单验证规则
    const loginRules = {
      username: [
        { required: true, message: '请输入用户名', trigger: 'blur' }
      ],
      password: [
        { required: true, message: '请输入密码', trigger: 'blur' }
      ]
    }
    
    // 从本地存储加载用户名
    const initForm = () => {
      const rememberUser = localStorage.getItem('rememberUser')
      if (rememberUser) {
        loginForm.username = rememberUser
        loginForm.remember = true
      }
    }
    
    // 处理登录
    const handleLogin = () => {
      if (!loginFormRef.value) return
      
      loginFormRef.value.validate(async (valid) => {
        if (!valid) return
        
        loading.value = true
        
        try {
          await userStore.login(loginForm.username, loginForm.password)
          
          // 保存用户名到本地
          if (loginForm.remember) {
            localStorage.setItem('rememberUser', loginForm.username)
          } else {
            localStorage.removeItem('rememberUser')
          }
          
          ElMessage.success('登录成功')
          router.push('/')
        } catch (error) {
          console.error('登录失败:', error)
          ElMessage.error(error.message || '登录失败，请检查用户名和密码')
        } finally {
          loading.value = false
        }
      })
    }
    
    // 初始化表单
    initForm()
    
    return {
      loginFormRef,
      loginForm,
      loginRules,
      loading,
      handleLogin
    }
  }
}
</script>

<style lang="scss" scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background-color: #f5f7fa;
  background-image: linear-gradient(45deg, #f5f7fa 0%, #c3cfe2 100%);
}

.login-box {
  width: 400px;
  border-radius: 8px;
  background-color: #fff;
  box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
  padding: 30px;
  box-sizing: border-box;
}

.login-header {
  margin-bottom: 30px;
  text-align: center;
  
  .logo {
    display: flex;
    justify-content: center;
    align-items: center;
    margin-bottom: 10px;
    
    img {
      width: 40px;
      height: 40px;
      margin-right: 10px;
    }
    
    span {
      font-size: 24px;
      font-weight: bold;
      color: #409EFF;
    }
  }
  
  .slogan {
    color: #606266;
    font-size: 14px;
  }
}

.login-form {
  margin: 20px 0;
}

.login-button {
  width: 100%;
  height: 44px;
  font-size: 16px;
  border-radius: 4px;
}

.login-footer {
  text-align: center;
  margin-top: 20px;
  color: #909399;
  font-size: 12px;
}
</style>