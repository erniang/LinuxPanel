# LinuxPanel 常见问题解答 (FAQ)

本文档收集了用户在使用LinuxPanel过程中常见的问题和解决方案。

## 目录

- [安装问题](#安装问题)
- [登录问题](#登录问题)
- [网站管理问题](#网站管理问题)
- [文件管理问题](#文件管理问题)
- [数据库问题](#数据库问题)
- [应用商店问题](#应用商店问题)
- [系统问题](#系统问题)
- [性能问题](#性能问题)
- [升级问题](#升级问题)

## 安装问题

### Q: 一键安装脚本执行失败，提示"command not found"

**A:** 这通常是由于脚本没有执行权限或系统缺少基本工具如bash导致的。尝试以下步骤：

1. 确保脚本有执行权限：`chmod +x install.sh`
2. 确保使用bash执行脚本：`bash install.sh`

### Q: 安装过程中报告"无法连接到存储库"或"下载失败"

**A:** 可能是网络问题或镜像源不可用。尝试以下解决方案：

1. 检查服务器网络连接
2. 如果使用的是国外服务器，可能需要更换国内镜像源
3. 对于Go和Node.js的安装问题，可以尝试手动下载安装包后上传到服务器

### Q: 安装过程中MySQL/MariaDB配置失败

**A:** 可能是由于MySQL已有配置或权限问题。尝试：

1. 检查MySQL是否已安装并正在运行：`systemctl status mysql`或`systemctl status mysqld`
2. 如果已安装，尝试手动创建数据库和用户：
   ```sql
   CREATE DATABASE linuxpanel CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
   CREATE USER 'linuxpanel'@'localhost' IDENTIFIED BY 'linuxpanel';
   GRANT ALL PRIVILEGES ON linuxpanel.* TO 'linuxpanel'@'localhost';
   FLUSH PRIVILEGES;
   ```

### Q: 编译后端时报错"go: command not found"

**A:** Go语言环境未正确安装或环境变量未设置。解决方法：

1. 检查Go是否已安装：`which go`
2. 如果已安装但命令未找到，设置环境变量：
   ```bash
   export PATH=$PATH:/usr/local/go/bin
   ```
3. 将上述命令添加到`~/.bashrc`或`/etc/profile`中使其永久生效

## 登录问题

### Q: 无法登录面板，提示"用户名或密码错误"

**A:** 可能是凭据错误或用户数据损坏。尝试：

1. 确认使用默认凭据：用户名`admin`，密码`admin`（如果未修改）
2. 如果忘记密码，可以通过以下步骤重置：
   ```bash
   # 生成新的盐值和密码哈希
   SALT=$(openssl rand -hex 8)
   # 新密码为'admin'
   PASSWORD_HASH=$(echo -n "admin$SALT" | md5sum | cut -d ' ' -f 1)
   
   # 编辑用户文件
   sudo cat > /var/lib/linuxpanel/data/users/admin.json <<EOF
   {
       "username": "admin",
       "password_hash": "$PASSWORD_HASH",
       "salt": "$SALT",
       "role": "admin",
       "email": "admin@example.com",
       "created_at": "$(date +%s)",
       "last_login": "0"
   }
   EOF
   ```

### Q: 登录后立即被退出或提示"会话已过期"

**A:** 可能是cookie或会话配置问题。尝试：

1. 清除浏览器缓存和cookie
2. 检查服务器时间是否正确：`date`
3. 确保配置文件中的`jwt_secret`已正确设置

### Q: 登录成功但页面显示空白

**A:** 前端资源可能未正确加载。排查步骤：

1. 检查浏览器控制台是否有JavaScript错误
2. 确认Nginx配置正确：`nginx -t`
3. 检查前端文件是否存在：`ls -la /opt/linuxpanel/ui/dist`
4. 查看Nginx错误日志：`tail -f /var/log/nginx/error.log`

## 网站管理问题

### Q: 创建网站后无法访问

**A:** 可能是Nginx配置、防火墙或域名解析问题。检查：

1. 确认网站状态是否为"运行中"
2. 检查Nginx配置是否正确：`nginx -t`
3. 查看Nginx错误日志：`tail -f /var/log/nginx/error.log`
4. 确保域名已正确解析到服务器IP
5. 检查防火墙是否允许80/443端口：
   ```bash
   # Ubuntu/Debian
   sudo ufw status
   
   # CentOS/RHEL
   sudo firewall-cmd --list-all
   ```

### Q: SSL证书申请失败

**A:** Let's Encrypt证书申请需要满足特定条件。确保：

1. 域名已正确解析到当前服务器IP
2. 80端口可从外网访问（Let's Encrypt验证需要）
3. 服务器时间正确（证书验证对时间敏感）
4. 检查acme.sh日志：`tail -f /root/.acme.sh/acme.sh.log`

### Q: PHP网站报错"无法连接到PHP-FPM"

**A:** PHP-FPM服务可能未运行或配置不正确。解决步骤：

1. 检查PHP-FPM服务状态：`systemctl status php7.4-fpm`（根据版本替换7.4）
2. 确保PHP-FPM套接字文件存在：`ls -la /run/php/`
3. 重启PHP-FPM服务：`systemctl restart php7.4-fpm`

## 文件管理问题

### Q: 无法上传大文件

**A:** 通常是由于PHP或Nginx的上传限制导致。解决方法：

1. 修改Nginx客户端正文大小限制：
   ```
   client_max_body_size 100m;  # 在http, server或location块中添加
   ```
2. 修改PHP上传限制（php.ini）：
   ```ini
   upload_max_filesize = 100M
   post_max_size = 100M
   ```
3. 重启Nginx和PHP-FPM服务

### Q: 文件权限操作失败

**A:** 可能是LinuxPanel服务权限不足。解决方法：

1. 确保LinuxPanel以root用户运行
2. 如果不是root用户，需要为用户添加sudo权限
3. 检查目标文件系统是否只读或有特殊挂载选项

### Q: 无法编辑特定文件

**A:** 可能是文件权限或格式问题。解决方法：

1. 确认文件权限：`ls -la /path/to/file`
2. 检查文件是否为二进制文件（不可编辑）：`file /path/to/file`
3. 确保文件未被其他进程锁定：`lsof /path/to/file`

## 数据库问题

### Q: 无法创建数据库

**A:** 可能是MySQL权限或配置问题。解决方法：

1. 检查MySQL服务状态：`systemctl status mysql`
2. 验证LinuxPanel用户有权创建数据库：
   ```sql
   SHOW GRANTS FOR 'linuxpanel'@'localhost';
   ```
3. 手动尝试创建数据库：
   ```sql
   CREATE DATABASE test_db;
   ```

### Q: 数据库备份失败

**A:** 可能是权限、磁盘空间或mysqldump问题。解决方法：

1. 检查磁盘空间：`df -h`
2. 确保mysqldump命令可用：`which mysqldump`
3. 检查备份目录权限：`ls -la /var/lib/linuxpanel/data/backups`
4. 手动尝试备份：
   ```bash
   mysqldump -u root -p database_name > backup.sql
   ```

### Q: 数据库连接超时

**A:** 可能是MySQL配置或资源问题。解决方法：

1. 检查MySQL最大连接数：
   ```sql
   SHOW VARIABLES LIKE 'max_connections';
   ```
2. 检查当前连接数：
   ```sql
   SHOW STATUS WHERE Variable_name = 'Threads_connected';
   ```
3. 如有必要，增加最大连接数（在my.cnf中）：
   ```
   max_connections = 200
   ```

## 应用商店问题

### Q: 应用安装失败

**A:** 可能是依赖、网络或权限问题。解决方法：

1. 检查安装日志
2. 确保服务器满足应用要求（PHP版本、扩展等）
3. 检查网络连接（应用下载可能失败）
4. 检查磁盘空间：`df -h`

### Q: 应用商店为空或加载失败

**A:** 可能是网络连接或应用源配置问题。解决方法：

1. 检查网络连接，确保可以访问应用源
2. 验证应用源URL是否正确
3. 尝试添加备用应用源
4. 检查LinuxPanel日志中的错误信息

### Q: 已安装的应用无法正常工作

**A:** 可能是配置、权限或依赖问题。解决方法：

1. 检查应用的错误日志
2. 确保Nginx和PHP配置正确
3. 验证应用所需的PHP扩展是否已安装
4. 检查应用目录权限

## 系统问题

### Q: 面板显示的系统信息不准确

**A:** 可能是监控服务或权限问题。解决方法：

1. 重启LinuxPanel服务：`systemctl restart linuxpanel`
2. 确保LinuxPanel有足够权限读取系统信息
3. 手动验证系统信息：
   ```bash
   free -m        # 内存信息
   df -h          # 磁盘信息
   uptime         # 系统负载
   cat /proc/cpuinfo  # CPU信息
   ```

### Q: 系统资源使用率过高

**A:** 可能是某些进程占用过多资源。排查步骤：

1. 检查高CPU使用率进程：`top -c`
2. 检查内存使用情况：`free -m`
3. 检查磁盘I/O：`iostat -x 1`
4. 查看当前最大文件描述符限制：`ulimit -n`

### Q: 日志文件过大

**A:** 日志文件可能需要轮转或清理。解决方法：

1. 配置logrotate处理LinuxPanel日志：
   ```
   # 创建文件 /etc/logrotate.d/linuxpanel
   /var/log/linuxpanel/*.log {
       daily
       missingok
       rotate 7
       compress
       delaycompress
       notifempty
       create 644 root root
   }
   ```
2. 手动清理过大的日志文件：
   ```bash
   # 备份并清空
   cp /var/log/linuxpanel/error.log /var/log/linuxpanel/error.log.bak
   echo "" > /var/log/linuxpanel/error.log
   ```

## 性能问题

### Q: 面板响应缓慢

**A:** 可能是服务器资源不足或配置问题。解决方法：

1. 检查服务器负载：`uptime`
2. 检查内存使用情况：`free -m`
3. 考虑增加服务器资源（CPU/内存）
4. 优化Nginx和MySQL配置

### Q: 网站加载速度慢

**A:** 多种因素可能导致网站加载缓慢。解决方法：

1. 启用Nginx缓存
2. 检查PHP-FPM配置，可能需要调整进程数
3. 检查网站代码是否有性能问题
4. 考虑使用CDN分发静态资源

### Q: 数据库查询慢

**A:** 可能是数据库配置或查询优化问题。解决方法：

1. 启用慢查询日志找出问题查询
2. 为常用查询创建索引
3. 优化MySQL配置（如缓冲池大小）
4. 考虑分离数据库到专用服务器

## 升级问题

### Q: 升级后面板无法启动

**A:** 可能是配置不兼容或文件损坏。解决方法：

1. 检查日志文件：`tail -f /var/log/linuxpanel/error.log`
2. 从备份恢复配置文件
3. 确保所有依赖已更新：`go mod tidy`
4. 如果问题持续，考虑从备份恢复或重新安装

### Q: 升级后某些功能丢失

**A:** 可能是配置迁移问题或功能变更。解决方法：

1. 检查更新日志了解功能变更
2. 确保正确迁移了配置和数据
3. 咨询开发团队或社区支持

### Q: 如何保持系统自动更新

**A:** 可以设置自动更新机制：

1. 在crontab中添加定期更新任务：
   ```bash
   # 编辑crontab
   crontab -e
   
   # 添加每周一自动更新
   0 2 * * 1 /opt/linuxpanel/update.sh > /var/log/linuxpanel/update.log 2>&1
   ```
2. 或在面板设置中启用自动更新选项

## 联系支持

如果您遇到的问题未在本文档中列出，可以通过以下方式获取支持：

1. 在GitHub上提交Issue：[https://github.com/erniang/LinuxPanel/issues](https://github.com/erniang/LinuxPanel/issues)
2. 加入社区讨论组
3. 查阅详细的[开发文档](development.md)或[使用指南](usage.md) 