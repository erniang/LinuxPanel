package api

import (
	"github.com/gin-gonic/gin"
)

// InitRouter 初始化API路由
func InitRouter() *gin.Engine {
	router := gin.Default()

	// 初始化路由
	InitRoutes(router, nil)

	return router
}
