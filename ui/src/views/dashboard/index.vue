<template>
  <div class="dashboard page-container">
    <h2 class="page-title">系统概览</h2>
    
    <!-- 状态卡片 -->
    <el-row :gutter="20" class="status-cards">
      <el-col :xs="24" :sm="12" :md="6">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>CPU</span>
            </div>
          </template>
          <el-progress 
            type="dashboard" 
            :percentage="cpuUsage" 
            :color="getCpuColor(cpuUsage)"
          />
          <div class="card-info">
            <span>负载: {{ status.load1.toFixed(2) }}</span>
          </div>
        </el-card>
      </el-col>
      
      <el-col :xs="24" :sm="12" :md="6">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>内存</span>
            </div>
          </template>
          <el-progress 
            type="dashboard" 
            :percentage="memoryUsage" 
            :color="getMemoryColor(memoryUsage)"
          />
          <div class="card-info">
            <span>已用: {{ formatSize(status.memoryTotal - status.memoryFree) }}</span>
            <span>总计: {{ formatSize(status.memoryTotal) }}</span>
          </div>
        </el-card>
      </el-col>
      
      <el-col :xs="24" :sm="12" :md="6">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>磁盘</span>
            </div>
          </template>
          <el-progress 
            type="dashboard" 
            :percentage="diskUsage" 
            :color="getDiskColor(diskUsage)"
          />
          <div class="card-info">
            <span>已用: {{ formatSize(status.diskTotal - status.diskFree) }}</span>
            <span>总计: {{ formatSize(status.diskTotal) }}</span>
          </div>
        </el-card>
      </el-col>
      
      <el-col :xs="24" :sm="12" :md="6">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>网站</span>
            </div>
          </template>
          <div class="website-status">
            <h3>{{ websiteCount }}</h3>
            <p>运行网站数</p>
          </div>
        </el-card>
      </el-col>
    </el-row>
    
    <!-- 监控图表 -->
    <el-row :gutter="20" class="monitor-charts">
      <el-col :xs="24" :md="12">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>CPU使用率(%)</span>
            </div>
          </template>
          <div class="chart-container">
            <chart ref="cpuChart" autoresize />
          </div>
        </el-card>
      </el-col>
      
      <el-col :xs="24" :md="12">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>内存使用率(%)</span>
            </div>
          </template>
          <div class="chart-container">
            <chart ref="memoryChart" autoresize />
          </div>
        </el-card>
      </el-col>
    </el-row>
    
    <!-- 系统信息 -->
    <el-row :gutter="20">
      <el-col :span="24">
        <el-card shadow="hover">
          <template #header>
            <div class="card-header">
              <span>系统信息</span>
            </div>
          </template>
          <el-descriptions :column="3" border>
            <el-descriptions-item label="操作系统">
              {{ systemInfo.platform }} {{ systemInfo.os }}
            </el-descriptions-item>
            <el-descriptions-item label="内核版本">
              {{ systemInfo.kernelVer }}
            </el-descriptions-item>
            <el-descriptions-item label="主机名">
              {{ systemInfo.hostname }}
            </el-descriptions-item>
            <el-descriptions-item label="CPU核心数">
              {{ systemInfo.cpuCores }}
            </el-descriptions-item>
            <el-descriptions-item label="内存">
              {{ formatSize(systemInfo.memory) }}
            </el-descriptions-item>
            <el-descriptions-item label="运行时间">
              {{ formatUptime(systemInfo.uptime) }}
            </el-descriptions-item>
            <el-descriptions-item label="面板版本">
              {{ systemInfo.panelVer }}
            </el-descriptions-item>
            <el-descriptions-item label="启动时间">
              {{ formatDate(systemInfo.bootTime) }}
            </el-descriptions-item>
            <el-descriptions-item label="系统时间">
              {{ formatDate(systemInfo.serverTime) }}
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script>
import { ref, reactive, onMounted, onBeforeUnmount, computed } from 'vue'
import { getSystemInfo, getSystemStatus } from '../../api/system'
import { getWebsiteList } from '../../api/website'
import { formatSize, formatDate, formatUptime } from '../../utils/format'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent, ToolboxComponent } from 'echarts/components'
import VChart from 'vue-echarts'

// 注册echarts组件
use([
  CanvasRenderer,
  LineChart,
  GridComponent,
  TooltipComponent,
  LegendComponent,
  ToolboxComponent
])

export default {
  name: 'Dashboard',
  components: {
    Chart: VChart
  },
  setup() {
    // 系统信息
    const systemInfo = reactive({
      hostname: '',
      os: '',
      platform: '',
      kernelVer: '',
      arch: '',
      goVersion: '',
      cpuCores: 0,
      memory: 0,
      uptime: 0,
      bootTime: null,
      serverTime: null,
      panelVer: '',
      panelUptime: null
    })
    
    // 系统状态
    const status = reactive({
      cpuUsage: 0,
      memoryUsage: 0,
      memoryFree: 0,
      memoryTotal: 0,
      diskUsage: 0,
      diskFree: 0,
      diskTotal: 0,
      load1: 0,
      load5: 0,
      load15: 0
    })
    
    // 圆环图进度值
    const cpuUsage = computed(() => Math.floor(status.cpuUsage))
    const memoryUsage = computed(() => Math.floor(status.memoryUsage))
    const diskUsage = computed(() => Math.floor(status.diskUsage))
    
    // 网站数量
    const websiteCount = ref(0)
    
    // 颜色获取函数
    const getCpuColor = (value) => {
      if (value < 60) return '#67C23A'
      if (value < 80) return '#E6A23C'
      return '#F56C6C'
    }
    
    const getMemoryColor = (value) => {
      if (value < 60) return '#67C23A'
      if (value < 80) return '#E6A23C'
      return '#F56C6C'
    }
    
    const getDiskColor = (value) => {
      if (value < 60) return '#67C23A'
      if (value < 80) return '#E6A23C'
      return '#F56C6C'
    }
    
    // 图表引用
    const cpuChart = ref(null)
    const memoryChart = ref(null)
    
    // 图表数据
    const cpuData = reactive({
      times: [],
      values: []
    })
    
    const memoryData = reactive({
      times: [],
      values: []
    })
    
    // 获取系统信息
    const fetchSystemInfo = async () => {
      try {
        const res = await getSystemInfo()
        Object.assign(systemInfo, res.data)
      } catch (error) {
        console.error('获取系统信息失败:', error)
      }
    }
    
    // 获取系统状态
    const fetchSystemStatus = async () => {
      try {
        const res = await getSystemStatus()
        Object.assign(status, res.data)
        
        // 更新图表数据
        updateChartData()
      } catch (error) {
        console.error('获取系统状态失败:', error)
      }
    }
    
    // 获取网站列表
    const fetchWebsites = async () => {
      try {
        const res = await getWebsiteList()
        // 计算运行中的网站数量
        websiteCount.value = res.data.filter(site => site.status === 1).length
      } catch (error) {
        console.error('获取网站列表失败:', error)
      }
    }
    
    // 更新图表数据
    const updateChartData = () => {
      const now = new Date()
      const timeStr = `${now.getHours()}:${now.getMinutes()}:${now.getSeconds()}`
      
      // 更新CPU数据
      cpuData.times.push(timeStr)
      cpuData.values.push(status.cpuUsage)
      
      // 保持最多显示20个点
      if (cpuData.times.length > 20) {
        cpuData.times.shift()
        cpuData.values.shift()
      }
      
      // 更新内存数据
      memoryData.times.push(timeStr)
      memoryData.values.push(status.memoryUsage)
      
      if (memoryData.times.length > 20) {
        memoryData.times.shift()
        memoryData.values.shift()
      }
      
      // 更新图表配置
      updateCharts()
    }
    
    // 更新图表
    const updateCharts = () => {
      if (cpuChart.value) {
        cpuChart.value.setOption({
          tooltip: {
            trigger: 'axis'
          },
          xAxis: {
            type: 'category',
            data: cpuData.times,
            axisLabel: {
              rotate: 45
            }
          },
          yAxis: {
            type: 'value',
            min: 0,
            max: 100,
            axisLabel: {
              formatter: '{value}%'
            }
          },
          series: [
            {
              name: 'CPU使用率',
              type: 'line',
              data: cpuData.values,
              smooth: true,
              showSymbol: false,
              areaStyle: {
                opacity: 0.2
              },
              lineStyle: {
                width: 2
              }
            }
          ]
        })
      }
      
      if (memoryChart.value) {
        memoryChart.value.setOption({
          tooltip: {
            trigger: 'axis'
          },
          xAxis: {
            type: 'category',
            data: memoryData.times,
            axisLabel: {
              rotate: 45
            }
          },
          yAxis: {
            type: 'value',
            min: 0,
            max: 100,
            axisLabel: {
              formatter: '{value}%'
            }
          },
          series: [
            {
              name: '内存使用率',
              type: 'line',
              data: memoryData.values,
              smooth: true,
              showSymbol: false,
              areaStyle: {
                opacity: 0.2
              },
              lineStyle: {
                width: 2
              }
            }
          ]
        })
      }
    }
    
    // 定时器
    let timer = null
    
    onMounted(async () => {
      // 初始化数据
      await fetchSystemInfo()
      await fetchSystemStatus()
      await fetchWebsites()
      
      // 初始化图表
      updateCharts()
      
      // 定时更新状态
      timer = setInterval(async () => {
        await fetchSystemStatus()
      }, 5000)
    })
    
    onBeforeUnmount(() => {
      // 清除定时器
      if (timer) {
        clearInterval(timer)
        timer = null
      }
    })
    
    return {
      systemInfo,
      status,
      cpuUsage,
      memoryUsage,
      diskUsage,
      websiteCount,
      cpuChart,
      memoryChart,
      getCpuColor,
      getMemoryColor,
      getDiskColor,
      formatSize,
      formatDate,
      formatUptime
    }
  }
}
</script>

<style lang="scss" scoped>
.dashboard {
  .page-title {
    margin-top: 0;
    margin-bottom: 20px;
    font-size: 20px;
    font-weight: 600;
  }
  
  .status-cards {
    .el-card {
      margin-bottom: 20px;
      text-align: center;
      
      .card-header {
        font-weight: bold;
      }
    }
  }
  
  .chart-container {
    height: 300px;
  }
  
  .website-status {
    height: 130px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    
    h3 {
      font-size: 38px;
      color: #409EFF;
      margin: 0;
      margin-bottom: 10px;
    }
    
    p {
      margin: 0;
      color: #606266;
    }
  }
}
</style> 