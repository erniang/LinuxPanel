package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"

	"github.com/erniang/LinuxPanel/pkg/api"
	"github.com/erniang/LinuxPanel/pkg/core"
)

var (
	Version = "1.0.0"
)

func main() {
	fmt.Printf("LinuxPanel 轻量级管理面板 v%s\n", Version)

	// 检查系统环境
	fmt.Println("检查系统环境...")

	// 初始化配置
	config := core.NewConfig()
	config.Version = Version
	config.Port = getPort()

	// 检查前端文件
	checkFrontendFiles()

	// 初始化数据库
	fmt.Println("初始化数据库...")
	err := core.InitDB(config)
	if err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}

	// 初始化API路由
	fmt.Printf("启动Web服务 [0.0.0.0:%d]...\n", config.Port)
	router := api.InitRouter(config)

	// 启动Web服务
	err = router.Run(fmt.Sprintf(":%d", config.Port))
	if err != nil {
		log.Fatalf("启动Web服务失败: %v", err)
	}
}

// 获取端口号
func getPort() int {
	portStr := os.Getenv("PANEL_PORT")
	if portStr != "" {
		port, err := strconv.Atoi(portStr)
		if err == nil && port > 0 && port < 65536 {
			return port
		}
	}
	return 8080 // 默认端口
}

// 检查前端文件
func checkFrontendFiles() {
	distDir := "./ui/dist"
	indexPath := filepath.Join(distDir, "index.html")

	// 检查dist目录是否存在
	if _, err := os.Stat(distDir); os.IsNotExist(err) {
		fmt.Println("警告: 前端文件目录不存在，创建临时页面")
		createTempIndexFile()
		return
	}

	// 检查index.html是否存在
	if _, err := os.Stat(indexPath); os.IsNotExist(err) {
		fmt.Println("警告: 前端入口文件不存在，创建临时页面")
		createTempIndexFile()
		return
	}

	fmt.Println("前端文件检查通过")
}

// 创建临时index.html文件
func createTempIndexFile() {
	// 确保目录存在
	os.MkdirAll("./ui/dist", 0755)

	// 创建临时HTML文件
	html := `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LinuxPanel - 轻量级Linux服务器管理面板</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f5f7fa;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            color: #333;
        }
        .container {
            text-align: center;
            background-color: white;
            border-radius: 10px;
            padding: 40px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
            max-width: 600px;
        }
        h1 {
            color: #409EFF;
            margin-bottom: 20px;
        }
        p {
            line-height: 1.6;
            margin-bottom: 20px;
        }
        .status {
            display: inline-block;
            background-color: #E6A23C;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-weight: bold;
        }
        .info {
            margin-top: 30px;
            font-size: 0.9em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>LinuxPanel 服务已启动</h1>
        <p>后端服务运行中，但前端文件未构建</p>
        <div class="status">临时页面</div>
        <div class="info">
            <p>请构建前端文件或安装完整版本：</p>
            <pre>cd /opt/linuxpanel/ui && npm install && npm run build</pre>
            <p>默认管理员账户: admin</p>
            <p>默认密码: admin123</p>
        </div>
    </div>
</body>
</html>
`

	err := os.WriteFile("./ui/dist/index.html", []byte(html), 0644)
	if err != nil {
		fmt.Printf("创建临时页面失败: %v\n", err)
	} else {
		fmt.Println("临时页面已创建")
	}
}
