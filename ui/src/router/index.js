import { createRouter, createWebHistory } from 'vue-router'
import Layout from '@/layout'

export const constantRoutes = [
  {
    path: '/redirect',
    component: Layout,
    hidden: true,
    children: [
      {
        path: '/redirect/:path(.*)',
        component: () => import('@/views/redirect')
      }
    ]
  },
  {
    path: '/login',
    component: () => import('@/views/login/index'),
    hidden: true
  },
  {
    path: '/',
    component: Layout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        component: () => import('@/views/dashboard/index'),
        name: 'Dashboard',
        meta: { title: '控制台', icon: 'dashboard', affix: true }
      }
    ]
  },
  {
    path: '/website',
    component: Layout,
    redirect: '/website/index',
    meta: { title: '网站管理', icon: 'website' },
    children: [
      {
        path: 'index',
        component: () => import('@/views/website/index'),
        name: 'Website',
        meta: { title: '网站管理', icon: 'website' }
      }
    ]
  },
  {
    path: '/filemanager',
    component: Layout,
    redirect: '/filemanager/index',
    meta: { title: '文件管理', icon: 'file' },
    children: [
      {
        path: 'index',
        component: () => import('@/views/filemanager/index'),
        name: 'FileManager',
        meta: { title: '文件管理', icon: 'folder' }
      }
    ]
  },
  {
    path: '/database',
    component: Layout,
    redirect: '/database/index',
    meta: { title: '数据库', icon: 'database' },
    children: [
      {
        path: 'index',
        component: () => import('@/views/database/index'),
        name: 'Database',
        meta: { title: '数据库管理', icon: 'database' }
      }
    ]
  },
  {
    path: '/appstore',
    component: Layout,
    redirect: '/appstore/index',
    meta: { title: '应用商店', icon: 'app' },
    children: [
      {
        path: 'index',
        component: () => import('@/views/appstore/index'),
        name: 'AppStore',
        meta: { title: '应用商店', icon: 'app' }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes: constantRoutes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  }
})

export function resetRouter() {
  const newRouter = createRouter({
    history: createWebHistory(),
    routes: constantRoutes,
    scrollBehavior(to, from, savedPosition) {
      if (savedPosition) {
        return savedPosition
      } else {
        return { top: 0 }
      }
    }
  })
  router.matcher = newRouter.matcher
}

export default router 