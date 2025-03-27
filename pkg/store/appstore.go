package store

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// AppMeta 应用元数据
type AppMeta struct {
	ID          string   `json:"id"`           // 应用唯一标识
	Name        string   `json:"name"`         // 应用名称
	Version     string   `json:"version"`      // 应用版本
	Description string   `json:"description"`  // 应用描述
	Author      string   `json:"author"`       // 作者
	Category    string   `json:"category"`     // 分类
	Icon        string   `json:"icon"`         // 图标URL
	Tags        []string `json:"tags"`         // 标签
	Registry    string   `json:"registry"`     // 来源仓库
	ScriptURL   string   `json:"scriptUrl"`    // 安装脚本URL
	Size        int64    `json:"size"`         // 估计安装大小(字节)
}

// App 应用信息
type App struct {
	Meta       AppMeta   `json:"meta"`        // 应用元数据
	Status     string    `json:"status"`      // 状态：notinstalled, installing, installed, failed
	InstallDir string    `json:"installDir"`  // 安装目录
	InstallAt  time.Time `json:"installAt"`   // 安装时间
	Config     any       `json:"config"`      // 配置信息
}

// AppRegistry 应用仓库
type AppRegistry struct {
	Name        string `json:"name"`        // 仓库名称
	URL         string `json:"url"`         // 仓库URL
	Description string `json:"description"` // 仓库描述
	PublicKey   string `json:"publicKey"`   // 验证公钥
}

// 错误定义
var (
	ErrAppNotFound       = errors.New("应用不存在")
	ErrAppAlreadyExists  = errors.New("应用已存在")
	ErrSignatureInvalid  = errors.New("脚本签名无效")
	ErrScriptDownloadFail = errors.New("脚本下载失败")
	ErrScriptExecFail     = errors.New("脚本执行失败")
)

// 全局变量
var (
	// 应用安装目录
	AppBaseDir = "/opt/panel/apps"
	
	// 应用数据目录
	AppDataDir = "/var/lib/panel/appdata"
	
	// 已安装应用列表
	installedApps = make(map[string]*App)
	
	// 已注册的应用仓库
	registries = []AppRegistry{
		{
			Name:        "官方仓库",
			URL:         "https://registry.yourpanel.com",
			Description: "轻量面板官方应用仓库",
			PublicKey:   "base64encodedpublickey", // 实际使用时应替换为真实的公钥
		},
	}
)

// Init 初始化应用商店
func Init() error {
	// 确保目录存在
	if err := os.MkdirAll(AppBaseDir, 0755); err != nil {
		return err
	}
	
	if err := os.MkdirAll(AppDataDir, 0755); err != nil {
		return err
	}
	
	// 加载已安装的应用
	return loadInstalledApps()
}

// 加载已安装的应用信息
func loadInstalledApps() error {
	appsDir := filepath.Join(AppDataDir, "installed")
	if err := os.MkdirAll(appsDir, 0755); err != nil {
		return err
	}
	
	entries, err := ioutil.ReadDir(appsDir)
	if err != nil {
		return err
	}
	
	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) == ".json" {
			appID := entry.Name()[:len(entry.Name())-5] // 移除.json后缀
			
			data, err := ioutil.ReadFile(filepath.Join(appsDir, entry.Name()))
			if err != nil {
				fmt.Printf("读取应用信息失败: %s, 错误: %v\n", appID, err)
				continue
			}
			
			var app App
			if err := json.Unmarshal(data, &app); err != nil {
				fmt.Printf("解析应用信息失败: %s, 错误: %v\n", appID, err)
				continue
			}
			
			installedApps[appID] = &app
		}
	}
	
	return nil
}

// GetRegistries 获取所有应用仓库
func GetRegistries() []AppRegistry {
	return registries
}

// AddRegistry 添加应用仓库
func AddRegistry(registry AppRegistry) {
	// 检查重复
	for i, reg := range registries {
		if reg.URL == registry.URL {
			// 更新已有仓库
			registries[i] = registry
			return
		}
	}
	
	// 添加新仓库
	registries = append(registries, registry)
}

// RemoveRegistry 移除应用仓库
func RemoveRegistry(url string) {
	newRegistries := make([]AppRegistry, 0, len(registries))
	for _, reg := range registries {
		if reg.URL != url {
			newRegistries = append(newRegistries, reg)
		}
	}
	registries = newRegistries
}

// FetchAppList 从仓库获取应用列表
func FetchAppList() ([]AppMeta, error) {
	// TODO: 实际实现应连接到仓库API获取应用列表
	// 以下是演示数据
	demoApps := []AppMeta{
		{
			ID:          "nginx",
			Name:        "Nginx Web服务器",
			Version:     "1.24.0",
			Description: "高性能Web服务器和反向代理",
			Author:      "Nginx, Inc.",
			Category:    "Web服务器",
			Icon:        "https://www.nginx.com/wp-content/uploads/2020/05/NGINX-product-icon.svg",
			Tags:        []string{"web", "http", "反向代理", "负载均衡"},
			Registry:    "官方仓库",
			ScriptURL:   "https://registry.yourpanel.com/scripts/nginx.sh",
			Size:        2 * 1024 * 1024, // 2MB
		},
		{
			ID:          "mysql",
			Name:        "MySQL数据库",
			Version:     "8.0.33",
			Description: "流行的开源关系型数据库",
			Author:      "Oracle Corporation",
			Category:    "数据库",
			Icon:        "https://www.mysql.com/common/logos/mysql-logo.svg",
			Tags:        []string{"数据库", "关系型", "SQL"},
			Registry:    "官方仓库",
			ScriptURL:   "https://registry.yourpanel.com/scripts/mysql.sh",
			Size:        180 * 1024 * 1024, // 180MB
		},
		{
			ID:          "php",
			Name:        "PHP运行环境",
			Version:     "8.2.8",
			Description: "PHP语言运行环境，包含常用扩展",
			Author:      "PHP Group",
			Category:    "语言运行时",
			Icon:        "https://www.php.net/images/logos/new-php-logo.svg",
			Tags:        []string{"php", "运行时", "语言"},
			Registry:    "官方仓库",
			ScriptURL:   "https://registry.yourpanel.com/scripts/php.sh",
			Size:        25 * 1024 * 1024, // 25MB
		},
	}
	
	return demoApps, nil
}

// GetInstalledApps 获取已安装的应用
func GetInstalledApps() []*App {
	apps := make([]*App, 0, len(installedApps))
	for _, app := range installedApps {
		apps = append(apps, app)
	}
	return apps
}

// GetApp 获取指定应用信息
func GetApp(id string) (*App, error) {
	app, ok := installedApps[id]
	if !ok {
		return nil, ErrAppNotFound
	}
	return app, nil
}

// InstallApp 安装应用
func InstallApp(appMeta AppMeta) error {
	// 检查是否已安装
	if _, ok := installedApps[appMeta.ID]; ok {
		return ErrAppAlreadyExists
	}
	
	// 创建应用实例
	app := &App{
		Meta:       appMeta,
		Status:     "installing",
		InstallDir: filepath.Join(AppBaseDir, appMeta.ID),
		InstallAt:  time.Now(),
	}
	
	// 保存应用信息
	if err := saveAppInfo(app); err != nil {
		return err
	}
	
	// 将应用添加到已安装列表
	installedApps[appMeta.ID] = app
	
	// 异步执行安装
	go runInstallScript(app)
	
	return nil
}

// 保存应用信息到文件
func saveAppInfo(app *App) error {
	appsDir := filepath.Join(AppDataDir, "installed")
	if err := os.MkdirAll(appsDir, 0755); err != nil {
		return err
	}
	
	data, err := json.MarshalIndent(app, "", "  ")
	if err != nil {
		return err
	}
	
	return ioutil.WriteFile(filepath.Join(appsDir, app.Meta.ID+".json"), data, 0644)
}

// 执行安装脚本
func runInstallScript(app *App) {
	defer func() {
		// 保存最终状态
		saveAppInfo(app)
	}()
	
	// 确保安装目录存在
	if err := os.MkdirAll(app.InstallDir, 0755); err != nil {
		app.Status = "failed"
		fmt.Printf("创建安装目录失败: %v\n", err)
		return
	}
	
	// 下载脚本
	scriptPath := filepath.Join(os.TempDir(), fmt.Sprintf("install_%s.sh", app.Meta.ID))
	
	// TODO: 实际实现应当下载脚本并验证签名
	// 以下是模拟脚本
	scriptContent := `#!/bin/bash
echo "正在安装 ${1}..."
mkdir -p ${2}/bin
echo '#!/bin/bash
echo "这是 ${1} 应用"' > ${2}/bin/app
chmod +x ${2}/bin/app
echo "安装完成!"
`
	
	if err := ioutil.WriteFile(scriptPath, []byte(scriptContent), 0755); err != nil {
		app.Status = "failed"
		fmt.Printf("保存安装脚本失败: %v\n", err)
		return
	}
	
	// 验证脚本签名
	// TODO: 实现真正的签名验证
	// verifySignature(scriptPath, app.Meta.Registry)
	
	// 执行安装脚本
	cmd := exec.Command(scriptPath, app.Meta.ID, app.InstallDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		app.Status = "failed"
		fmt.Printf("执行安装脚本失败: %v\n", err)
		fmt.Printf("输出: %s\n", output)
		return
	}
	
	// 安装成功
	app.Status = "installed"
	fmt.Printf("应用 %s 安装成功\n", app.Meta.ID)
}

// UninstallApp 卸载应用
func UninstallApp(id string) error {
	// 检查应用是否存在
	app, ok := installedApps[id]
	if !ok {
		return ErrAppNotFound
	}
	
	// 执行卸载操作
	// TODO: 实现卸载脚本执行
	
	// 删除安装目录
	if err := os.RemoveAll(app.InstallDir); err != nil {
		return err
	}
	
	// 删除应用信息文件
	appFile := filepath.Join(AppDataDir, "installed", id+".json")
	if err := os.Remove(appFile); err != nil && !os.IsNotExist(err) {
		return err
	}
	
	// 从已安装列表中移除
	delete(installedApps, id)
	
	return nil
}

// 验证脚本签名
func verifySignature(scriptPath string, registryName string) (bool, error) {
	// 寻找对应仓库
	var publicKey ed25519.PublicKey
	for _, reg := range registries {
		if reg.Name == registryName {
			// 解码公钥
			keyBytes, err := base64.StdEncoding.DecodeString(reg.PublicKey)
			if err != nil {
				return false, err
			}
			publicKey = keyBytes
			break
		}
	}
	
	if publicKey == nil {
		return false, errors.New("找不到仓库公钥")
	}
	
	// 读取脚本内容
	_, err := ioutil.ReadFile(scriptPath)
	if err != nil {
		return false, err
	}
	
	// TODO: 实现真正的签名验证
	// 1. 分离脚本内容和签名
	// 2. 使用公钥验证签名
	
	// 这里仅做示例
	return true, nil
}

// installDockerApp 安装Docker应用
func installDockerApp(app AppMeta, installPath string) error {
	// 模拟通过Docker安装应用
	fmt.Printf("安装Docker应用 %s 到 %s\n", app.Name, installPath)
	
	// 实际项目中这里应该执行Docker pull/run等命令
	// 这里模拟一个安装过程
	time.Sleep(500 * time.Millisecond)
	
	return nil
} 