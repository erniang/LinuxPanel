import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import './styles/index.scss'
import axios from 'axios'

// 创建axios实例
const http = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 请求拦截器
http.interceptors.request.use(
  config => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`
    }
    return config
  },
  error => {
    return Promise.reject(error)
  }
)

// 响应拦截器
http.interceptors.response.use(
  response => {
    const res = response.data
    if (res.code !== 0) {
      // 处理业务错误
      if (res.code === 401) {
        // 未授权，清除token并重定向到登录页
        localStorage.removeItem('token')
        router.push('/login')
      }
      return Promise.reject(new Error(res.msg || '未知错误'))
    }
    return res
  },
  error => {
    return Promise.reject(error)
  }
)

const app = createApp(App)

// 注册所有Element Plus图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component)
}

// 全局属性
app.config.globalProperties.$http = http

// 使用插件
app.use(router)
app.use(createPinia())
app.use(ElementPlus, { size: 'default', zIndex: 3000 })

app.mount('#app') 