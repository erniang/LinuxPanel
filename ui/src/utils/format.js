import moment from 'moment'
// 加载中文语言包
import 'moment/locale/zh-cn'
moment.locale('zh-cn')

/**
 * 格式化文件大小
 * @param {number} size 文件大小 (字节)
 * @returns {string} 格式化后的文件大小
 */
export function formatSize(size) {
  if (size === null || size === undefined || size === '') {
    return '0 B'
  }
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']
  let index = 0
  
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024
    index++
  }
  
  return size.toFixed(2) + ' ' + units[index]
}

/**
 * 格式化时间戳
 * @param {number|string|Date} time 时间戳或日期对象
 * @param {string} format 格式化模板
 * @returns {string} 格式化后的时间
 */
export function formatDate(time, format = 'YYYY-MM-DD HH:mm:ss') {
  if (!time) return ''
  return moment(time).format(format)
}

/**
 * 格式化运行时间
 * @param {number} seconds 秒数
 * @returns {string} 格式化后的时间
 */
export function formatUptime(seconds) {
  if (!seconds) return '0秒'
  
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const remainingSeconds = Math.floor(seconds % 60)
  
  let result = ''
  if (days > 0) {
    result += days + '天'
  }
  if (hours > 0 || days > 0) {
    result += hours + '小时'
  }
  if (minutes > 0 || hours > 0 || days > 0) {
    result += minutes + '分钟'
  }
  if (remainingSeconds > 0 || minutes > 0 || hours > 0 || days > 0) {
    result += remainingSeconds + '秒'
  }
  
  return result
} 