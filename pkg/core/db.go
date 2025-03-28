package core

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

var db *sql.DB

// InitDB 初始化数据库连接
func InitDB(config *Config) error {
	// 确保数据目录存在
	dataDir := filepath.Dir(config.DBPath)
	if _, err := os.Stat(dataDir); os.IsNotExist(err) {
		if err := os.MkdirAll(dataDir, 0755); err != nil {
			return fmt.Errorf("创建数据目录失败: %v", err)
		}
	}

	// 根据配置选择数据库类型
	var err error
	switch config.DBType {
	case "sqlite":
		// 连接SQLite数据库
		db, err = sql.Open("sqlite3", config.DBPath)
		if err != nil {
			return fmt.Errorf("连接SQLite数据库失败: %v", err)
		}

		// 测试连接
		if err := db.Ping(); err != nil {
			return fmt.Errorf("SQLite数据库连接测试失败: %v", err)
		}

		// 初始化数据库表
		if err := initSQLiteTables(); err != nil {
			return fmt.Errorf("初始化SQLite表结构失败: %v", err)
		}

	default:
		return fmt.Errorf("不支持的数据库类型: %s", config.DBType)
	}

	return nil
}

// GetDB 获取数据库连接
func GetDB() *sql.DB {
	return db
}

// CloseDB 关闭数据库连接
func CloseDB() error {
	if db != nil {
		return db.Close()
	}
	return nil
}

// 初始化SQLite数据库表
func initSQLiteTables() error {
	// 用户表
	_, err := db.Exec(`
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT NOT NULL UNIQUE,
		password TEXT NOT NULL,
		role TEXT NOT NULL DEFAULT 'user',
		status INTEGER NOT NULL DEFAULT 1,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)
	`)
	if err != nil {
		return err
	}

	// 网站表
	_, err = db.Exec(`
	CREATE TABLE IF NOT EXISTS websites (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		domain TEXT NOT NULL,
		port INTEGER NOT NULL,
		path TEXT NOT NULL,
		type TEXT NOT NULL,
		status INTEGER NOT NULL DEFAULT 1,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)
	`)
	if err != nil {
		return err
	}

	// 数据库表
	_, err = db.Exec(`
	CREATE TABLE IF NOT EXISTS databases (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL UNIQUE,
		username TEXT NOT NULL,
		password TEXT NOT NULL,
		type TEXT NOT NULL DEFAULT 'sqlite',
		status INTEGER NOT NULL DEFAULT 1,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)
	`)
	if err != nil {
		return err
	}

	// 应用商店表
	_, err = db.Exec(`
	CREATE TABLE IF NOT EXISTS apps (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		description TEXT,
		version TEXT NOT NULL,
		status INTEGER NOT NULL DEFAULT 1,
		installed INTEGER NOT NULL DEFAULT 0,
		install_path TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)
	`)
	if err != nil {
		return err
	}

	// 系统设置表
	_, err = db.Exec(`
	CREATE TABLE IF NOT EXISTS settings (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key TEXT NOT NULL UNIQUE,
		value TEXT NOT NULL,
		description TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)
	`)
	if err != nil {
		return err
	}

	// 检查是否有默认管理员账户，如果没有，创建一个
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM users WHERE role = 'admin'").Scan(&count)
	if err != nil {
		return err
	}

	if count == 0 {
		// 创建默认管理员账户 (admin/admin123)
		_, err = db.Exec("INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
			"admin",
			"$2a$10$ORRhMgJMMl0ZYXXhe/Ygm.yC.ZRGynAL5HU9I5DrBEzK8M2OXQksO", // 使用bcrypt加密的"admin123"
			"admin")
		if err != nil {
			return err
		}
	}

	return nil
}
