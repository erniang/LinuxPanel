package common

import (
	"net/http"
	"strings"
	
	"github.com/gin-gonic/gin"
	"github.com/erniang/LinuxPanel/pkg/auth"
)

// AuthMiddleware 认证中间件，验证用户是否登录
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		
		// 从Authorization头中获取token
		if token == "" {
			// 也可以从cookie中获取
			tokenCookie, _ := c.Cookie("token")
			token = tokenCookie
		}
		
		// 移除Bearer前缀（如果有）
		token = strings.TrimPrefix(token, "Bearer ")
		
		// 验证token
		if token == "" {
			c.JSON(http.StatusOK, gin.H{
				"code": 401,
				"msg":  "未授权，请先登录",
			})
			c.Abort()
			return
		}
		
		// 获取用户信息并存储到上下文
		user := auth.GetUserFromToken(token)
		c.Set("user", user)
		
		c.Next()
	}
}

// AdminOnly 仅管理员可访问
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusOK, gin.H{
				"code": 401,
				"msg":  "未授权，请先登录",
			})
			c.Abort()
			return
		}
		
		// 转换为用户类型
		u, ok := user.(*auth.User)
		if !ok || u.Role != auth.RoleAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code": 403,
				"msg":  "权限不足，需要管理员权限",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// OperatorOnly 仅运维或管理员可访问
func OperatorOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusOK, gin.H{
				"code": 401,
				"msg":  "未授权，请先登录",
			})
			c.Abort()
			return
		}
		
		// 转换为用户类型
		u, ok := user.(*auth.User)
		if !ok || (u.Role != auth.RoleAdmin && u.Role != auth.RoleOperator) {
			c.JSON(http.StatusOK, gin.H{
				"code": 403,
				"msg":  "权限不足，需要运维或管理员权限",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
} 