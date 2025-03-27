import axios from 'axios'

const http = axios.create({
  baseURL: '/api/v1',
  timeout: 15000
})

// 获取系统信息
export function getSystemInfo() {
  return http({
    url: '/system/info',
    method: 'get'
  })
}

// 获取系统状态
export function getSystemStatus() {
  return http({
    url: '/system/status',
    method: 'get'
  })
}

// 重启系统 (管理员)
export function rebootSystem() {
  return http({
    url: '/system/admin/reboot',
    method: 'post'
  })
} 