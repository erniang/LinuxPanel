# LinuxPanel - 轻量级Linux服务器管理面板

<div align="center">
    <img src="./ui/src/assets/logo.png" alt="LinuxPanel Logo" width="200">
</div>

![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)
![Go Version](https://img.shields.io/badge/go-%3E%3D1.21-blue.svg)
![Node Version](https://img.shields.io/badge/node-%3E%3D16-green.svg)

LinuxPanel是一个轻量级的Linux服务器管理面板，提供直观的Web界面来管理您的Linux服务器，采用模块化设计，支持通过应用商店按需安装所需的组件。

## 功能特性

### 核心功能
- 系统信息监控
- 模块化设计
- 基于SQLite的数据存储
- 轻量级资源占用

### 可选模块（通过应用商店安装）
- Nginx网站管理
- MySQL/MariaDB数据库管理
- PHP运行环境
- 文件管理
- 防火墙配置
- SSL证书申请

## 系统要求

- Linux操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 10+)
- 最小配置：1核CPU，512MB内存，5GB硬盘空间
- 推荐配置：2核CPU，1GB内存，10GB+硬盘空间

## 快速安装

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/erniang/LinuxPanel/main/install.sh

# 给脚本添加执行权限
chmod +x install.sh

# 以root用户运行安装脚本
sudo ./install.sh
```

## 更新与修复

如果安装过程中出现问题，特别是前端构建失败，可以使用以下命令修复：

```bash
# 下载修复脚本
wget https://raw.githubusercontent.com/erniang/LinuxPanel/main/update_scripts/update_build.sh

# 给脚本添加执行权限
chmod +x update_build.sh

# 运行修复脚本
sudo ./update_build.sh
```

## 使用指南

安装完成后，通过浏览器访问服务器IP地址（或配置域名），默认监听8080端口：

```
http://YOUR_SERVER_IP:8080
```

初始登录凭证：
- 用户名：admin
- 密码：admin123

**重要提示：** 首次登录后请立即修改默认密码！

## 配置文件

主配置文件位于 `/etc/linuxpanel/config.yaml`

## 服务管理

LinuxPanel作为系统服务运行，可以使用以下命令管理：

```bash
# 启动服务
systemctl start linuxpanel

# 停止服务
systemctl stop linuxpanel

# 重启服务
systemctl restart linuxpanel

# 查看服务状态
systemctl status linuxpanel

# 设置开机自启
systemctl enable linuxpanel
```

## 常见问题解决

### 前端页面显示404或安装后无法访问

如果安装后访问面板时出现404页面或显示不完整的内容，可能是前端构建失败导致的。请使用上述的更新与修复脚本修复问题。

### 无法登录系统

默认用户名和密码是 `admin` / `admin123`。如果无法登录，请检查：

1. 密码是否输入正确
2. 后端服务是否正常运行（使用 `systemctl status linuxpanel` 检查）
3. 数据库是否损坏（尝试重新安装）

## 许可证

本项目采用GPL-3.0 License

## 开发指南

如果您想参与开发，请查看[开发文档](docs/development.md)。

### 后端结构

```
pkg/
├── api/          # API路由和处理器
├── auth/         # 身份验证
├── common/       # 公共组件和类型
├── config/       # 配置处理
├── database/     # 数据库操作
├── logger/       # 日志系统
├── models/       # 数据模型
├── system/       # 系统信息和操作
├── types/        # 类型定义
└── web/          # 网站部署管理
```

### 前端结构

```
ui/
├── public/       # 静态资源
└── src/
    ├── api/      # API请求
    ├── assets/   # 资源文件
    ├── components/ # 通用组件
    ├── layout/   # 布局组件
    ├── router/   # 路由配置
    ├── store/    # 状态管理
    ├── styles/   # 样式文件
    ├── utils/    # 工具函数
    └── views/    # 页面视图
```

## 贡献

欢迎提交问题报告、功能请求和Pull Request。在提交Pull Request之前，请确保您的代码符合项目的编码规范。

## 联系方式

- GitHub Issues: [https://github.com/erniang/LinuxPanel/issues](https://github.com/erniang/LinuxPanel/issues)
- 邮箱：admin@example.com

## 致谢

LinuxPanel的开发受到了以下开源项目的启发：

- [宝塔面板](https://www.bt.cn/)
- [Cockpit](https://cockpit-project.org/)
- [Webmin](http://www.webmin.com/)

感谢所有贡献者和用户的支持！ 