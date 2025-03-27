import axios from 'axios'

const http = axios.create({
  baseURL: '/api/v1',
  timeout: 15000
})

// 获取所有网站
export function getWebsiteList() {
  return http({
    url: '/websites/list',
    method: 'get'
  })
}

// 获取网站详情
export function getWebsiteDetail(id) {
  return http({
    url: `/websites/detail/${id}`,
    method: 'get'
  })
}

// 创建网站
export function createWebsite(data) {
  return http({
    url: '/websites/create',
    method: 'post',
    data
  })
}

// 更新网站
export function updateWebsite(data) {
  return http({
    url: '/websites/update',
    method: 'post',
    data
  })
}

// 删除网站
export function deleteWebsite(id) {
  return http({
    url: '/websites/delete',
    method: 'post',
    data: { id }
  })
}

// 控制网站状态
export function controlWebsite(id, enable) {
  return http({
    url: '/websites/control',
    method: 'post',
    data: { id, enable }
  })
} 