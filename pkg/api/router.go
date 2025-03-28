package api

import (
	"log"
	"os"

	"github.com/erniang/LinuxPanel/pkg/core"
	"github.com/gin-gonic/gin"
)

// InitRouter 初始化API路由
func InitRouter(config *core.Config) *gin.Engine {
	// 设置模式，根据环境变量调整
	mode := os.Getenv("GIN_MODE")
	if mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	} else if mode == "test" {
		gin.SetMode(gin.TestMode)
	}

	// 创建带有默认中间件的路由
	router := gin.Default()

	// 添加CORS中间件
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// 添加恢复中间件
	router.Use(gin.Recovery())

	// 记录请求日志
	router.Use(func(c *gin.Context) {
		// 开始时间
		log.Printf("API请求: %s %s", c.Request.Method, c.Request.URL.Path)
		c.Next()
	})

	// 初始化所有路由
	InitRoutes(router, config)

	return router
}
