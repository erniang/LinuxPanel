package core

import (
	"io/ioutil"
	"os"

	"gopkg.in/yaml.v3"
)

// Config 存储面板的核心配置信息
type Config struct {
	Port int `yaml:"port"` // 服务端口
	SSL struct {
		Enabled bool   `yaml:"enabled"` // 是否启用SSL
		Cert    string `yaml:"cert"`    // 证书路径或"auto"表示自动申请
		Key     string `yaml:"key"`     // 私钥路径
	} `yaml:"ssl"`
	Database struct {
		Path string `yaml:"path"` // SQLite数据库路径
	} `yaml:"database"`
	LogPath  string `yaml:"log_path"`  // 日志路径
	DataPath string `yaml:"data_path"` // 数据存储路径
}

// DefaultConfig 返回默认配置
func DefaultConfig() *Config {
	cfg := &Config{
		Port:     8080,
		LogPath:  "/var/log/panel",
		DataPath: "/var/lib/panel",
	}
	
	cfg.SSL.Enabled = false
	cfg.SSL.Cert = "auto"
	
	cfg.Database.Path = "/var/lib/panel/panel.db"
	
	return cfg
}

// LoadConfig 从指定路径加载配置文件
func LoadConfig(path string) (*Config, error) {
	cfg := DefaultConfig()
	
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