package v1

import (
	"net/http"
	"runtime"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/yourusername/linuxpanel/pkg/api"
)

// InitSystemRoutes 初始化系统管理相关的路由
func InitSystemRoutes(router *gin.RouterGroup) {
	sysGroup := router.Group("/system")
	
	// 公开路由
	sysGroup.GET("/info", getSystemInfo)
	
	// 需要认证的路由
	sysGroup.Use(api.AuthMiddleware())
	{
		sysGroup.GET("/status", getSystemStatus)
	}
	
	// 仅管理员可访问的路由
	adminSysGroup := sysGroup.Group("/admin")
	adminSysGroup.Use(api.AdminOnly())
	{
		adminSysGroup.POST("/reboot", rebootSystem)
	}
}

// SystemInfo 系统信息
type SystemInfo struct {
	Hostname    string    `json:"hostname"`
	OS          string    `json:"os"`
	Platform    string    `json:"platform"`
	KernelVer   string    `json:"kernel_version"`
	Arch        string    `json:"arch"`
	GoVersion   string    `json:"go_version"`
	CPUCores    int       `json:"cpu_cores"`
	Memory      uint64    `json:"memory"`
	Uptime      uint64    `json:"uptime"`
	BootTime    time.Time `json:"boot_time"`
	ServerTime  time.Time `json:"server_time"`
	PanelVer    string    `json:"panel_version"`
	PanelUptime time.Time `json:"panel_uptime"`
}

// SystemStatus 系统状态
type SystemStatus struct {
	CPUUsage    float64 `json:"cpu_usage"`
	MemoryUsage float64 `json:"memory_usage"`
	MemoryFree  uint64  `json:"memory_free"`
	MemoryTotal uint64  `json:"memory_total"`
	DiskUsage   float64 `json:"disk_usage"`
	DiskFree    uint64  `json:"disk_free"`
	DiskTotal   uint64  `json:"disk_total"`
	Load1       float64 `json:"load1"`
	Load5       float64 `json:"load5"`
	Load15      float64 `json:"load15"`
}

// 面板启动时间
var panelUptime = time.Now()

// getSystemInfo 获取系统信息
func getSystemInfo(c *gin.Context) {
	// 获取主机信息
	hostInfo, err := host.Info()
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取系统信息失败: " + err.Error(),
		})
		return
	}
	
	// 获取内存信息
	memInfo, err := mem.VirtualMemory()
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取内存信息失败: " + err.Error(),
		})
		return
	}
	
	// 获取CPU信息
	cpuCount, err := cpu.Counts(true)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取CPU信息失败: " + err.Error(),
		})
		return
	}
	
	// 构建系统信息
	info := SystemInfo{
		Hostname:    hostInfo.Hostname,
		OS:          hostInfo.OS,
		Platform:    hostInfo.Platform,
		KernelVer:   hostInfo.KernelVersion,
		Arch:        runtime.GOARCH,
		GoVersion:   runtime.Version(),
		CPUCores:    cpuCount,
		Memory:      memInfo.Total,
		Uptime:      hostInfo.Uptime,
		BootTime:    time.Unix(int64(hostInfo.BootTime), 0),
		ServerTime:  time.Now(),
		PanelVer:    "1.0.0", // 硬编码面板版本，实际应该从配置或构建信息获取
		PanelUptime: panelUptime,
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": info,
	})
}

// getSystemStatus 获取系统状态
func getSystemStatus(c *gin.Context) {
	// 获取CPU使用率
	cpuPercent, err := cpu.Percent(time.Second, false)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取CPU使用率失败: " + err.Error(),
		})
		return
	}
	
	// 获取内存使用情况
	memInfo, err := mem.VirtualMemory()
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取内存使用情况失败: " + err.Error(),
		})
		return
	}
	
	// 获取磁盘使用情况
	diskInfo, err := disk.Usage("/")
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取磁盘使用情况失败: " + err.Error(),
		})
		return
	}
	
	// 获取系统负载
	loadInfo, err := host.Load()
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取系统负载失败: " + err.Error(),
		})
		return
	}
	
	// 构建系统状态
	status := SystemStatus{
		CPUUsage:    cpuPercent[0],
		MemoryUsage: memInfo.UsedPercent,
		MemoryFree:  memInfo.Free,
		MemoryTotal: memInfo.Total,
		DiskUsage:   diskInfo.UsedPercent,
		DiskFree:    diskInfo.Free,
		DiskTotal:   diskInfo.Total,
		Load1:       loadInfo.Load1,
		Load5:       loadInfo.Load5,
		Load15:      loadInfo.Load15,
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": status,
	})
}

// rebootSystem 重启系统（仅管理员可用）
func rebootSystem(c *gin.Context) {
	// 实际操作应该执行系统命令重启
	// 这里只是示例，实际项目中应该使用os/exec调用系统命令
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "系统重启指令已发送",
	})
} 