import { defineStore } from 'pinia'
import { login, logout, getUserInfo } from '../api/user'

export const useUserStore = defineStore('user', {
  state: () => ({
    token: localStorage.getItem('token') || '',
    userInfo: JSON.parse(localStorage.getItem('userInfo') || '{}')
  }),
  
  getters: {
    isLoggedIn: (state) => !!state.token,
    isAdmin: (state) => state.userInfo.role === 'admin',
    isOperator: (state) => state.userInfo.role === 'operator',
    username: (state) => state.userInfo.username || ''
  },
  
  actions: {
    // 登录
    async login(username, password) {
      try {
        const res = await login({ username, password })
        const { token, user } = res.data
        this.token = token
        this.userInfo = user
        
        // 存储到本地
        localStorage.setItem('token', token)
        localStorage.setItem('userInfo', JSON.stringify(user))
        
        return Promise.resolve(res)
      } catch (error) {
        return Promise.reject(error)
      }
    },
    
    // 登出
    async logout() {
      try {
        await logout()
        this.resetState()
        return Promise.resolve()
      } catch (error) {
        return Promise.reject(error)
      }
    },
    
    // 获取用户信息
    async getUserInfo() {
      try {
        const res = await getUserInfo()
        this.userInfo = res.data
        localStorage.setItem('userInfo', JSON.stringify(res.data))
        return Promise.resolve(res)
      } catch (error) {
        return Promise.reject(error)
      }
    },
    
    // 重置状态
    resetState() {
      this.token = ''
      this.userInfo = {}
      localStorage.removeItem('token')
      localStorage.removeItem('userInfo')
    }
  }
}) 