package v1

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/erniang/LinuxPanel/pkg/store"
)

// InitAppStoreRoutes 初始化应用商店相关的路由
func InitAppStoreRoutes(router *gin.RouterGroup) {
	// 初始化应用商店模块
	store.Init()
	
	appGroup := router.Group("/apps")
	{
		appGroup.GET("/list", listApps)
		appGroup.GET("/installed", listInstalledApps)
		appGroup.GET("/detail/:id", getAppDetail)
		appGroup.POST("/install", installApp)
		appGroup.POST("/uninstall", uninstallApp)
		appGroup.GET("/registries", listRegistries)
		appGroup.POST("/registries/add", addRegistry)
		appGroup.POST("/registries/remove", removeRegistry)
	}
}

// listApps 列出所有可用应用
func listApps(c *gin.Context) {
	apps, err := store.FetchAppList()
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取应用列表失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": apps,
	})
}

// listInstalledApps 列出已安装的应用
func listInstalledApps(c *gin.Context) {
	apps := store.GetInstalledApps()
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": apps,
	})
}

// getAppDetail 获取应用详情
func getAppDetail(c *gin.Context) {
	id := c.Param("id")
	
	app, err := store.GetApp(id)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": app,
	})
}

// installApp 安装应用
func installApp(c *gin.Context) {
	var appMeta store.AppMeta
	if err := c.BindJSON(&appMeta); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if appMeta.ID == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "应用ID不能为空",
		})
		return
	}
	
	if err := store.InstallApp(appMeta); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "安装应用失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "应用安装已启动，可查看详情了解安装进度",
	})
}

// uninstallApp 卸载应用
func uninstallApp(c *gin.Context) {
	var req struct {
		ID string `json:"id"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.ID == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "应用ID不能为空",
		})
		return
	}
	
	if err := store.UninstallApp(req.ID); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "卸载应用失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "应用卸载成功",
	})
}

// listRegistries 列出所有应用仓库
func listRegistries(c *gin.Context) {
	registries := store.GetRegistries()
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": registries,
	})
}

// addRegistry 添加应用仓库
func addRegistry(c *gin.Context) {
	var registry store.AppRegistry
	if err := c.BindJSON(&registry); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if registry.Name == "" || registry.URL == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "仓库名称和URL不能为空",
		})
		return
	}
	
	store.AddRegistry(registry)
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "仓库添加成功",
	})
}

// removeRegistry 移除应用仓库
func removeRegistry(c *gin.Context) {
	var req struct {
		URL string `json:"url"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.URL == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "仓库URL不能为空",
		})
		return
	}
	
	store.RemoveRegistry(req.URL)
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "仓库移除成功",
	})
} 