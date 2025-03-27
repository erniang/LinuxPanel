# LinuxPanel 贡献指南

非常感谢您对LinuxPanel项目的关注！我们欢迎并鼓励社区成员参与项目的开发和改进。本文档将帮助您了解如何为项目做出贡献。

## 行为准则

在参与本项目时，请遵循以下原则：

- 尊重所有项目参与者，不进行人身攻击或歧视
- 建设性地提出问题和建议
- 保持专业和友好的交流方式
- 关注项目的整体质量和用户体验

## 参与方式

您可以通过以下方式参与项目：

1. 提交Bug报告或功能请求
2. 改进文档
3. 提交代码修复或新功能
4. 帮助回答其他用户的问题
5. 参与代码审查和讨论

## 提交Issue

如果您发现了问题或有功能建议，请通过创建Issue告诉我们：

1. 使用适当的模板（Bug报告或功能请求）
2. 提供尽可能详细的信息，包括：
   - 对于Bug：问题描述、重现步骤、期望行为、实际行为、环境信息
   - 对于功能请求：详细描述该功能的需求和使用场景

## 提交Pull Request

如果您想直接贡献代码，请按照以下步骤：

1. Fork仓库到您的GitHub账户
2. 克隆您的仓库到本地
   ```bash
   git clone https://github.com/YOUR_USERNAME/LinuxPanel.git
   ```
3. 添加上游仓库
   ```bash
   git remote add upstream https://github.com/erniang/LinuxPanel.git
   ```
4. 创建一个新分支（分支命名请参考下文）
   ```bash
   git checkout -b feature/your-feature-name
   ```
5. 进行修改并确保代码符合项目规范
6. 提交您的更改
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```
7. 将您的更改推送到您的仓库
   ```bash
   git push origin feature/your-feature-name
   ```
8. 通过GitHub创建Pull Request

## 分支命名和提交消息规范

### 分支命名

请使用以下格式命名分支：

- `feature/name` - 新功能
- `fix/name` - Bug修复
- `docs/name` - 文档更新
- `refactor/name` - 代码重构
- `test/name` - 测试相关
- `chore/name` - 构建过程或辅助工具的变动

### 提交消息

我们使用[Conventional Commits](https://www.conventionalcommits.org/)规范：

```
<类型>[可选的作用域]: <描述>

[可选的正文]

[可选的页脚]
```

常用类型：

- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更新
- `style`: 代码风格更改（不影响代码功能）
- `refactor`: 代码重构（不是新功能也不是错误修复）
- `perf`: 性能优化
- `test`: 添加或修改测试
- `chore`: 构建过程或辅助工具的变动

示例：
```
feat(website): add SSL configuration support

Add UI components and backend API for SSL certificate management
```

## 开发环境设置

详细的开发环境设置请参考[开发指南](docs/development.md)。

## 代码风格和规范

- **Go代码**：
  - 使用`gofmt`格式化代码
  - 遵循[Effective Go](https://golang.org/doc/effective_go)指南
  - 添加适当的注释，尤其是导出的函数和类型

- **TypeScript/Vue代码**：
  - 遵循项目的ESLint和Prettier配置
  - 使用TypeScript类型定义
  - 组件使用PascalCase命名
  - 文件一个组件一个文件

## 测试

- 为新功能或修复添加适当的测试
- 确保所有测试通过后再提交PR
- 测试指南详见[开发指南](docs/development.md)中的测试部分

## 文档

- 更新或添加与您的更改相关的文档
- 文档用中文编写，清晰明了
- 代码示例应当实用且易于理解

## 许可证

通过提交PR，您同意您的贡献将根据项目[LICENSE](LICENSE)中指定的许可证授权。

---

感谢您为LinuxPanel做出贡献！如果您有任何问题，请随时通过Issue或讨论联系我们。 