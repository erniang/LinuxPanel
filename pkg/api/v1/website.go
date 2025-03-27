package v1

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/linuxpanel/pkg/api"
	"github.com/yourusername/linuxpanel/pkg/web"
)

// InitWebSiteRoutes 初始化网站管理相关的路由
func InitWebSiteRoutes(router *gin.RouterGroup) {
	// 初始化网站管理模块
	web.Init()
	
	// 需要运维或管理权限
	webGroup := router.Group("/websites")
	webGroup.Use(api.AuthMiddleware(), api.OperatorOnly())
	{
		webGroup.GET("/list", listWebsites)
		webGroup.GET("/detail/:id", getWebsiteDetail)
		webGroup.POST("/create", createWebsite)
		webGroup.POST("/update", updateWebsite)
		webGroup.POST("/delete", deleteWebsite)
		webGroup.POST("/control", controlWebsite)
	}
}

// listWebsites 列出所有网站
func listWebsites(c *gin.Context) {
	websites := web.GetAllWebsites()
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": websites,
	})
}

// getWebsiteDetail 获取网站详情
func getWebsiteDetail(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的网站ID",
		})
		return
	}
	
	website, err := web.GetWebsite(id)
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
		"data": website,
	})
}

// createWebsite 创建网站
func createWebsite(c *gin.Context) {
	var config web.WebsiteConfig
	if err := c.BindJSON(&config); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if config.Domain == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "域名不能为空",
		})
		return
	}
	
	website, err := web.CreateWebsite(config)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "创建网站失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "网站创建成功",
		"data": website,
	})
}

// updateWebsite 更新网站配置
func updateWebsite(c *gin.Context) {
	var config web.WebsiteConfig
	if err := c.BindJSON(&config); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if config.ID <= 0 {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的网站ID",
		})
		return
	}
	
	website, err := web.UpdateWebsite(config.ID, config)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "更新网站失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "网站更新成功",
		"data": website,
	})
}

// deleteWebsite 删除网站
func deleteWebsite(c *gin.Context) {
	var req struct {
		ID int `json:"id"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.ID <= 0 {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的网站ID",
		})
		return
	}
	
	if err := web.DeleteWebsite(req.ID); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "删除网站失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "网站删除成功",
	})
}

// controlWebsite 控制网站状态（启用/停用）
func controlWebsite(c *gin.Context) {
	var req struct {
		ID     int  `json:"id"`
		Enable bool `json:"enable"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.ID <= 0 {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的网站ID",
		})
		return
	}
	
	if err := web.ControlWebsite(req.ID, req.Enable); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "控制网站失败: " + err.Error(),
		})
		return
	}
	
	status := "已启用"
	if !req.Enable {
		status = "已停用"
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "网站" + status,
	})
} 