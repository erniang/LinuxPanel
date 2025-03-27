package api

import (
	"github.com/gin-gonic/gin"
	v1 "github.com/yourusername/linuxpanel/pkg/api/v1"
)

// InitRouter 初始化API路由
func InitRouter() *gin.Engine {
	router := gin.Default()
	
	// API前缀分组
	apiGroup := router.Group("/api")
	
	// API v1版本
	v1Group := apiGroup.Group("/v1")
	{
		// 初始化各模块路由
		v1.InitSystemRoutes(v1Group)
		v1.InitUserRoutes(v1Group)
		v1.InitWebSiteRoutes(v1Group) // 添加网站管理路由
	}
	
	return router
} 