package web

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// SSLConfig SSL配置
type SSLConfig struct {
	Enabled bool   `json:"enabled"` // 是否启用SSL
	Type    string `json:"type"`    // SSL类型：self（自签名）、let（Let's Encrypt）、custom（自定义）
	Cert    string `json:"cert"`    // 证书路径
	Key     string `json:"key"`     // 密钥路径
}

// DatabaseConfig 数据库配置
type DatabaseConfig struct {
	Type     string `json:"type"`     // 数据库类型：mysql, mariadb, postgresql, none
	Name     string `json:"name"`     // 数据库名
	User     string `json:"user"`     // 数据库用户
	Password string `json:"password"` // 数据库密码
	Host     string `json:"host"`     // 数据库主机
	Port     int    `json:"port"`     // 数据库端口
	Charset  string `json:"charset"`  // 字符集
}

// WebsiteConfig 网站配置
type WebsiteConfig struct {
	ID          int            `json:"id"`          // 网站ID
	Name        string         `json:"name"`        // 网站名称
	Domain      string         `json:"domain"`      // 主域名
	Path        string         `json:"path"`        // 网站根目录
	PHPVersion  string         `json:"phpVersion"`  // PHP版本选择
	SSL         SSLConfig      `json:"ssl"`         // SSL配置
	Database    DatabaseConfig `json:"database"`    // 数据库配置
	Status      int            `json:"status"`      // 状态：0-停用，1-启用
	CreateTime  time.Time      `json:"createTime"`  // 创建时间
	UpdateTime  time.Time      `json:"updateTime"`  // 更新时间
	Description string         `json:"description"` // 描述
}

// 错误定义
var (
	ErrWebsiteNotFound     = errors.New("网站不存在")
	ErrWebsiteAlreadyExist = errors.New("网站已存在")
	ErrInvalidDomain       = errors.New("无效的域名")
	ErrInvalidPHPVersion   = errors.New("无效的PHP版本")
	ErrInvalidSSLType      = errors.New("无效的SSL类型")
	ErrInvalidOperation    = errors.New("无效的操作")
)

// 全局配置
var (
	WebsiteBaseDir = "/var/www"
	WebsiteConfDir = "/etc/nginx/conf.d"
	DataDir        = "/var/lib/panel/websites"
)

// 已部署的网站列表（内存缓存）
var websiteList = make(map[int]*WebsiteConfig)
var nextWebsiteID = 1

// Init 初始化网站管理模块
func Init() error {
	// 确保目录存在
	if err := os.MkdirAll(DataDir, 0755); err != nil {
		return err
	}
	
	// 加载网站配置
	return loadWebsiteConfigs()
}

// 加载保存的网站配置
func loadWebsiteConfigs() error {
	// 确保网站存储目录存在
	if err := os.MkdirAll(DataDir, 0755); err != nil {
		return err
	}
	
	files, err := ioutil.ReadDir(DataDir)
	if err != nil {
		return err
	}
	
	maxID := 0
	for _, file := range files {
		if file.IsDir() || !strings.HasSuffix(file.Name(), ".json") {
			continue
		}
		
		// 解析文件名中的网站ID
		idStr := strings.TrimSuffix(file.Name(), ".json")
		var id int
		fmt.Sscanf(idStr, "%d", &id)
		
		// 读取网站配置
		data, err := ioutil.ReadFile(filepath.Join(DataDir, file.Name()))
		if err != nil {
			fmt.Printf("读取网站配置失败: %s, 错误: %v\n", file.Name(), err)
			continue
		}
		
		var website WebsiteConfig
		if err := json.Unmarshal(data, &website); err != nil {
			fmt.Printf("解析网站配置失败: %s, 错误: %v\n", file.Name(), err)
			continue
		}
		
		websiteList[id] = &website
		
		// 记录最大ID
		if id > maxID {
			maxID = id
		}
	}
	
	// 设置下一个可用ID
	nextWebsiteID = maxID + 1
	
	return nil
}

// 保存网站配置到文件
func saveWebsiteConfig(website *WebsiteConfig) error {
	data, err := json.MarshalIndent(website, "", "  ")
	if err != nil {
		return err
	}
	
	// 确保目录存在
	if err := os.MkdirAll(DataDir, 0755); err != nil {
		return err
	}
	
	return ioutil.WriteFile(filepath.Join(DataDir, fmt.Sprintf("%d.json", website.ID)), data, 0644)
}

// GetAllWebsites 获取所有网站配置
func GetAllWebsites() []*WebsiteConfig {
	websites := make([]*WebsiteConfig, 0, len(websiteList))
	for _, website := range websiteList {
		websites = append(websites, website)
	}
	return websites
}

// GetWebsite 获取指定网站配置
func GetWebsite(id int) (*WebsiteConfig, error) {
	website, ok := websiteList[id]
	if !ok {
		return nil, ErrWebsiteNotFound
	}
	return website, nil
}

// CreateWebsite 创建新网站
func CreateWebsite(config WebsiteConfig) (*WebsiteConfig, error) {
	// 验证域名
	if config.Domain == "" {
		return nil, ErrInvalidDomain
	}
	
	// 检查域名是否已被使用
	for _, site := range websiteList {
		if site.Domain == config.Domain {
			return nil, ErrWebsiteAlreadyExist
		}
	}
	
	// 验证PHP版本
	if config.PHPVersion != "" && !isValidPHPVersion(config.PHPVersion) {
		return nil, ErrInvalidPHPVersion
	}
	
	// 设置网站ID
	config.ID = nextWebsiteID
	nextWebsiteID++
	
	// 设置创建时间
	config.CreateTime = time.Now()
	config.UpdateTime = time.Now()
	
	// 如果没有指定网站根目录，使用默认目录
	if config.Path == "" {
		config.Path = filepath.Join(WebsiteBaseDir, config.Domain)
	}
	
	// 保存网站配置
	websiteList[config.ID] = &config
	if err := saveWebsiteConfig(&config); err != nil {
		delete(websiteList, config.ID)
		return nil, err
	}
	
	// 部署网站
	if err := deployWebsite(&config); err != nil {
		// 部署失败，但配置已保存
		fmt.Printf("部署网站失败: %v\n", err)
	}
	
	return &config, nil
}

// UpdateWebsite 更新网站配置
func UpdateWebsite(id int, config WebsiteConfig) (*WebsiteConfig, error) {
	// 检查网站是否存在
	oldConfig, ok := websiteList[id]
	if !ok {
		return nil, ErrWebsiteNotFound
	}
	
	// 验证域名
	if config.Domain != oldConfig.Domain {
		// 如果域名变更，检查新域名是否已被使用
		for _, site := range websiteList {
			if site.ID != id && site.Domain == config.Domain {
				return nil, ErrWebsiteAlreadyExist
			}
		}
	}
	
	// 验证PHP版本
	if config.PHPVersion != "" && !isValidPHPVersion(config.PHPVersion) {
		return nil, ErrInvalidPHPVersion
	}
	
	// 保持原有ID
	config.ID = id
	
	// 更新时间
	config.CreateTime = oldConfig.CreateTime
	config.UpdateTime = time.Now()
	
	// 保存更新后的配置
	websiteList[id] = &config
	if err := saveWebsiteConfig(&config); err != nil {
		websiteList[id] = oldConfig // 恢复原配置
		return nil, err
	}
	
	// 重新部署网站
	if err := deployWebsite(&config); err != nil {
		fmt.Printf("重新部署网站失败: %v\n", err)
	}
	
	return &config, nil
}

// DeleteWebsite 删除网站
func DeleteWebsite(id int) error {
	// 检查网站是否存在
	website, ok := websiteList[id]
	if !ok {
		return ErrWebsiteNotFound
	}
	
	// 删除网站配置
	delete(websiteList, id)
	
	// 删除配置文件
	configFile := filepath.Join(DataDir, fmt.Sprintf("%d.json", id))
	if err := os.Remove(configFile); err != nil {
		if !os.IsNotExist(err) {
			websiteList[id] = website // 恢复配置
			return err
		}
	}
	
	// 执行网站卸载
	if err := undeployWebsite(website); err != nil {
		fmt.Printf("卸载网站失败: %v\n", err)
	}
	
	return nil
}

// ControlWebsite 控制网站状态（启用/停用）
func ControlWebsite(id int, enable bool) error {
	// 检查网站是否存在
	website, ok := websiteList[id]
	if !ok {
		return ErrWebsiteNotFound
	}
	
	// 更新状态
	if enable {
		website.Status = 1
	} else {
		website.Status = 0
	}
	
	// 保存配置
	if err := saveWebsiteConfig(website); err != nil {
		return err
	}
	
	// 应用配置
	if enable {
		// 启用网站配置
		if err := enableNginxConfig(website.Domain); err != nil {
			return err
		}
	} else {
		// 停用网站配置
		if err := disableNginxConfig(website.Domain); err != nil {
			return err
		}
	}
	
	return nil
}

// 验证PHP版本
func isValidPHPVersion(version string) bool {
	validVersions := []string{"5.6", "7.0", "7.1", "7.2", "7.3", "7.4", "8.0", "8.1", "8.2"}
	for _, v := range validVersions {
		if version == v {
			return true
		}
	}
	return false
}

// 部署网站
func deployWebsite(website *WebsiteConfig) error {
	// 创建网站根目录
	if err := os.MkdirAll(website.Path, 0755); err != nil {
		return err
	}
	
	// 创建Nginx配置
	if err := createNginxConfig(website); err != nil {
		return err
	}
	
	// 如果启用了数据库，创建数据库
	if website.Database.Type != "" && website.Database.Type != "none" {
		if err := createDatabase(website); err != nil {
			return err
		}
	}
	
	// 如果启用了SSL，配置SSL
	if website.SSL.Enabled {
		if err := configureSSL(website); err != nil {
			return err
		}
	}
	
	// 重新加载Nginx配置
	return reloadNginx()
}

// 卸载网站
func undeployWebsite(website *WebsiteConfig) error {
	// 删除Nginx配置
	nginxConfig := filepath.Join(WebsiteConfDir, website.Domain+".conf")
	if err := os.Remove(nginxConfig); err != nil {
		if !os.IsNotExist(err) {
			return err
		}
	}
	
	// 重新加载Nginx配置
	return reloadNginx()
}

// 创建Nginx配置文件
func createNginxConfig(website *WebsiteConfig) error {
	// 配置模板
	var configTemplate string
	if website.SSL.Enabled {
		// HTTPS配置
		configTemplate = `server {
    listen 80;
    server_name %s;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name %s;
    
    ssl_certificate %s;
    ssl_certificate_key %s;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    root %s;
    index index.html index.htm index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/var/run/php/php%s-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    access_log /var/log/nginx/%s-access.log;
    error_log /var/log/nginx/%s-error.log;
}
`
		configTemplate = fmt.Sprintf(configTemplate,
			website.Domain,
			website.Domain,
			website.SSL.Cert,
			website.SSL.Key,
			website.Path,
			strings.Replace(website.PHPVersion, ".", "", 1),
			website.Domain,
			website.Domain)
	} else {
		// HTTP配置
		configTemplate = `server {
    listen 80;
    server_name %s;
    
    root %s;
    index index.html index.htm index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/var/run/php/php%s-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    access_log /var/log/nginx/%s-access.log;
    error_log /var/log/nginx/%s-error.log;
}
`
		configTemplate = fmt.Sprintf(configTemplate,
			website.Domain,
			website.Path,
			strings.Replace(website.PHPVersion, ".", "", 1),
			website.Domain,
			website.Domain)
	}
	
	// 写入配置文件
	configPath := filepath.Join(WebsiteConfDir, website.Domain+".conf")
	return ioutil.WriteFile(configPath, []byte(configTemplate), 0644)
}

// 配置SSL
func configureSSL(website *WebsiteConfig) error {
	switch website.SSL.Type {
	case "self":
		// 生成自签名证书
		return generateSelfSignedCert(website)
	case "let":
		// 申请Let's Encrypt证书
		return applyLetsEncryptCert(website)
	case "custom":
		// 使用自定义证书，不需要额外处理
		return nil
	default:
		return ErrInvalidSSLType
	}
}

// 生成自签名证书
func generateSelfSignedCert(website *WebsiteConfig) error {
	// 创建证书目录
	certDir := filepath.Join("/etc/panel/certs", website.Domain)
	if err := os.MkdirAll(certDir, 0755); err != nil {
		return err
	}
	
	// 设置证书路径
	website.SSL.Cert = filepath.Join(certDir, "server.crt")
	website.SSL.Key = filepath.Join(certDir, "server.key")
	
	// 保存更新后的配置
	if err := saveWebsiteConfig(website); err != nil {
		return err
	}
	
	// 使用openssl生成自签名证书
	cmd := exec.Command("openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "365", "-nodes", "-x509",
		"-subj", fmt.Sprintf("/CN=%s", website.Domain),
		"-keyout", website.SSL.Key,
		"-out", website.SSL.Cert)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("生成自签名证书失败: %s\n", output)
		return err
	}
	
	return nil
}

// 申请Let's Encrypt证书
func applyLetsEncryptCert(website *WebsiteConfig) error {
	// 创建证书目录
	certDir := filepath.Join("/etc/panel/certs", website.Domain)
	if err := os.MkdirAll(certDir, 0755); err != nil {
		return err
	}
	
	// 设置证书路径
	website.SSL.Cert = filepath.Join(certDir, "fullchain.pem")
	website.SSL.Key = filepath.Join(certDir, "privkey.pem")
	
	// 保存更新后的配置
	if err := saveWebsiteConfig(website); err != nil {
		return err
	}
	
	// 使用certbot申请证书
	// 注意：这里假设已安装certbot
	cmd := exec.Command("certbot", "certonly", "--webroot",
		"-w", website.Path, 
		"-d", website.Domain,
		"--cert-path", website.SSL.Cert,
		"--key-path", website.SSL.Key,
		"--non-interactive", "--agree-tos", "-m", "admin@example.com")
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("申请Let's Encrypt证书失败: %s\n", output)
		return err
	}
	
	return nil
}

// 创建数据库
func createDatabase(website *WebsiteConfig) error {
	// 暂不实现，仅保留接口
	return nil
}

// 启用Nginx配置
func enableNginxConfig(domain string) error {
	// 在支持sites-enabled的系统上需要创建符号链接
	// 这里假设使用配置文件直接加载，所以不需要额外操作
	return reloadNginx()
}

// 停用Nginx配置
func disableNginxConfig(domain string) error {
	// 在支持sites-enabled的系统上需要删除符号链接
	// 这里假设使用配置文件直接加载，所以仅需重命名配置文件
	configPath := filepath.Join(WebsiteConfDir, domain+".conf")
	disabledPath := configPath + ".disabled"
	
	if err := os.Rename(configPath, disabledPath); err != nil {
		return err
	}
	
	return reloadNginx()
}

// 重新加载Nginx配置
func reloadNginx() error {
	cmd := exec.Command("nginx", "-s", "reload")
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("重载Nginx配置失败: %s\n", output)
		return err
	}
	return nil
} 