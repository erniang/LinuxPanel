package api

import (
	"github.com/gin-gonic/gin"
	"github.com/yourusername/linuxpanel/pkg/api/v1"
	"github.com/yourusername/linuxpanel/pkg/core"
	"github.com/yourusername/linuxpanel/pkg/monitor"
)

// InitRoutes 初始化所有路由
func InitRoutes(router *gin.Engine, config *core.Config) {
	// 初始化监控模块
	monitor.Init()
	
	// API版本v1
	v1Group := router.Group("/api/v1")
	{
		// 初始化各子模块路由
		v1.InitMonitorRoutes(v1Group)
		v1.InitFileManagerRoutes(v1Group)
		v1.InitUserRoutes(v1Group)
		v1.InitAppStoreRoutes(v1Group)
		v1.InitWebSiteRoutes(v1Group)
		v1.InitSecurityRoutes(v1Group)
		v1.InitDatabaseRoutes(v1Group)
	}
	
	// 前端静态文件
	router.Static("/assets", "./ui/dist/assets")
	router.StaticFile("/", "./ui/dist/index.html")
	router.StaticFile("/favicon.ico", "./ui/dist/favicon.ico")
} 