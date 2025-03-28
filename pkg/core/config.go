package core

import (
	"io/ioutil"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config 系统配置
type Config struct {
	// 版本信息
	Version string

	// 数据库配置
	DBType string // sqlite, mysql
	DBPath string // SQLite数据库文件路径
	DBHost string // MySQL主机
	DBPort int    // MySQL端口
	DBUser string // MySQL用户名
	DBPass string // MySQL密码
	DBName string // MySQL数据库名

	// 服务配置
	Port            int    // HTTP服务端口
	WorkDir         string // 工作目录
	DataDir         string // 数据存储目录
	LogDir          string // 日志目录
	TempDir         string // 临时文件目录
	AllowIPs        string // 允许访问的IP，多个IP用逗号分隔，为空表示允许所有IP
	EnableLocalAuth bool   // 是否启用本地认证
	JWTSecret       string // JWT密钥
}

// NewConfig 创建默认配置
func NewConfig() *Config {
	// 获取当前工作目录
	workDir, err := os.Getwd()
	if err != nil {
		workDir = "."
	}

	// 默认配置
	config := &Config{
		Version:         "1.0.0",
		DBType:          "sqlite",
		DBPath:          filepath.Join(workDir, "data", "linuxpanel.db"),
		Port:            8080,
		WorkDir:         workDir,
		DataDir:         filepath.Join(workDir, "data"),
		LogDir:          filepath.Join(workDir, "logs"),
		TempDir:         filepath.Join(workDir, "tmp"),
		EnableLocalAuth: true,
		JWTSecret:       "linuxpanel_default_secret",
	}

	// 创建必要的目录
	os.MkdirAll(config.DataDir, 0755)
	os.MkdirAll(config.LogDir, 0755)
	os.MkdirAll(config.TempDir, 0755)

	return config
}

// LoadConfig 从指定路径加载配置文件
func LoadConfig(path string) (*Config, error) {
	cfg := NewConfig()

	// 检查文件是否存在
	_, err := os.Stat(path)
	if os.IsNotExist(err) {
		// 文件不存在，创建默认配置
		data, err := yaml.Marshal(cfg)
		if err != nil {
			return nil, err
		}

		if err := ioutil.WriteFile(path, data, 0644); err != nil {
			return nil, err
		}

		return cfg, nil
	}

	// 读取现有配置
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}

	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	return cfg, nil
}
