package filemanager

import (
	"errors"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// FileInfo 表示文件或目录的信息
type FileInfo struct {
	Name       string    `json:"name"`       // 文件名
	Path       string    `json:"path"`       // 文件路径
	Size       int64     `json:"size"`       // 文件大小(字节)
	Mode       string    `json:"mode"`       // 文件权限
	IsDir      bool      `json:"isDir"`      // 是否是目录
	ModTime    time.Time `json:"modTime"`    // 修改时间
	Owner      string    `json:"owner"`      // 所有者
	Group      string    `json:"group"`      // 用户组
	Permission string    `json:"permission"` // 权限字符串
}

// 安全目录限制
var (
	ErrPathOutsideSafeRoot = errors.New("请求的路径超出安全根目录")
	ErrPathNotFound        = errors.New("文件或目录不存在")
	ErrReadPermission      = errors.New("没有读取权限")
	ErrWritePermission     = errors.New("没有写入权限")
	
	SafeRoots = []string{
		"/var/www",
		"/home",
		"/data",
		"/www",
		"/opt",
	}
)

// IsPathSafe 导出版本的路径安全检查函数
func IsPathSafe(path string) bool {
	return isPathSafe(path)
}

// 检查路径是否在安全根目录内
func isPathSafe(path string) bool {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return false
	}
	
	for _, root := range SafeRoots {
		if strings.HasPrefix(absPath, root) {
			return true
		}
	}
	
	return false
}

// ListDirectory 列出目录内容
func ListDirectory(path string) ([]FileInfo, error) {
	// 安全检查
	if !isPathSafe(path) {
		return nil, ErrPathOutsideSafeRoot
	}
	
	// 读取目录
	entries, err := ioutil.ReadDir(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrPathNotFound
		}
		if os.IsPermission(err) {
			return nil, ErrReadPermission
		}
		return nil, err
	}
	
	// 转换信息
	result := make([]FileInfo, 0, len(entries))
	for _, entry := range entries {
		fileInfo := FileInfo{
			Name:       entry.Name(),
			Path:       filepath.Join(path, entry.Name()),
			Size:       entry.Size(),
			Mode:       entry.Mode().String(),
			IsDir:      entry.IsDir(),
			ModTime:    entry.ModTime(),
			Permission: entry.Mode().String(),
		}
		
		// 获取所有者和组信息（在Windows上会失败，但这个面板主要针对Linux）
		// TODO: 使用syscall获取uid和gid，并转换为用户名和组名
		
		result = append(result, fileInfo)
	}
	
	// 排序：目录在前，文件在后，按名称排序
	sort.Slice(result, func(i, j int) bool {
		if result[i].IsDir && !result[j].IsDir {
			return true
		}
		if !result[i].IsDir && result[j].IsDir {
			return false
		}
		return result[i].Name < result[j].Name
	})
	
	return result, nil
}

// ReadFile 读取文件内容
func ReadFile(path string) ([]byte, error) {
	// 安全检查
	if !isPathSafe(path) {
		return nil, ErrPathOutsideSafeRoot
	}
	
	// 读取文件
	data, err := ioutil.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrPathNotFound
		}
		if os.IsPermission(err) {
			return nil, ErrReadPermission
		}
		return nil, err
	}
	
	return data, nil
}

// WriteFile 写入文件内容
func WriteFile(path string, data []byte) error {
	// 安全检查
	if !isPathSafe(path) {
		return ErrPathOutsideSafeRoot
	}
	
	// 确保目录存在
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	
	// 写入文件
	err := ioutil.WriteFile(path, data, 0644)
	if err != nil {
		if os.IsPermission(err) {
			return ErrWritePermission
		}
		return err
	}
	
	return nil
}

// DeleteFile 删除文件或目录
func DeleteFile(path string) error {
	// 安全检查
	if !isPathSafe(path) {
		return ErrPathOutsideSafeRoot
	}
	
	// 删除文件或目录
	err := os.RemoveAll(path)
	if err != nil {
		if os.IsNotExist(err) {
			return ErrPathNotFound
		}
		if os.IsPermission(err) {
			return ErrWritePermission
		}
		return err
	}
	
	return nil
}

// CreateDirectory 创建目录
func CreateDirectory(path string) error {
	// 安全检查
	if !isPathSafe(path) {
		return ErrPathOutsideSafeRoot
	}
	
	// 创建目录
	err := os.MkdirAll(path, 0755)
	if err != nil {
		if os.IsPermission(err) {
			return ErrWritePermission
		}
		return err
	}
	
	return nil
}

// CopyFile 复制文件或目录
func CopyFile(src, dst string) error {
	// 安全检查
	if !isPathSafe(src) || !isPathSafe(dst) {
		return ErrPathOutsideSafeRoot
	}
	
	// 获取源文件信息
	srcInfo, err := os.Stat(src)
	if err != nil {
		if os.IsNotExist(err) {
			return ErrPathNotFound
		}
		return err
	}
	
	// 根据源文件类型处理
	if srcInfo.IsDir() {
		return copyDir(src, dst)
	}
	
	return copyFileContents(src, dst)
}

// 复制目录
func copyDir(src, dst string) error {
	// 创建目标目录
	if err := os.MkdirAll(dst, 0755); err != nil {
		return err
	}
	
	// 读取源目录
	entries, err := ioutil.ReadDir(src)
	if err != nil {
		return err
	}
	
	// 递归复制内容
	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())
		
		if entry.IsDir() {
			if err := copyDir(srcPath, dstPath); err != nil {
				return err
			}
		} else {
			if err := copyFileContents(srcPath, dstPath); err != nil {
				return err
			}
		}
	}
	
	return nil
}

// 复制文件内容
func copyFileContents(src, dst string) error {
	// 打开源文件
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()
	
	// 创建目标文件
	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()
	
	// 复制内容
	_, err = io.Copy(dstFile, srcFile)
	return err
} 