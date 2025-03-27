package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/erniang/LinuxPanel/pkg/api"
	"github.com/erniang/LinuxPanel/pkg/core"
)

var (
	configPath string
	port       int
	debug      bool
)

func init() {
	// 命令行参数解析
	flag.StringVar(&configPath, "config", "/etc/panel/config.yaml", "配置文件路径")
	flag.IntVar(&port, "port", 8080, "HTTP服务端口")
	flag.BoolVar(&debug, "debug", false, "是否开启调试模式")
	flag.Parse()
	
	// 创建必要的目录
	os.MkdirAll(filepath.Dir(configPath), 0755)
}

func main() {
	// 初始化配置
	config, err := core.LoadConfig(configPath)
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}
	
	// 设置模式
	if debug {
		gin.SetMode(gin.DebugMode)
	} else {
		gin.SetMode(gin.ReleaseMode)
	}
	
	// 创建服务器实例
	router := gin.Default()
	
	// 初始化API路由
	api.InitRoutes(router, config)
	
	// 启动服务器
	serverAddr := fmt.Sprintf(":%d", port)
	if config.Port > 0 {
		serverAddr = fmt.Sprintf(":%d", config.Port)
	}
	
	fmt.Printf("轻量级Linux面板启动于 http://localhost%s\n", serverAddr)
	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("服务器启动失败: %v", err)
	}
} 