package api

import (
	"net/http"
	"os"
	"path/filepath"

	v1 "github.com/erniang/LinuxPanel/pkg/api/v1"
	"github.com/erniang/LinuxPanel/pkg/core"
	"github.com/erniang/LinuxPanel/pkg/monitor"
	"github.com/gin-gonic/gin"
)

// InitRoutes 初始化所有路由
func InitRoutes(router *gin.Engine, config *core.Config) {
	// 初始化监控模块
	monitor.Init()

	// 添加基本的测试API（即使前端构建失败，也能确保API能响应）
	router.GET("/api/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": "API服务正常运行",
		})
	})

	// 添加基本的系统信息API
	router.GET("/api/system/info", func(c *gin.Context) {
		info := map[string]interface{}{
			"hostname":       "localhost",
			"os":             "Linux",
			"platform":       "x86_64",
			"kernel_version": "5.10.0",
			"go_version":     "1.21",
			"cpu_cores":      4,
			"memory":         8192,
			"uptime":         0,
			"server_time":    "",
			"panel_version":  config.Version,
		}
		c.JSON(http.StatusOK, info)
	})

	// 添加登录API
	router.POST("/api/auth/login", func(c *gin.Context) {
		var login struct {
			Username string `json:"username"`
			Password string `json:"password"`
		}
		if err := c.ShouldBindJSON(&login); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的请求参数"})
			return
		}

		// 简单认证逻辑，仅作演示
		if login.Username == "admin" && login.Password == "admin123" {
			c.JSON(http.StatusOK, gin.H{
				"token": "demo-token-12345",
				"user": gin.H{
					"name": "admin",
					"role": "admin",
				},
			})
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		}
	})

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
	uiDistPath := "./ui/dist"
	if stat, err := os.Stat(uiDistPath); err == nil && stat.IsDir() {
		router.Static("/assets", filepath.Join(uiDistPath, "assets"))
		router.StaticFile("/favicon.ico", filepath.Join(uiDistPath, "favicon.ico"))
	}

	// 处理所有其他路由，返回前端入口文件，支持SPA的路由
	router.NoRoute(func(c *gin.Context) {
		// 如果是API路由，返回404
		if len(c.Request.URL.Path) >= 4 && c.Request.URL.Path[:4] == "/api" {
			c.JSON(http.StatusNotFound, gin.H{"error": "API not found"})
			return
		}

		// 检查前端入口文件是否存在
		indexPath := filepath.Join(uiDistPath, "index.html")
		if _, err := os.Stat(indexPath); os.IsNotExist(err) {
			// 创建临时入口文件
			createTempIndexFile(uiDistPath)
		}

		// 返回前端入口文件
		c.File(indexPath)
	})
}

// createTempIndexFile 创建临时入口文件
func createTempIndexFile(distPath string) {
	// 确保目录存在
	os.MkdirAll(distPath, 0755)

	// 创建基本HTML
	html := `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LinuxPanel - 轻量级管理面板</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background-color: #f5f7fa;
            color: #333;
        }
        .container {
            background-color: white;
            border-radius: 4px;
            box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
            padding: 20px;
            width: 80%;
            max-width: 600px;
            text-align: center;
        }
        h1 {
            color: #409EFF;
        }
        .api-test {
            margin-top: 20px;
            padding: 15px;
            background-color: #f0f9eb;
            border-radius: 4px;
            text-align: left;
        }
        button {
            background-color: #409EFF;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin-top: 20px;
        }
        button:hover {
            background-color: #337ecc;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>LinuxPanel</h1>
        <p>后端服务运行中，前端页面未找到</p>
        <div class="api-test">
            <h3>API测试</h3>
            <div id="api-result">正在测试API连接...</div>
        </div>
        <button onclick="testAPI()">测试API连接</button>
    </div>
    <script>
        function testAPI() {
            const resultElem = document.getElementById('api-result');
            resultElem.textContent = '正在连接API...';
            
            fetch('/api/test')
                .then(response => response.json())
                .then(data => {
                    resultElem.textContent = '✅ API连接成功: ' + data.message;
                })
                .catch(error => {
                    resultElem.textContent = '❌ API连接失败: ' + error.message;
                });
        }
        
        // 自动测试API
        testAPI();
    </script>
</body>
</html>`

	// 写入文件
	indexPath := filepath.Join(distPath, "index.html")
	os.WriteFile(indexPath, []byte(html), 0644)
}
