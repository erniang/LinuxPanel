package monitor

import (
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

// DiskUsage 存储磁盘使用信息
type DiskUsage struct {
	Path       string  `json:"path"`       // 挂载点路径
	Total      uint64  `json:"total"`      // 总容量(byte)
	Used       uint64  `json:"used"`       // 已用容量
	UsedPercent float64 `json:"usedPercent"` // 使用百分比
}

// MonitorData 存储系统监控数据
type MonitorData struct {
	CPU     float64 `json:"cpu"`     // CPU使用率百分比
	Memory  struct {
		Total uint64 `json:"total"`  // 总内存(byte)
		Used  uint64 `json:"used"`   // 已用内存
		UsedPercent float64 `json:"usedPercent"` // 使用百分比
	} `json:"memory"`
	Disk    []DiskUsage `json:"disk"`  // 各分区使用情况
	Network struct {
		Rx uint64 `json:"rx"`       // 接收字节数
		Tx uint64 `json:"tx"`       // 发送字节数
	} `json:"network"`
	Uptime uint64 `json:"uptime"`     // 系统运行时间(秒)
	LoadAvg [3]float64 `json:"loadAvg"` // 1, 5, 15分钟负载
}

// HistoricalData 存储历史监控数据的环形缓冲区
type HistoricalData struct {
	Data []MonitorData // 监控数据数组
	Size int           // 缓冲区大小
	Pos  int           // 当前位置
	mu   sync.RWMutex  // 读写锁
}

// 全局监控数据存储
var (
	currentData MonitorData
	historyData *HistoricalData
	dataMutex   sync.RWMutex
	lastNetIO   net.IOCountersStat // 上次网络IO计数
	lastIOTime  time.Time          // 上次IO时间
)

// Init 初始化监控系统
func Init() {
	// 初始化环形缓冲区 (24小时 x 60分钟，每分钟一个采样点)
	historyData = &HistoricalData{
		Data: make([]MonitorData, 24*60),
		Size: 24*60,
	}
	
	// 初始化网络基线
	ioStats, _ := net.IOCounters(false)
	if len(ioStats) > 0 {
		lastNetIO = ioStats[0]
		lastIOTime = time.Now()
	}
	
	// 启动后台收集任务
	go collectMetricsTask()
}

// 后台定时收集指标
func collectMetricsTask() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	
	// 立即收集一次
	CollectMetrics()
	
	for range ticker.C {
		CollectMetrics()
	}
}

// CollectMetrics 收集系统指标
func CollectMetrics() MonitorData {
	data := MonitorData{}
	
	// CPU使用率
	cpuPercent, err := cpu.Percent(time.Second, false)
	if err == nil && len(cpuPercent) > 0 {
		data.CPU = cpuPercent[0]
	}
	
	// 内存使用
	memInfo, err := mem.VirtualMemory()
	if err == nil {
		data.Memory.Total = memInfo.Total
		data.Memory.Used = memInfo.Used
		data.Memory.UsedPercent = memInfo.UsedPercent
	}
	
	// 磁盘使用情况
	partitions, err := disk.Partitions(false)
	if err == nil {
		for _, part := range partitions {
			usage, err := disk.Usage(part.Mountpoint)
			if err == nil {
				diskUsage := DiskUsage{
					Path:       part.Mountpoint,
					Total:      usage.Total,
					Used:       usage.Used,
					UsedPercent: usage.UsedPercent,
				}
				data.Disk = append(data.Disk, diskUsage)
			}
		}
	}
	
	// 网络IO
	ioStats, err := net.IOCounters(false)
	if err == nil && len(ioStats) > 0 {
		curTime := time.Now()
		timeDelta := curTime.Sub(lastIOTime).Seconds()
		
		// 计算速率
		if timeDelta > 0 {
			data.Network.Rx = ioStats[0].BytesRecv
			data.Network.Tx = ioStats[0].BytesSent
			
			// 更新历史记录
			lastNetIO = ioStats[0]
			lastIOTime = curTime
		}
	}
	
	// 更新当前数据
	dataMutex.Lock()
	currentData = data
	dataMutex.Unlock()
	
	// 保存到历史数据
	historyData.mu.Lock()
	historyData.Data[historyData.Pos] = data
	historyData.Pos = (historyData.Pos + 1) % historyData.Size
	historyData.mu.Unlock()
	
	return data
}

// GetCurrentMetrics 获取当前指标
func GetCurrentMetrics() MonitorData {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	return currentData
}

// GetHistoricalMetrics 获取历史指标
func GetHistoricalMetrics(hours int) []MonitorData {
	if hours <= 0 || hours > 24 {
		hours = 24
	}
	
	count := hours * 60
	result := make([]MonitorData, 0, count)
	
	historyData.mu.RLock()
	defer historyData.mu.RUnlock()
	
	// 从当前位置向前取指定数量的样本
	pos := historyData.Pos
	for i := 0; i < count; i++ {
		// 向前移动（环形缓冲区）
		pos = (pos - 1 + historyData.Size) % historyData.Size
		
		// 如果数据有效，添加到结果
		if historyData.Data[pos].Memory.Total > 0 {
			result = append(result, historyData.Data[pos])
		}
	}
	
	return result
} 