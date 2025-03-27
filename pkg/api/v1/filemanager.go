package v1

import (
	"io/ioutil"
	"net/http"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/linuxpanel/pkg/filemanager"
)

// InitFileManagerRoutes 初始化文件管理相关的路由
func InitFileManagerRoutes(router *gin.RouterGroup) {
	fileGroup := router.Group("/files")
	{
		fileGroup.GET("/list", listDirectory)
		fileGroup.GET("/read", readFile)
		fileGroup.POST("/write", writeFile)
		fileGroup.POST("/delete", deleteFile)
		fileGroup.POST("/mkdir", createDirectory)
		fileGroup.POST("/copy", copyFile)
		fileGroup.POST("/upload", uploadFile)
	}
}

// listDirectory 列出目录内容
func listDirectory(c *gin.Context) {
	path := c.Query("path")
	if path == "" {
		path = "/"
	}
	
	files, err := filemanager.ListDirectory(path)
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
		"data": gin.H{
			"path":  path,
			"files": files,
		},
	})
}

// readFile 读取文件内容
func readFile(c *gin.Context) {
	path := c.Query("path")
	if path == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "路径不能为空",
		})
		return
	}
	
	content, err := filemanager.ReadFile(path)
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
		"data": gin.H{
			"path":    path,
			"content": string(content),
		},
	})
}

// writeFile 写入文件内容
func writeFile(c *gin.Context) {
	var req struct {
		Path    string `json:"path"`
		Content string `json:"content"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.Path == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "路径不能为空",
		})
		return
	}
	
	if err := filemanager.WriteFile(req.Path, []byte(req.Content)); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "文件保存成功",
	})
}

// deleteFile 删除文件或目录
func deleteFile(c *gin.Context) {
	var req struct {
		Path string `json:"path"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.Path == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "路径不能为空",
		})
		return
	}
	
	if err := filemanager.DeleteFile(req.Path); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "删除成功",
	})
}

// createDirectory 创建目录
func createDirectory(c *gin.Context) {
	var req struct {
		Path string `json:"path"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.Path == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "路径不能为空",
		})
		return
	}
	
	if err := filemanager.CreateDirectory(req.Path); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "目录创建成功",
	})
}

// copyFile 复制文件或目录
func copyFile(c *gin.Context) {
	var req struct {
		Source      string `json:"source"`
		Destination string `json:"destination"`
	}
	
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	if req.Source == "" || req.Destination == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "源路径和目标路径不能为空",
		})
		return
	}
	
	if err := filemanager.CopyFile(req.Source, req.Destination); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "文件复制成功",
	})
}

// uploadFile 上传文件
func uploadFile(c *gin.Context) {
	// 获取目标目录路径
	dstDir := c.PostForm("path")
	if dstDir == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "目标目录不能为空",
		})
		return
	}
	
	// 安全检查
	if !filemanager.IsPathSafe(dstDir) {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "目标目录不在安全路径内",
		})
		return
	}
	
	// 获取上传的文件
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取上传文件失败: " + err.Error(),
		})
		return
	}
	defer file.Close()
	
	// 读取文件内容
	fileContent, err := ioutil.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "读取上传文件失败: " + err.Error(),
		})
		return
	}
	
	// 保存文件
	dstPath := filepath.Join(dstDir, header.Filename)
	if err := filemanager.WriteFile(dstPath, fileContent); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "保存文件失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "文件上传成功",
		"data": gin.H{
			"path": dstPath,
			"size": len(fileContent),
			"name": header.Filename,
		},
	})
} 