---
title: 基于servlet的文件上传
categories: [开发]
tags: [Java]
date: 2024-09-17 17:10:15
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/avatar.jpg
---



# 前言
基于servlet可以实现前后端分离，前端的html页面中可以用form表单，后端可以在service方法中实现上传与下载

# 上传文件
## 前端upload.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>文件上传</title>
</head>
<body>
    <form method="post" enctype="multipart/form-data" action="uploadServlet">
        姓名：<input type="text" name="uname"> <br>
        文件：<input type="file" name="myFile"> <br>
        <button>提交</button>

    </form>
</body>
</html>
```
   - `<form method="post" enctype="multipart/form-data" action="uploadServlet">`: 定义了一个表单元素，它具有以下属性：
    - `method="post"`: 指定表单数据通过HTTP POST方法发送到服务器。POST方法允许发送大量数据，且数据不会在URL中显示。
    - `enctype="multipart/form-data"`: 指定表单数据的编码类型。因为表单包含文件上传，所以必须使用这种编码类型。
    - `action="uploadServlet"`: 指定表单数据提交到的服务器端地址。这里，表单数据将被发送到名为 `uploadServlet` 的服务器端处理程序。
     - `姓名：<input type="text" name="uname">`: 创建了一个文本输入框，用户可以输入自己的姓名。`name="uname"` 属性是表单数据提交到服务器时使用的键名。
     - `文件：<input type="file" name="myFile">`: 创建了一个文件选择框，用户可以选择要上传的文件。`name="myFile"` 是提交到服务器的键名。
     - `<button>提交</button>`: 创建了一个按钮，用户点击后，表单数据将被提交到服务器。按钮没有指定 `type` 属性，默认为 `submit` 类型。

## 后端UploadServlet
```java
@WebServlet("/uploadServlet")
@MultipartConfig
public class UploadServlet extends HttpServlet
{
    @Override
    protected void service(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
    {
        System.out.println("文件上传");
        //请求的编码
        request.setCharacterEncoding("utf-8");
        //获取普通表单项
        String uname = request.getParameter("uname");
        System.out.println("uname:"+uname);
        //获取part对象
        Part part = request.getPart("myFile");
        String fileName = part.getSubmittedFileName();
        System.out.println("fileName:"+fileName);
        String realPath = request.getServletContext().getRealPath("/");
        System.out.println("realPath:"+realPath);
        part.write(realPath+"/"+fileName);

    }
}
```

- `String uname = request.getParameter("uname");`: 获取表单中名为 `uname` 的普通表单项的值。
- `Part part = request.getPart("myFile");`: 通过 `getPart` 方法获取表单中名为 `myFile` 的文件上传部分的 `Part` 对象。
- `String fileName = part.getSubmittedFileName();`: 从 `Part` 对象中获取上传文件的原始文件名。
- `String realPath = request.getServletContext().getRealPath("/");`: 获取Web应用程序的根目录的绝对路径。
- `part.write(realPath+"/"+fileName);`: 将上传的文件写入到Web应用程序的根目录下，文件名使用原始文件名。


# 下载文件
## 前端download.html
==在html中\<a href="">当浏览器无法解析href的地址会自动下载，也可设置download直接下载==
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>文件下载</title>
</head>
<body>

    <a href="down/thisZIP.zip">压缩文件</a>
    <hr>
    <a href="down/key.txt" download="thisIsMyText">文本文件</a>
    <a href="down/57.png" download="thisIsMyPng">图片文件</a>

    <hr>
    <form action="downloadServlet">
        文件名： <input type="text" name="fileName" placeholder="请输入要下载的文件名">
        <button>下载</button>
    </form>
</body>
</html>
```
  - `<form action="downloadServlet">`: 创建了一个表单，其`action`属性设置为`downloadServlet`，这意味着表单数据将被发送到服务器端的`downloadServlet`处理程序。
    - `文件名： <input type="text" name="fileName" placeholder="请输入要下载的文件名">`: 在表单中添加了一个文本输入框，用户可以在其中输入要下载的文件名。`name="fileName"`属性指定了表单提交时该输入框的键名，`placeholder`属性提供了输入框的提示信息。
    - `<button>下载</button>`: 添加了一个按钮，用户点击后，表单会被提交，发送用户输入的文件名到服务器端的`downloadServlet`。

## 后端DownloadServlet
```java
@WebServlet("/downloadServlet")
public class DownloadServlet extends HttpServlet
{
    protected void service(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
    {
        System.out.println("文件下载");
        request.setCharacterEncoding("utf-8");
        response.setCharacterEncoding("utf-8");
        String parameter = request.getParameter("fileName");
        if (parameter == null || parameter.trim().isEmpty())
        {
            response.getWriter().write("请输入要下载的文件名");
            response.getWriter().close();
            return;
        }
        String path = request.getServletContext().getRealPath("/down/");
        File file = new File(path + parameter);
        if (file.exists() && file.isFile())
        {
            response.setContentType("application/octet-stream");
            response.setHeader("Content-Disposition", "attachment;filename=" + parameter);
            FileInputStream in = new FileInputStream(file);
            ServletOutputStream out = response.getOutputStream();
            byte[] bytes = new byte[1024];
            int len = 0;
            while ((len = in.read(bytes)) != -1)
            {
                out.write(bytes, 0, len);
            }
            out.close();
            in.close();

        }
        else
        {
            response.getWriter().write("文件不存在请重试");
            response.getWriter().close();
        }
    }
}
```
这段Java代码定义了一个名为 `DownloadServlet` 的类，它扩展了 `HttpServlet` 类，用于处理HTTP请求，特别是文件下载请求。以下是代码中各个部分的详细解释：
- `@WebServlet("/downloadServlet")`: 这是一个注解，用于将 `DownloadServlet` 类映射到 `/downloadServlet` 路径，这样当客户端请求该路径时，这个Servlet会被调用。
- `String parameter = request.getParameter("fileName");`: 获取表单中名为 `fileName` 的参数值，即用户输入的文件名。
- `String path = request.getServletContext().getRealPath("/down/");`: 获取Web应用程序中 `/down/` 目录的绝对路径。
  - `response.setContentType("application/octet-stream");`: 设置响应的内容类型为 `application/octet-stream`，这是一个通用的二进制文件类型。
  - `response.setHeader("Content-Disposition", "attachment;filename=" + parameter);`: 设置响应头 `Content-Disposition`，指示浏览器应该提示用户下载文件，而不是尝试打开它。同时指定下载时的文件名。
  - `FileInputStream in = new FileInputStream(file);`: 创建一个 `FileInputStream` 对象，用于读取要下载的文件。
  - `ServletOutputStream out = response.getOutputStream();`: 获取响应的输出流，用于将文件内容发送到客户端。
  - `byte[] bytes = new byte[1024];`: 创建一个字节数组，作为缓冲区，用于读取文件内容。
  - `int len = 0; while ((len = in.read(bytes)) != -1) { ... }`: 使用循环读取文件内容，并将其写入到响应输出流
# 总结
对于上传文件，前端使用了一个HTML表单，其中包含了用户输入姓名和文件选择的功能。表单通过POST方法提交，并且设置了multipart/form-data的编码类型，以支持文件上传。后端使用了一个Servlet类（UploadServlet），它通过HttpServletRequest获取用户输入的姓名和上传的文件，然后将文件写入到Web应用程序的根目录下。
对于下载文件，前端同样使用了一个HTML表单，用户可以输入文件名来请求下载。表单通过POST方法提交，并且设置了action属性，指向了后端的DownloadServlet。后端使用了一个Servlet类（DownloadServlet），它通过HttpServletRequest获取用户输入的文件名，然后检查该文件是否存在，如果存在，则将文件内容以附件的形式发送给客户端。
