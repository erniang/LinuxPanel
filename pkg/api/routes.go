package api

import (
	"net/http"

	v1 "github.com/erniang/LinuxPanel/pkg/api/v1"
	"github.com/erniang/LinuxPanel/pkg/core"
	"github.com/erniang/LinuxPanel/pkg/monitor"
	"github.com/gin-gonic/gin"
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
		v1.InitSystemRoutes(v1Group)
		v1.InitDatabaseRoutes(v1Group)
	}

	// 前端静态文件
	router.Static("/assets", "./ui/dist/assets")
	router.StaticFile("/favicon.ico", "./ui/dist/favicon.ico")

	// 处理所有其他路由，返回前端入口文件，支持SPA的路由
	router.NoRoute(func(c *gin.Context) {
		// 如果是API路由，返回404
		if len(c.Request.URL.Path) >= 4 && c.Request.URL.Path[:4] == "/api" {
			c.JSON(http.StatusNotFound, gin.H{"error": "API not found"})
			return
		}
		// 非API路由，返回前端入口文件
		c.File("./ui/dist/index.html")
	})
}
