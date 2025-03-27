package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/erniang/LinuxPanel/pkg/api"
)

var (
	port     = flag.Int("port", 8080, "HTTP服务端口")
	version  = "1.0.0"
	buildTag = "dev"
)

func main() {
	// 解析命令行参数
	flag.Parse()
	
	// 打印启动信息
	fmt.Printf("LinuxPanel v%s (%s) 正在启动...\n", version, buildTag)
	fmt.Printf("HTTP服务监听端口: %d\n", *port)
	
	// 初始化API路由
	router := api.InitRouter()
	
	// 启动HTTP服务
	go func() {
		addr := fmt.Sprintf(":%d", *port)
		err := router.Run(addr)
		if err != nil {
			fmt.Printf("启动HTTP服务失败: %s\n", err.Error())
			os.Exit(1)
		}
	}()
	
	// 等待中断信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	
	// 优雅退出
	fmt.Println("正在关闭服务...")
	fmt.Println("服务已关闭")
} 