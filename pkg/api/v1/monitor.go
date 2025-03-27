package v1

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/erniang/LinuxPanel/pkg/monitor"
)

// InitMonitorRoutes 初始化监控相关的路由
func InitMonitorRoutes(router *gin.RouterGroup) {
	monitorGroup := router.Group("/monitor")
	{
		monitorGroup.GET("/current", getCurrentMetrics)
		monitorGroup.GET("/history", getHistoricalMetrics)
	}
}

// getCurrentMetrics 获取当前系统指标
func getCurrentMetrics(c *gin.Context) {
	data := monitor.GetCurrentMetrics()
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": data,
	})
}

// getHistoricalMetrics 获取历史系统指标
func getHistoricalMetrics(c *gin.Context) {
	hoursStr := c.DefaultQuery("hours", "6")
	hours, err := strconv.Atoi(hoursStr)
	if err != nil || hours <= 0 || hours > 24 {
		hours = 6 // 默认6小时
	}
	
	data := monitor.GetHistoricalMetrics(hours)
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": data,
	})
} 