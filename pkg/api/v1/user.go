package v1

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/linuxpanel/pkg/api"
	"github.com/yourusername/linuxpanel/pkg/auth"
)

// InitUserRoutes 初始化用户管理相关的路由
func InitUserRoutes(router *gin.RouterGroup) {
	// 公开路由
	publicGroup := router.Group("/public")
	{
		publicGroup.POST("/login", userLogin)
	}
	
	// 需要认证的路由
	userGroup := router.Group("/user")
	userGroup.Use(api.AuthMiddleware())
	{
		userGroup.GET("/info", getUserInfo)
		userGroup.POST("/logout", userLogout)
		userGroup.POST("/change-password", changePassword)
	}
	
	// 仅管理员可访问的路由
	adminGroup := router.Group("/users")
	adminGroup.Use(api.AuthMiddleware(), api.AdminOnly())
	{
		adminGroup.GET("/list", listUsers)
		adminGroup.POST("/create", createUser)
		adminGroup.POST("/update", updateUser)
		adminGroup.POST("/delete", deleteUser)
	}
}

// LoginRequest 登录请求
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// PasswordChangeRequest 修改密码请求
type PasswordChangeRequest struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required"`
}

// UserRequest 用户管理请求
type UserRequest struct {
	ID       int    `json:"id"`
	Username string `json:"username" binding:"required"`
	Password string `json:"password,omitempty"`
	Role     string `json:"role" binding:"required"`
	Status   int    `json:"status"`
}

// userLogin 用户登录
func userLogin(c *gin.Context) {
	var req LoginRequest
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的登录请求",
		})
		return
	}
	
	user, token, err := auth.Login(req.Username, req.Password)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "登录失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "登录成功",
		"data": gin.H{
			"token": token,
			"user":  user,
		},
	})
}

// userLogout 用户登出
func userLogout(c *gin.Context) {
	token := c.GetHeader("Authorization")
	// 移除Bearer前缀（如果有）
	token = token[7:]
	
	err := auth.Logout(token)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "登出失败: " + err.Error(),
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "登出成功",
	})
}

// getUserInfo 获取当前用户信息
func getUserInfo(c *gin.Context) {
	userObj, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取用户信息失败",
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": userObj,
	})
}

// changePassword 修改密码
func changePassword(c *gin.Context) {
	var req PasswordChangeRequest
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	user, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "获取用户信息失败",
		})
		return
	}
	
	userObj := user.(*auth.User)
	
	// 验证旧密码并更新新密码
	// 实际项目中应调用auth模块的ChangePassword方法
	// 这里仅为示例
	if req.OldPassword != "admin123" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "原密码错误",
		})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "密码修改成功",
	})
}

// listUsers 列出所有用户
func listUsers(c *gin.Context) {
	// 模拟数据，实际应从数据库获取
	users := []auth.User{
		{
			ID:       1,
			Username: "admin",
			Role:     auth.RoleAdmin,
			Status:   1,
		},
		{
			ID:       2,
			Username: "operator",
			Role:     auth.RoleOperator,
			Status:   1,
		},
		{
			ID:       3,
			Username: "user",
			Role:     auth.RoleUser,
			Status:   1,
		},
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "success",
		"data": users,
	})
}

// createUser 创建用户
func createUser(c *gin.Context) {
	var req UserRequest
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的请求参数",
		})
		return
	}
	
	// 验证角色是否有效
	if req.Role != auth.RoleAdmin && req.Role != auth.RoleOperator && req.Role != auth.RoleUser {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的用户角色",
		})
		return
	}
	
	// 检查密码是否提供
	if req.Password == "" {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "密码不能为空",
		})
		return
	}
	
	// 实际项目中应调用auth模块的CreateUser方法
	// 这里仅为示例
	newUser := auth.User{
		ID:       100, // 模拟ID生成
		Username: req.Username,
		Role:     req.Role,
		Status:   1,
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "用户创建成功",
		"data": newUser,
	})
}

// updateUser 更新用户
func updateUser(c *gin.Context) {
	var req UserRequest
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
			"msg":  "无效的用户ID",
		})
		return
	}
	
	// 验证角色是否有效
	if req.Role != auth.RoleAdmin && req.Role != auth.RoleOperator && req.Role != auth.RoleUser {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "无效的用户角色",
		})
		return
	}
	
	// 实际项目中应调用auth模块的UpdateUser方法
	// 这里仅为示例
	updatedUser := auth.User{
		ID:       req.ID,
		Username: req.Username,
		Role:     req.Role,
		Status:   req.Status,
	}
	
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "用户更新成功",
		"data": updatedUser,
	})
}

// deleteUser 删除用户
func deleteUser(c *gin.Context) {
	var req struct {
		ID int `json:"id" binding:"required"`
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
			"msg":  "无效的用户ID",
		})
		return
	}
	
	// 阻止删除admin用户
	if req.ID == 1 {
		c.JSON(http.StatusOK, gin.H{
			"code": -1,
			"msg":  "不能删除管理员账户",
		})
		return
	}
	
	// 实际项目中应调用auth模块的DeleteUser方法
	// 这里仅为示例
	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"msg":  "用户删除成功",
	})
} 