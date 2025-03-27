import axios from 'axios'

const http = axios.create({
  baseURL: '/api/v1',
  timeout: 15000
})

// 用户登录
export function login(data) {
  return http({
    url: '/public/login',
    method: 'post',
    data
  })
}

// 用户登出
export function logout() {
  return http({
    url: '/user/logout',
    method: 'post'
  })
}

// 获取用户信息
export function getUserInfo() {
  return http({
    url: '/user/info',
    method: 'get'
  })
}

// 修改密码
export function changePassword(data) {
  return http({
    url: '/user/change-password',
    method: 'post',
    data
  })
}

// 获取用户列表 (管理员)
export function getUserList() {
  return http({
    url: '/users/list',
    method: 'get'
  })
}

// 创建用户 (管理员)
export function createUser(data) {
  return http({
    url: '/users/create',
    method: 'post',
    data
  })
}

// 更新用户 (管理员)
export function updateUser(data) {
  return http({
    url: '/users/update',
    method: 'post',
    data
  })
}

// 删除用户 (管理员)
export function deleteUser(id) {
  return http({
    url: '/users/delete',
    method: 'post',
    data: { id }
  })
} 