# LinuxPanel 开发指南

本文档面向希望参与LinuxPanel开发的开发者，提供了项目结构、技术栈、开发环境搭建和贡献指南等信息。

## 目录

- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [开发环境搭建](#开发环境搭建)
- [编码规范](#编码规范)
- [API文档](#api文档)
- [前端开发](#前端开发)
- [后端开发](#后端开发)
- [测试指南](#测试指南)
- [提交代码](#提交代码)
- [版本发布流程](#版本发布流程)

## 技术栈

LinuxPanel采用现代化的技术栈，主要包括：

### 后端

- **Go语言**: 核心语言, v1.18+
- **Gin**: HTTP框架
- **GORM**: ORM库
- **JWT**: 认证
- **gopsutil**: 系统信息获取
- **yaml**: 配置文件处理

### 前端

- **Vue 3**: 前端框架
- **Vite**: 构建工具
- **TypeScript**: 类型支持
- **Element Plus**: UI组件库
- **Pinia**: 状态管理
- **Vue Router**: 路由管理
- **Axios**: HTTP客户端
- **ECharts**: 图表库

### 其他

- **Nginx**: Web服务器
- **MySQL/MariaDB**: 数据库
- **systemd**: 服务管理
- **Docker**: 容器化（可选）

## 项目结构

项目分为后端和前端两部分，结构如下：

### 后端结构

```
/
├── cmd/                    # 命令行入口
│   └── server/             # 服务器入口
├── pkg/                    # 核心包
│   ├── api/                # API定义和处理
│   │   ├── middleware/     # 中间件
│   │   ├── v1/             # API v1
│   │   └── routes.go       # 路由定义
│   ├── auth/               # 认证相关
│   ├── config/             # 配置管理
│   ├── database/           # 数据库操作
│   ├── logger/             # 日志系统
│   ├── models/             # 数据模型
│   ├── system/             # 系统信息和操作
│   ├── types/              # 共享类型定义
│   ├── utils/              # 工具函数
│   └── web/                # 网站部署管理
├── docs/                   # 文档
├── scripts/                # 脚本
│   └── install.sh          # 安装脚本
├── .gitignore
├── go.mod                  # Go模块定义
├── go.sum                  # Go依赖版本锁定
├── main.go                 # 主入口
└── README.md               # 项目说明
```

### 前端结构

```
ui/
├── public/                 # 静态资源
├── src/
│   ├── api/                # API请求
│   ├── assets/             # 资源文件
│   ├── components/         # 通用组件
│   ├── layout/             # 布局组件
│   ├── router/             # 路由配置
│   ├── store/              # 状态管理
│   ├── styles/             # 样式文件
│   ├── utils/              # 工具函数
│   ├── views/              # 页面视图
│   ├── App.vue             # 根组件
│   ├── main.ts             # 入口文件
│   └── vite-env.d.ts       # Vite类型定义
├── .eslintrc.js            # ESLint配置
├── .gitignore
├── index.html              # HTML模板
├── package.json            # 依赖定义
├── tsconfig.json           # TypeScript配置
├── vite.config.ts          # Vite配置
└── README.md               # 前端说明
```

## 开发环境搭建

### 前提条件

- Go 1.18+
- Node.js 16+
- npm 7+
- MySQL/MariaDB 5.7+
- Git

### 后端开发环境

1. 克隆仓库

```bash
git clone https://github.com/erniang/LinuxPanel.git
cd LinuxPanel
```

2. 安装Go依赖

```bash
# 设置GOPROXY（国内开发者推荐）
export GOPROXY=https://goproxy.cn,direct

# 安装依赖
go mod tidy
```

3. 运行开发服务器

```bash
# 直接运行
go run main.go

# 或者构建后运行
go build -o linuxpanel
./linuxpanel
```

### 前端开发环境

1. 进入前端目录

```bash
cd ui
```

2. 安装依赖

```bash
npm install
```

3. 创建开发环境配置

```bash
# 创建.env.development文件
cat > .env.development <<EOF
VITE_APP_BASE_API=http://localhost:8080/api
EOF
```

4. 启动开发服务器

```bash
npm run dev
```

前端服务默认在`http://localhost:5173`上运行。

### 开发数据库设置

对于开发环境，您可以使用本地MySQL/MariaDB：

```bash
# 创建开发数据库
mysql -u root -p -e "CREATE DATABASE linuxpanel_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -u root -p -e "CREATE USER 'linuxpanel_dev'@'localhost' IDENTIFIED BY 'dev_password';"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON linuxpanel_dev.* TO 'linuxpanel_dev'@'localhost';"
mysql -u root -p -e "FLUSH PRIVILEGES;"
```

然后修改配置文件以使用开发数据库：

```bash
# 创建开发配置
cat > config.dev.yaml <<EOF
server:
  port: 8080
  host: "127.0.0.1"
  
database:
  type: "mysql"
  host: "localhost"
  port: 3306
  user: "linuxpanel_dev"
  password: "dev_password"
  name: "linuxpanel_dev"
  
paths:
  data: "./data"
  logs: "./logs"
  websites: "./websites"
  
security:
  jwt_secret: "development_secret_key"
  session_timeout: 86400
EOF
```

启动后端服务时指定配置文件：

```bash
# 使用开发配置启动
go run main.go -config config.dev.yaml
```

## 编码规范

### Go代码规范

- 遵循[Effective Go](https://golang.org/doc/effective_go)和[Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)中的建议
- 使用`gofmt`格式化代码
- 添加适当的注释，特别是导出的函数和类型
- 错误处理：明确检查和处理错误，不要使用`_`忽略错误
- 变量命名：使用有意义的名称，局部变量使用简短名称，导出的名称使用有描述性的名称

### TypeScript/Vue代码规范

- 使用ESLint和Prettier保持代码风格一致
- 使用TypeScript类型定义，避免使用`any`
- 组件命名：使用PascalCase
- 属性绑定：使用kebab-case
- 组件文件：一个文件只包含一个组件
- CSS：优先使用scoped CSS，避免全局样式污染

## API文档

LinuxPanel的API采用RESTful风格，主要分为以下模块：

### 认证API

- `POST /api/v1/auth/login`: 用户登录
- `POST /api/v1/auth/logout`: 用户登出
- `GET /api/v1/auth/refresh`: 刷新访问令牌

### 系统API

- `GET /api/v1/system/info`: 获取系统信息
- `GET /api/v1/system/status`: 获取系统状态
- `GET /api/v1/system/resources`: 获取资源使用情况

### 网站API

- `GET /api/v1/websites`: 获取所有网站
- `GET /api/v1/websites/:id`: 获取特定网站
- `POST /api/v1/websites`: 创建网站
- `PUT /api/v1/websites/:id`: 更新网站
- `DELETE /api/v1/websites/:id`: 删除网站
- `POST /api/v1/websites/:id/control`: 控制网站状态

### 文件API

- `GET /api/v1/files/list`: 列出文件和目录
- `GET /api/v1/files/read`: 读取文件内容
- `POST /api/v1/files/write`: 写入文件内容
- `POST /api/v1/files/delete`: 删除文件或目录
- `POST /api/v1/files/mkdir`: 创建目录
- `POST /api/v1/files/copy`: 复制文件或目录
- `POST /api/v1/files/upload`: 上传文件

### 数据库API

- `GET /api/v1/database/list`: 列出数据库
- `POST /api/v1/database/create`: 创建数据库
- `DELETE /api/v1/database/delete`: 删除数据库
- `POST /api/v1/database/backup`: 备份数据库
- `POST /api/v1/database/recover`: 恢复数据库
- `GET /api/v1/database/user/list`: 列出数据库用户
- `POST /api/v1/database/user/create`: 创建数据库用户
- `DELETE /api/v1/database/user/delete`: 删除数据库用户
- `PUT /api/v1/database/user/permissions`: 更新用户权限
- `PUT /api/v1/database/user/password`: 更改用户密码

### 应用商店API

- `GET /api/v1/apps/list`: 列出可用应用
- `GET /api/v1/apps/installed`: 列出已安装应用
- `GET /api/v1/apps/detail/:id`: 获取应用详情
- `POST /api/v1/apps/install`: 安装应用
- `POST /api/v1/apps/uninstall`: 卸载应用
- `GET /api/v1/apps/registries`: 获取应用源
- `POST /api/v1/apps/registries/add`: 添加应用源
- `DELETE /api/v1/apps/registries/remove`: 移除应用源

详细的API文档可以在开发环境中通过访问`/swagger/index.html`获取。

## 前端开发

### 组件开发

组件应遵循以下原则：

1. **单一职责**：一个组件应只做一件事
2. **可复用性**：通用组件应放在`components`目录，页面特定组件放在对应的视图目录
3. **可测试性**：组件应易于测试，避免直接依赖外部服务
4. **props验证**：使用TypeScript定义props类型

示例：

```vue
<template>
  <div class="status-card">
    <div class="card-title">{{ title }}</div>
    <div class="card-value">{{ formatValue }}</div>
    <el-progress 
      :percentage="percentage" 
      :color="statusColor"
    ></el-progress>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent, PropType } from 'vue'

export default defineComponent({
  name: 'StatusCard',
  props: {
    title: {
      type: String,
      required: true
    },
    value: {
      type: Number,
      required: true
    },
    unit: {
      type: String,
      default: '%'
    },
    warningThreshold: {
      type: Number,
      default: 60
    },
    criticalThreshold: {
      type: Number,
      default: 80
    }
  },
  setup(props) {
    const formatValue = computed(() => {
      return `${props.value}${props.unit}`
    })
    
    const percentage = computed(() => {
      return Math.min(props.value, 100)
    })
    
    const statusColor = computed(() => {
      if (props.value >= props.criticalThreshold) return '#F56C6C'
      if (props.value >= props.warningThreshold) return '#E6A23C'
      return '#67C23A'
    })
    
    return {
      formatValue,
      percentage,
      statusColor
    }
  }
})
</script>

<style scoped>
.status-card {
  padding: 20px;
  border-radius: 4px;
  background: #fff;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
}

.card-title {
  font-size: 16px;
  color: #303133;
  margin-bottom: 10px;
}

.card-value {
  font-size: 24px;
  font-weight: bold;
  margin-bottom: 15px;
}
</style>
```

### 状态管理

使用Pinia进行状态管理，store定义示例：

```typescript
// src/store/website.ts
import { defineStore } from 'pinia'
import { fetchWebsites, createWebsite, updateWebsite, deleteWebsite, controlWebsite } from '@/api/website'
import type { WebsiteInfo, WebsiteCreateParams, WebsiteUpdateParams } from '@/types/website'

export const useWebsiteStore = defineStore('website', {
  state: () => ({
    websites: [] as WebsiteInfo[],
    loading: false,
    error: null as string | null,
  }),
  
  getters: {
    getWebsiteById: (state) => (id: number) => {
      return state.websites.find(site => site.id === id)
    },
  },
  
  actions: {
    async fetchWebsites() {
      this.loading = true
      this.error = null
      
      try {
        const response = await fetchWebsites()
        this.websites = response.data
      } catch (err: any) {
        this.error = err.message || 'Failed to fetch websites'
        throw err
      } finally {
        this.loading = false
      }
    },
    
    async createWebsite(params: WebsiteCreateParams) {
      this.loading = true
      this.error = null
      
      try {
        const response = await createWebsite(params)
        this.websites.push(response.data)
        return response.data
      } catch (err: any) {
        this.error = err.message || 'Failed to create website'
        throw err
      } finally {
        this.loading = false
      }
    },
    
    // 其他方法...
  },
})
```

### API请求

使用Axios进行API请求，示例：

```typescript
// src/api/website.ts
import request from '@/utils/request'
import type { WebsiteInfo, WebsiteCreateParams, WebsiteUpdateParams } from '@/types/website'

export function fetchWebsites() {
  return request({
    url: '/api/v1/websites',
    method: 'get'
  })
}

export function getWebsite(id: number) {
  return request({
    url: `/api/v1/websites/${id}`,
    method: 'get'
  })
}

export function createWebsite(data: WebsiteCreateParams) {
  return request({
    url: '/api/v1/websites',
    method: 'post',
    data
  })
}

export function updateWebsite(id: number, data: WebsiteUpdateParams) {
  return request({
    url: `/api/v1/websites/${id}`,
    method: 'put',
    data
  })
}

export function deleteWebsite(id: number) {
  return request({
    url: `/api/v1/websites/${id}`,
    method: 'delete'
  })
}

export function controlWebsite(id: number, action: 'start' | 'stop' | 'restart') {
  return request({
    url: `/api/v1/websites/${id}/control`,
    method: 'post',
    data: { action }
  })
}
```

## 后端开发

### 添加新API

要添加新的API端点，请遵循以下步骤：

1. 在适当的包中定义处理器函数

```go
// pkg/api/v1/example.go
package v1

import (
    "net/http"
    
    "github.com/gin-gonic/gin"
    "github.com/erniang/LinuxPanel/pkg/utils"
)

// ExampleRequest 定义请求结构
type ExampleRequest struct {
    Name string `json:"name" binding:"required"`
}

// ExampleResponse 定义响应结构
type ExampleResponse struct {
    Message string `json:"message"`
}

// HandleExample 处理示例请求
func HandleExample(c *gin.Context) {
    var req ExampleRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.ResponseError(c, http.StatusBadRequest, err.Error())
        return
    }
    
    // 业务逻辑处理
    
    utils.ResponseSuccess(c, ExampleResponse{
        Message: "Hello, " + req.Name,
    })
}
```

2. 在路由文件中注册新端点

```go
// pkg/api/v1/routes.go
package v1

import (
    "github.com/gin-gonic/gin"
)

// InitExampleRoutes 初始化示例路由
func InitExampleRoutes(router *gin.RouterGroup) {
    exampleGroup := router.Group("/example")
    {
        exampleGroup.POST("/", HandleExample)
        // 其他路由...
    }
}

// 在主路由文件中引用
// pkg/api/routes.go
func RegisterRoutes(router *gin.Engine) {
    // ...
    v1Group := router.Group("/api/v1")
    {
        // ...
        v1.InitExampleRoutes(v1Group)
    }
}
```

### 数据库模型

使用GORM定义模型，示例：

```go
// pkg/models/website.go
package models

import (
    "time"
    
    "gorm.io/gorm"
)

// Website 表示网站模型
type Website struct {
    ID          uint      `gorm:"primaryKey" json:"id"`
    Name        string    `gorm:"size:100;not null" json:"name"`
    Domain      string    `gorm:"size:255;not null;uniqueIndex" json:"domain"`
    Path        string    `gorm:"size:255;not null" json:"path"`
    PHPVersion  string    `gorm:"size:10" json:"php_version"`
    SSL         bool      `gorm:"default:false" json:"ssl"`
    SSLType     string    `gorm:"size:20" json:"ssl_type"`
    CertPath    string    `gorm:"size:255" json:"cert_path"`
    KeyPath     string    `gorm:"size:255" json:"key_path"`
    Status      string    `gorm:"size:20;default:'running'" json:"status"`
    CreatedAt   time.Time `json:"created_at"`
    UpdatedAt   time.Time `json:"updated_at"`
    Description string    `gorm:"size:500" json:"description"`
}

// WebsiteService 提供网站相关操作
type WebsiteService struct {
    DB *gorm.DB
}

// NewWebsiteService 创建网站服务
func NewWebsiteService(db *gorm.DB) *WebsiteService {
    return &WebsiteService{DB: db}
}

// GetAll 获取所有网站
func (s *WebsiteService) GetAll() ([]Website, error) {
    var websites []Website
    result := s.DB.Find(&websites)
    return websites, result.Error
}

// GetByID 通过ID获取网站
func (s *WebsiteService) GetByID(id uint) (Website, error) {
    var website Website
    result := s.DB.First(&website, id)
    return website, result.Error
}

// Create 创建网站
func (s *WebsiteService) Create(website *Website) error {
    return s.DB.Create(website).Error
}

// Update 更新网站
func (s *WebsiteService) Update(website *Website) error {
    return s.DB.Save(website).Error
}

// Delete 删除网站
func (s *WebsiteService) Delete(id uint) error {
    return s.DB.Delete(&Website{}, id).Error
}
```

### 错误处理

统一使用工具函数处理错误和响应：

```go
// pkg/utils/response.go
package utils

import (
    "github.com/gin-gonic/gin"
)

// Response 定义统一的响应格式
type Response struct {
    Code    int         `json:"code"`
    Message string      `json:"message"`
    Data    interface{} `json:"data,omitempty"`
}

// ResponseSuccess 成功响应
func ResponseSuccess(c *gin.Context, data interface{}) {
    c.JSON(200, Response{
        Code:    0,
        Message: "success",
        Data:    data,
    })
}

// ResponseError 错误响应
func ResponseError(c *gin.Context, code int, message string) {
    c.JSON(code, Response{
        Code:    code,
        Message: message,
    })
}
```

## 测试指南

### 后端测试

使用Go的标准测试包进行单元测试和集成测试：

```go
// pkg/utils/response_test.go
package utils

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
)

func TestResponseSuccess(t *testing.T) {
    // 设置测试环境
    gin.SetMode(gin.TestMode)
    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    
    // 测试数据
    testData := map[string]string{"name": "test"}
    
    // 调用被测函数
    ResponseSuccess(c, testData)
    
    // 验证结果
    assert.Equal(t, http.StatusOK, w.Code)
    
    var response Response
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)
    
    assert.Equal(t, 0, response.Code)
    assert.Equal(t, "success", response.Message)
    
    // 验证data字段
    dataJSON, err := json.Marshal(response.Data)
    assert.NoError(t, err)
    
    var resultData map[string]string
    err = json.Unmarshal(dataJSON, &resultData)
    assert.NoError(t, err)
    
    assert.Equal(t, "test", resultData["name"])
}

func TestResponseError(t *testing.T) {
    // 设置测试环境
    gin.SetMode(gin.TestMode)
    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    
    // 调用被测函数
    ResponseError(c, http.StatusBadRequest, "error message")
    
    // 验证结果
    assert.Equal(t, http.StatusBadRequest, w.Code)
    
    var response Response
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)
    
    assert.Equal(t, http.StatusBadRequest, response.Code)
    assert.Equal(t, "error message", response.Message)
}
```

### 前端测试

使用Vitest进行前端组件测试：

```typescript
// src/components/__tests__/StatusCard.test.ts
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import StatusCard from '../StatusCard.vue'

describe('StatusCard.vue', () => {
  it('renders props correctly', () => {
    const props = {
      title: 'CPU Usage',
      value: 45,
      unit: '%'
    }
    
    const wrapper = mount(StatusCard, { props })
    
    expect(wrapper.text()).toContain('CPU Usage')
    expect(wrapper.text()).toContain('45%')
  })
  
  it('applies correct color based on thresholds', async () => {
    const wrapper = mount(StatusCard, {
      props: {
        title: 'CPU Usage',
        value: 45,
        unit: '%',
        warningThreshold: 60,
        criticalThreshold: 80
      }
    })
    
    // 默认值应该使用绿色
    let progressBar = wrapper.findComponent({ name: 'el-progress' })
    expect(progressBar.props('color')).toBe('#67C23A')
    
    // 更新为警告值
    await wrapper.setProps({ value: 65 })
    expect(progressBar.props('color')).toBe('#E6A23C')
    
    // 更新为危险值
    await wrapper.setProps({ value: 85 })
    expect(progressBar.props('color')).toBe('#F56C6C')
  })
})
```

## 提交代码

### Git工作流

1. Fork项目到您的GitHub账户
2. 克隆您的Fork到本地
3. 创建新分支进行开发
4. 提交更改并推送到您的Fork
5. 创建Pull Request

```bash
# 克隆您的Fork
git clone https://github.com/YOUR_USERNAME/LinuxPanel.git
cd LinuxPanel

# 添加上游仓库
git remote add upstream https://github.com/erniang/LinuxPanel.git

# 创建新分支
git checkout -b feature/my-new-feature

# 进行更改...

# 提交更改
git add .
git commit -m "feat: add new feature"

# 推送到您的Fork
git push origin feature/my-new-feature
```

### 提交规范

使用[Conventional Commits](https://www.conventionalcommits.org/)规范：

- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更改
- `style`: 不影响代码含义的更改（空格、格式等）
- `refactor`: 既不修复错误也不添加功能的代码更改
- `perf`: 性能改进
- `test`: 添加或修正测试
- `chore`: 构建过程或辅助工具的变动

示例：

```
feat: add new database management API
fix: resolve website creation error when SSL enabled
docs: update installation guide
```

### Pull Request流程

1. 确保您的代码通过了所有测试
2. 更新文档以反映代码变更
3. 提交详细的PR描述，说明更改内容和原因
4. 关联相关的Issue（如有）
5. 等待代码审查并根据反馈进行修改

## 版本发布流程

LinuxPanel使用[语义化版本控制](https://semver.org/)：

- **主版本号**：不兼容的API更改
- **次版本号**：向后兼容的功能新增
- **修订号**：向后兼容的bug修复

### 发布步骤

1. 更新版本号（`version.go`和`package.json`）
2. 更新CHANGELOG.md
3. 创建发布分支（如`release/v1.2.0`）
4. 创建发布PR并合并到主分支
5. 创建发布标签
6. 构建发布包

```bash
# 更新版本文件
# ...

# 创建发布分支
git checkout -b release/v1.2.0

# 提交更改
git add .
git commit -m "chore: prepare release v1.2.0"

# 推送分支
git push origin release/v1.2.0

# 合并后创建标签
git tag v1.2.0
git push origin v1.2.0
```

## 贡献指南总结

1. **遵循代码规范**：Go代码使用`gofmt`格式化，前端代码遵循项目ESLint配置
2. **编写测试**：为新代码添加适当的测试
3. **文档更新**：更新相关文档以反映代码变更
4. **遵循Git工作流**：使用功能分支和规范的提交信息
5. **代码审查**：积极参与代码审查过程并及时响应反馈

我们欢迎所有形式的贡献，无论是新功能、bug修复，还是文档改进！ 