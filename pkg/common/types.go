package common

import (
	"time"
)

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