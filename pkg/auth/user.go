package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"
	
	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

// User roles
const (
	RoleAdmin    = "admin"
	RoleOperator = "operator"
	RoleUser     = "user"
)

// Common errors
var (
	ErrInvalidCredentials = errors.New("无效的用户名或密码")
	ErrUserNotFound       = errors.New("用户不存在")
	ErrUserAlreadyExists  = errors.New("用户已存在")
	ErrInvalidToken       = errors.New("无效的令牌")
	ErrTokenExpired       = errors.New("令牌已过期")
	ErrUserDisabled       = errors.New("用户已被禁用")
	ErrInvalidPassword    = errors.New("密码错误")
	ErrTokenInvalid       = errors.New("令牌无效或已过期")
	ErrUsernameExists     = errors.New("用户名已存在")
	ErrEmailExists        = errors.New("邮箱已被使用")
	ErrInvalidRole        = errors.New("无效的角色")
	ErrNoPermission       = errors.New("没有操作权限")
)

// User 用户信息
type User struct {
	ID          int    `json:"id"`
	Username    string `json:"username"`
	Password    string `json:"-"` // 密码不输出到JSON
	Salt        string `json:"-"` // 盐值不输出到JSON
	Role        string `json:"role"`
	Status      int    `json:"status"`
	LastLogin   int64  `json:"last_login"`
	CreateTime  int64  `json:"create_time"`
	Email       string `json:"email,omitempty"`
	Description string `json:"description,omitempty"`
}

// Token 用户令牌
type Token struct {
	Token      string    `json:"token"`
	UserID     int       `json:"userId"`
	ExpireTime time.Time `json:"expireTime"`
}

// 全局数据库连接
var db *sql.DB

// userTokenMap 存储用户token映射，实际项目中应该使用Redis等持久化存储
var userTokenMap = make(map[string]*User)

// 初始化数据库
func InitDB(dbPath string) error {
	var err error
	db, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		return err
	}
	
	// 创建用户表
	_, err = db.Exec(`
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password TEXT NOT NULL,
		email TEXT UNIQUE NOT NULL,
		role TEXT NOT NULL,
		last_login TIMESTAMP,
		create_time TIMESTAMP NOT NULL,
		status INTEGER NOT NULL DEFAULT 1
	)`)
	if err != nil {
		return err
	}
	
	// 创建令牌表
	_, err = db.Exec(`
	CREATE TABLE IF NOT EXISTS tokens (
		token TEXT PRIMARY KEY,
		user_id INTEGER NOT NULL,
		expire_time TIMESTAMP NOT NULL,
		FOREIGN KEY (user_id) REFERENCES users(id)
	)`)
	if err != nil {
		return err
	}
	
	// 检查是否需要创建管理员账号
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM users WHERE role='admin'").Scan(&count)
	if err != nil {
		return err
	}
	
	if count == 0 {
		// 创建默认管理员账号
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		
		_, err = db.Exec(`
		INSERT INTO users (username, password, email, role, create_time, status)
		VALUES (?, ?, ?, ?, ?, ?)`,
			"admin", string(hashedPassword), "admin@example.com", "admin", time.Now(), 1)
		if err != nil {
			return err
		}
	}
	
	return nil
}

// Login 用户登录
func Login(username, password string) (*User, string, error) {
	var user User
	err := db.QueryRow(`
	SELECT id, username, password, email, role, last_login, create_time, status
	FROM users WHERE username=?`, username).Scan(
		&user.ID, &user.Username, &user.Password, &user.Email, 
		&user.Role, &user.LastLogin, &user.CreateTime, &user.Status)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, "", ErrUserNotFound
		}
		return nil, "", err
	}
	
	// 检查用户状态
	if user.Status != 1 {
		return nil, "", ErrUserDisabled
	}
	
	// 验证密码
	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password))
	if err != nil {
		return nil, "", ErrInvalidPassword
	}
	
	// 更新最后登录时间
	_, err = db.Exec("UPDATE users SET last_login=? WHERE id=?", time.Now(), user.ID)
	if err != nil {
		return nil, "", err
	}
	
	// 生成新令牌
	tokenStr, err := generateToken(user.ID)
	if err != nil {
		return nil, "", err
	}
	
	return &user, tokenStr, nil
}

// 生成令牌
func generateToken(userID int) (string, error) {
	// 生成随机令牌
	b := make([]byte, 32)
	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}
	
	// 计算令牌哈希
	h := sha256.New()
	h.Write(b)
	h.Write([]byte(fmt.Sprintf("%d", userID)))
	h.Write([]byte(time.Now().String()))
	token := hex.EncodeToString(h.Sum(nil))
	
	// 设置过期时间（24小时）
	expireTime := time.Now().Add(24 * time.Hour)
	
	// 清除该用户之前的令牌
	_, err = db.Exec("DELETE FROM tokens WHERE user_id=?", userID)
	if err != nil {
		return "", err
	}
	
	// 保存令牌到数据库
	_, err = db.Exec("INSERT INTO tokens (token, user_id, expire_time) VALUES (?, ?, ?)",
		token, userID, expireTime)
	if err != nil {
		return "", err
	}
	
	return token, nil
}

// ValidateToken 验证令牌
func ValidateToken(tokenStr string) (*User, error) {
	var userID int
	var expireTime time.Time
	
	err := db.QueryRow("SELECT user_id, expire_time FROM tokens WHERE token=?", tokenStr).Scan(&userID, &expireTime)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrTokenInvalid
		}
		return nil, err
	}
	
	// 检查令牌是否过期
	if time.Now().After(expireTime) {
		// 删除过期令牌
		_, _ = db.Exec("DELETE FROM tokens WHERE token=?", tokenStr)
		return nil, ErrTokenExpired
	}
	
	// 获取用户信息
	var user User
	err = db.QueryRow(`
	SELECT id, username, password, email, role, last_login, create_time, status
	FROM users WHERE id=?`, userID).Scan(
		&user.ID, &user.Username, &user.Password, &user.Email, 
		&user.Role, &user.LastLogin, &user.CreateTime, &user.Status)
	
	if err != nil {
		return nil, err
	}
	
	// 检查用户状态
	if user.Status != 1 {
		return nil, ErrUserDisabled
	}
	
	return &user, nil
}

// CreateUser 创建新用户
func CreateUser(username, password, email, role string) error {
	// 验证角色是否有效
	if role != "admin" && role != "operator" && role != "user" {
		return ErrInvalidRole
	}
	
	// 检查用户名是否已存在
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM users WHERE username=?", username).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return ErrUsernameExists
	}
	
	// 检查邮箱是否已存在
	err = db.QueryRow("SELECT COUNT(*) FROM users WHERE email=?", email).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return ErrEmailExists
	}
	
	// 加密密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	
	// 创建用户
	_, err = db.Exec(`
	INSERT INTO users (username, password, email, role, create_time, status)
	VALUES (?, ?, ?, ?, ?, ?)`,
		username, string(hashedPassword), email, role, time.Now(), 1)
	
	return err
}

// UpdateUser 更新用户信息
func UpdateUser(id int, email, role string, status int) error {
	// 验证角色是否有效
	if role != "" && role != "admin" && role != "operator" && role != "user" {
		return ErrInvalidRole
	}
	
	// 检查邮箱是否已被其他用户使用
	if email != "" {
		var count int
		err := db.QueryRow("SELECT COUNT(*) FROM users WHERE email=? AND id!=?", email, id).Scan(&count)
		if err != nil {
			return err
		}
		if count > 0 {
			return ErrEmailExists
		}
	}
	
	// 更新用户信息
	var query string
	var args []interface{}
	
	if email != "" && role != "" {
		query = "UPDATE users SET email=?, role=?, status=? WHERE id=?"
		args = []interface{}{email, role, status, id}
	} else if email != "" {
		query = "UPDATE users SET email=?, status=? WHERE id=?"
		args = []interface{}{email, status, id}
	} else if role != "" {
		query = "UPDATE users SET role=?, status=? WHERE id=?"
		args = []interface{}{role, status, id}
	} else {
		query = "UPDATE users SET status=? WHERE id=?"
		args = []interface{}{status, id}
	}
	
	_, err := db.Exec(query, args...)
	return err
}

// ChangePassword 修改密码
func ChangePassword(id int, oldPassword, newPassword string) error {
	// 获取当前密码
	var currentPassword string
	err := db.QueryRow("SELECT password FROM users WHERE id=?", id).Scan(&currentPassword)
	if err != nil {
		if err == sql.ErrNoRows {
			return ErrUserNotFound
		}
		return err
	}
	
	// 验证旧密码
	err = bcrypt.CompareHashAndPassword([]byte(currentPassword), []byte(oldPassword))
	if err != nil {
		return ErrInvalidPassword
	}
	
	// 加密新密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	
	// 更新密码
	_, err = db.Exec("UPDATE users SET password=? WHERE id=?", string(hashedPassword), id)
	if err != nil {
		return err
	}
	
	// 使所有令牌失效
	_, err = db.Exec("DELETE FROM tokens WHERE user_id=?", id)
	return err
}

// GetUsers 获取用户列表
func GetUsers() ([]User, error) {
	rows, err := db.Query(`
	SELECT id, username, email, role, last_login, create_time, status
	FROM users ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var users []User
	for rows.Next() {
		var user User
		err := rows.Scan(
			&user.ID, &user.Username, &user.Email, &user.Role,
			&user.LastLogin, &user.CreateTime, &user.Status)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	
	return users, nil
}

// GetUser 获取指定用户信息
func GetUser(id int) (*User, error) {
	var user User
	err := db.QueryRow(`
	SELECT id, username, email, role, last_login, create_time, status
	FROM users WHERE id=?`, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.Role,
		&user.LastLogin, &user.CreateTime, &user.Status)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	
	return &user, nil
}

// DeleteUser 删除用户
func DeleteUser(id int) error {
	// 先删除令牌
	_, err := db.Exec("DELETE FROM tokens WHERE user_id=?", id)
	if err != nil {
		return err
	}
	
	// 删除用户
	result, err := db.Exec("DELETE FROM users WHERE id=?", id)
	if err != nil {
		return err
	}
	
	// 检查是否删除成功
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	
	if affected == 0 {
		return ErrUserNotFound
	}
	
	return nil
}

// Logout 用户登出
func Logout(tokenStr string) error {
	_, err := db.Exec("DELETE FROM tokens WHERE token=?", tokenStr)
	return err
}

// GetUserFromToken 从令牌获取用户信息
func GetUserFromToken(token string) *User {
	return userTokenMap[token]
}

// GenerateToken 生成用户令牌
func GenerateToken(user *User) string {
	// 这里使用简单的时间戳+用户名生成token
	// 实际项目中应该使用JWT等更安全的方式
	token := time.Now().Format("20060102150405") + "-" + user.Username
	
	// 存储token和用户信息的映射
	userTokenMap[token] = user
	
	return token
} 