---
title: Hexo博客部署到服务器
tags: [Hexo, Nginx, Docker, HTTPS, CDN]
categories: [建站]
type: story
date: 2025-07-05 16:44:25
cover:
---

# Hexo 博客部署到服务器完整教程

这篇文章记录一套从零到可上线的 Hexo 部署流程：本地用 Hexo 写文章并生成静态文件，把生成后的 `public/` 上传到自己的云服务器，再由 Docker 中的 Nginx 对外提供访问。

最终目标是：

```text
本地 Hexo 项目
  -> hexo generate
  -> public/
  -> 上传到服务器 /opt/hexo-blog/html
  -> Docker Nginx 托管静态文件
  -> 域名访问
  -> HTTPS
```

这套方式的优点是结构清晰、排错简单。Hexo 只负责生成静态页面，服务器只负责托管 HTML、CSS、JS、图片等静态资源。

## 一、准备工作

你需要准备：

- 一台云服务器，例如阿里云 ECS。
- 一个域名，例如 `example.com`。
- 本地安装 Node.js、npm、Git。
- 服务器安装 Docker 和 Docker Compose。
- 本地可以通过 SSH 连接服务器。

本文示例中使用：

```text
服务器 IP：47.115.213.32
根域名：lbwxxc.top
www 域名：www.lbwxxc.top
服务器部署目录：/opt/hexo-blog
```

实际使用时，把这些值替换成你自己的。

## 二、本地安装并初始化 Hexo

先检查本地环境：

```bash
node -v
npm -v
git --version
```

安装 Hexo CLI：

```bash
npm install -g hexo-cli
```

初始化博客：

```bash
hexo init myblog
cd myblog
npm install
```

本地预览：

```bash
hexo server
```

默认访问：

```text
http://localhost:4000
```

新建文章：

```bash
hexo new "我的第一篇博客"
```

文章会生成在：

```text
source/_posts/
```

生成静态文件：

```bash
hexo clean
hexo generate
```

生成结果在：

```text
public/
```

后续真正部署到服务器的就是 `public/` 目录里的内容，不是整个 Hexo 项目。

## 三、服务器目录规划

登录服务器：

```bash
ssh root@47.115.213.32
```

创建目录：

```bash
sudo mkdir -p /opt/hexo-blog/html
sudo mkdir -p /opt/hexo-blog/conf.d
sudo mkdir -p /opt/hexo-blog/logs
sudo mkdir -p /opt/hexo-blog/certbot/www
sudo mkdir -p /opt/hexo-blog/certbot/conf
```

推荐目录结构：

```text
/opt/hexo-blog
├── docker-compose.yml
├── html/              # Hexo 生成后的静态文件
├── conf.d/            # Nginx 配置
├── logs/              # Nginx 日志
└── certbot/
    ├── www/           # Let's Encrypt 验证目录
    └── conf/          # SSL 证书目录
```

其中最重要的是：

```text
/opt/hexo-blog/html
```

这个目录会挂载到 Nginx 容器里的：

```text
/usr/share/nginx/html
```

也就是说，服务器上的 `/opt/hexo-blog/html/index.html`，在容器里就是 `/usr/share/nginx/html/index.html`。

## 四、编写 Docker Compose

创建 `docker-compose.yml`：

```bash
sudo nano /opt/hexo-blog/docker-compose.yml
```

写入：

```yaml
services:
  nginx:
    image: nginx:stable-alpine
    container_name: hexo-nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./logs:/var/log/nginx
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
```

说明：

- `80:80` 用于 HTTP 访问和证书验证。
- `443:443` 用于 HTTPS 访问。
- `./html:/usr/share/nginx/html:ro` 把静态文件挂载给 Nginx。
- `./conf.d:/etc/nginx/conf.d:ro` 把 Nginx 配置挂载进容器。
- `./certbot/conf:/etc/letsencrypt` 保存证书。

## 五、先配置 HTTP 站点

在申请 HTTPS 之前，建议先让 HTTP 正常访问。

创建 Nginx 配置：

```bash
sudo nano /opt/hexo-blog/conf.d/hexo.conf
```

如果你已经有域名，先写：

```nginx
server {
    listen 80;
    server_name lbwxxc.top www.lbwxxc.top;

    root /usr/share/nginx/html;
    index index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    error_page 404 /404.html;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
```

如果还没有域名，可以临时使用 IP：

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

启动 Nginx：

```bash
cd /opt/hexo-blog
sudo docker compose up -d
```

检查容器：

```bash
sudo docker ps
sudo docker logs hexo-nginx
```

检查 Nginx 配置：

```bash
sudo docker compose exec nginx nginx -t
```

## 六、上传 Hexo 静态文件

在本地 Hexo 项目里生成静态文件：

```bash
hexo clean
hexo generate
```

如果你本地是 Windows PowerShell，可以用：

```powershell
ssh root@47.115.213.32 "rm -rf /opt/hexo-blog/html/*"
scp -r .\public\* root@47.115.213.32:/opt/hexo-blog/html/
```

上传后，在服务器检查：

```bash
ls -la /opt/hexo-blog/html
```

应该能看到：

```text
index.html
archives/
categories/
tags/
css/
js/
```

此时访问：

```text
http://47.115.213.32/
```

或：

```text
http://lbwxxc.top/
http://www.lbwxxc.top/
```

如果能打开页面，说明 Hexo 静态文件和 Nginx 托管已经正常。

## 七、配置域名 DNS

如果不使用 CDN，最简单的 DNS 配置是 A 记录直连 ECS：

```text
@      A      47.115.213.32
www    A      47.115.213.32
```

含义：

- `@` 表示根域名，例如 `lbwxxc.top`。
- `www` 表示 `www.lbwxxc.top`。
- A 记录的值填服务器公网 IP。

配置完成后，本地刷新 DNS：

```powershell
ipconfig /flushdns
```

检查解析：

```powershell
nslookup lbwxxc.top
nslookup www.lbwxxc.top
```

正确结果应该都指向：

```text
47.115.213.32
```

注意：同一个主机记录不能同时存在 CNAME 和 A。比如 `@` 不能既有 CNAME 又有 A，`www` 也不能既有 CNAME 又有 A。

## 八、配置 HTTPS

确认 HTTP 可以访问后，再申请 HTTPS 证书。

先确保 Nginx 配置里有这个验证路径：

```nginx
location /.well-known/acme-challenge/ {
    root /var/www/certbot;
}
```

然后执行 Certbot：

```bash
sudo docker run --rm \
  -v /opt/hexo-blog/certbot/conf:/etc/letsencrypt \
  -v /opt/hexo-blog/certbot/www:/var/www/certbot \
  certbot/certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d lbwxxc.top \
  -d www.lbwxxc.top
```

证书成功后，修改 Nginx 配置：

```bash
sudo nano /opt/hexo-blog/conf.d/hexo.conf
```

不使用 CDN 时，推荐这样写：

```nginx
server {
    listen 80;
    server_name lbwxxc.top www.lbwxxc.top;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name lbwxxc.top www.lbwxxc.top;

    ssl_certificate /etc/letsencrypt/live/lbwxxc.top/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lbwxxc.top/privkey.pem;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    error_page 404 /404.html;

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|webp|woff|woff2)$ {
        expires 30d;
        access_log off;
    }
}
```

检查并重载：

```bash
cd /opt/hexo-blog
sudo docker compose exec nginx nginx -t
sudo docker compose exec nginx nginx -s reload
```

测试：

```powershell
curl.exe --ssl-no-revoke -I https://lbwxxc.top/
curl.exe --ssl-no-revoke -I https://www.lbwxxc.top/
```

正常应该看到：

```text
HTTP/1.1 200 OK
Server: nginx
```

## 九、日常更新博客流程

本地写文章：

```bash
hexo new "文章标题"
hexo server
```

确认没问题后生成：

```bash
hexo clean
hexo generate
```

上传到服务器：

```powershell
ssh root@47.115.213.32 "rm -rf /opt/hexo-blog/html/*"
scp -r .\public\* root@47.115.213.32:/opt/hexo-blog/html/
```

这种情况下不需要重启 Nginx，也不需要重启 Docker 容器。因为 Nginx 只是读取挂载目录里的静态文件，你替换了 `/opt/hexo-blog/html` 里的内容，下一次访问就会读到新文件。

只有修改这些内容时，才需要重载 Nginx：

- Nginx 配置文件。
- `docker-compose.yml`。
- HTTPS 证书配置。
- 域名 `server_name`。

重载命令：

```bash
sudo docker compose exec nginx nginx -t
sudo docker compose exec nginx nginx -s reload
```

## 十、写一个本地部署脚本

可以在 Hexo 项目根目录创建 `deploy.ps1`：

```powershell
hexo clean
hexo generate

ssh root@47.115.213.32 "rm -rf /opt/hexo-blog/html/*"
scp -r .\public\* root@47.115.213.32:/opt/hexo-blog/html/

Write-Host "Deploy finished."
```

以后更新文章后执行：

```powershell
.\deploy.ps1
```

如果你使用 CDN，部署后还需要去 CDN 控制台刷新缓存，尤其是首页、文章页、CSS、JS 有变化时。

## 十一、使用 CDN 时的配置

如果你使用阿里云 CDN，链路会变成：

```text
用户 -> CDN -> ECS 源站 Nginx
```

这时 DNS 不再直接 A 到服务器，而是 CNAME 到 CDN：

```text
@      CNAME    lbwxxc.top 对应的 CDN CNAME
www    CNAME    www.lbwxxc.top 对应的 CDN CNAME
```

CDN 控制台建议：

```text
HTTPS：开启
HTTP -> HTTPS：开启
回源协议：HTTP
回源端口：80
源站 IP：47.115.213.32
```

重点：如果 CDN 回源走 HTTP，源站 Nginx 不要再把 HTTP 跳转到 HTTPS，否则很容易出现重定向循环。

走 CDN 时，源站 Nginx 可以只监听 80：

```nginx
server {
    listen 80;
    server_name lbwxxc.top www.lbwxxc.top;

    root /usr/share/nginx/html;
    index index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    error_page 404 /404.html;
}
```

也就是说：

```text
不走 CDN：Nginx 做 HTTP -> HTTPS 跳转。
走 CDN：CDN 做 HTTP -> HTTPS 跳转，源站 Nginx 不跳。
```

这是整套部署中最容易出错的地方。

## 十二、最终推荐方案

如果不使用 CDN：

```text
DNS：
@      A      47.115.213.32
www    A      47.115.213.32

Nginx：
80 端口跳转到 HTTPS
443 端口提供静态站点
```

如果使用 CDN：

```text
DNS：
@      CNAME  CDN 提供的 CNAME
www    CNAME  CDN 提供的 CNAME

CDN：
负责 HTTPS 和 HTTP -> HTTPS

源站 Nginx：
80 端口直接返回静态文件，不做 HTTPS 跳转
```

## 十三、易错问题汇总与解决方案

### 1. 关闭 CDN 后网站访问不了

现象：

```text
CDN 已停止，但访问域名失败。
nslookup 显示域名仍然指向 CDN CNAME。
```

例如：

```text
lbwxxc.top -> lbwxxc.top.w.cdngslb.com -> offline.specialcdnstatus.com
Address: 169.254.254.254
```

原因：

```text
你停用了 CDN，但 DNS 仍然指向 CDN。
```

解决：

```text
删除或暂停 @ 的 CNAME。
删除或暂停 www 的 CNAME。
改成 A 记录指向 ECS IP。
```

示例：

```text
@      A      47.115.213.32
www    A      47.115.213.32
```

### 2. 根域名能否访问取决于 @ 记录

现象：

```text
https://www.lbwxxc.top 可以访问
https://lbwxxc.top 不能访问
```

原因通常是：

```text
www 已经 A 到服务器 IP。
@ 还 CNAME 到已停用 CDN。
```

解决：

```text
把 @ 记录也改成 A 记录：
@ A 47.115.213.32
```

验证：

```powershell
ipconfig /flushdns
nslookup lbwxxc.top
nslookup www.lbwxxc.top
```

两者都应该解析到服务器 IP。

### 3. A 记录和 CNAME 不能同时存在

同一个主机记录不能同时配置 A 和 CNAME。

错误示例：

```text
@      CNAME    xxx.cdn.com
@      A        47.115.213.32
```

正确做法：

```text
不用 CDN：保留 A，删除 CNAME。
使用 CDN：保留 CNAME，删除 A。
```

### 4. HTTPS 证书申请失败

常见原因：

- 域名没有解析到当前服务器。
- 服务器安全组没有放行 80 端口。
- Docker 没有映射 80 端口。
- Nginx 没有配置 `/.well-known/acme-challenge/`。
- CDN 干扰了验证请求。

排查顺序：

```bash
nslookup lbwxxc.top
sudo docker ps
sudo docker compose exec nginx nginx -t
curl -I http://lbwxxc.top/.well-known/acme-challenge/test
```

如果还没申请证书，先不要急着写复杂的 HTTPS 配置。先确保 HTTP 能正常访问。

### 5. Windows curl 报证书吊销检查错误

现象：

```text
CRYPT_E_REVOCATION_OFFLINE
```

或：

```text
schannel: next InitializeSecurityContext failed
```

可以用：

```powershell
curl.exe --ssl-no-revoke -I https://www.lbwxxc.top/
```

如果返回 `200 OK`，说明网站 HTTPS 基本正常，问题可能是 Windows 本地证书吊销检查无法联网完成。

### 6. 浏览器提示重定向次数过多

现象：

```text
ERR_TOO_MANY_REDIRECTS
```

常见原因：

```text
CDN 回源 HTTP。
源站 Nginx 又把 HTTP 跳 HTTPS。
CDN 和源站之间来回跳转。
```

解决：

```text
走 CDN：让 CDN 做 HTTP -> HTTPS，源站 Nginx 不跳。
不走 CDN：让 Nginx 做 HTTP -> HTTPS。
```

### 7. 修改文章后需要重启 Nginx 吗

不需要。

文章更新流程只是替换静态文件：

```text
hexo generate -> public/ -> 上传到 /opt/hexo-blog/html
```

Nginx 会直接读取新文件。

只有修改 Nginx 配置、证书配置、端口映射时，才需要：

```bash
sudo docker compose exec nginx nginx -t
sudo docker compose exec nginx nginx -s reload
```

### 8. 访问 404 页面但状态码不对

如果这样写：

```nginx
location / {
    try_files $uri $uri/ /404.html;
}
```

用户可能看到 404 页面，但 HTTP 状态码是 200。

更推荐：

```nginx
location / {
    try_files $uri $uri/ =404;
}

error_page 404 /404.html;
```

这样状态码更准确。

### 9. Docker Nginx 访问不到静态文件

检查挂载：

```yaml
volumes:
  - ./html:/usr/share/nginx/html:ro
```

检查服务器目录：

```bash
ls -la /opt/hexo-blog/html
```

检查容器内目录：

```bash
sudo docker compose exec nginx ls -la /usr/share/nginx/html
```

如果容器内看不到 `index.html`，说明挂载目录或上传路径错了。

### 10. 主题配置导致 Hexo 生成报错

如果使用 Stellar 等主题，常见报错可能不是 Hexo 本身问题，而是主题配置层级写错。

例如 `article.related_posts` 被写空、写错层级，或者把整个 `article` 覆盖成 `null`，都可能导致生成失败。

建议检查：

```text
_config.yml
_config.stellar.yml
themes/stellar/_config.yml
```

相关文章配置可以先关闭：

```yaml
article:
  related_posts:
    enable: false
```

如果想开启相关文章，再安装对应插件并按主题文档配置。

### 11. 主题语言配置不生效

简体中文通常应该写：

```yaml
language: zh-CN
```

不要写成：

```yaml
language: zh-TW
```

`zh-TW` 是繁体中文，`zh-CN` 才是简体中文。

如果主题还有自己的语言文件，也要确认主题目录下是否存在对应的 `zh-CN.yml`。

## 总结

Hexo 部署到自己的服务器，本质上只有三件事：

```text
1. 本地生成静态文件。
2. 上传到服务器目录。
3. 用 Nginx 把这个目录发布出去。
```

Docker Nginx 方案的核心配置是：

```text
/opt/hexo-blog/html -> /usr/share/nginx/html
```

不用 CDN 时，DNS 直接 A 到 ECS，Nginx 负责 HTTPS 跳转。

使用 CDN 时，DNS CNAME 到 CDN，CDN 负责 HTTPS 跳转，源站 Nginx 不要再跳 HTTPS。

把这几条关系理清楚，后续无论是更新文章、配置证书、排查 DNS，都会简单很多。
