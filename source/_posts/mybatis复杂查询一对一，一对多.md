---
title: mybatis复杂查询一对一，一对多
categories: [后端开发, MyBatis]
tags: [Java, MyBatis]
date: 2024-11-29 21:08:16
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/avatar.jpg
---
# 一对一
```java
@Data
public class User {
    int id;
    String name;
    int age;
    UserDetail detail;
}

@Data
public class UserDetail {

    int id;
    String des;
}
```

```xml
    <select id="selectAllUser" resultMap="UserAndUserDetail">
        select * from user
    </select>

    <select id="selectUserById" resultMap="UserAndUserDetail">
        select * from user where id = #{id}
    </select>

    <resultMap id="UserAndUserDetail" type="com.example.entity.User">
        <id property="id" column="id"/>
        <result property="name" column="name"/>
        <result property="age" column="age"/>
        <association property="detail" column="id" select="selectUserDetails"/>
    </resultMap>

    <select id="selectUserDetails" resultType="com.example.entity.UserDetail">
        select * from user_detail where id = #{id}
    </select>
```
这段 MyBatis 配置代码用于查询 `user` 表的数据，并通过关联查询获取 `user_detail` 表的数据。以下是详细解释：

## 代码结构

1. **`selectAllUser` 查询**：
   - 这是一个主查询，用于从 `user` 表中选择所有用户。
   - 使用 `resultMap="UserAndUserDetail"` 指定结果映射。

2. **`resultMap` (`UserAndUserDetail`)**：
   - 定义了如何将查询结果映射到 `User` 对象。
   - `id` 元素将数据库的 `id` 列映射到 `User` 对象的 `id` 属性。
   - `result` 元素将 `name` 和 `age` 列映射到相应的属性。
   - `association` 元素用于处理一对一的关联关系：
     - `property="detail"` 指定 `User` 对象中 `detail` 属性。
     - `column="id"` 用于传递给关联查询的参数。
     - `select="selectUserDetails"` 指定关联查询的 ID。

3. **`selectUserDetails` 查询**：
   - 这是一个关联查询，用于根据 `id` 从 `user_detail` 表中获取详细信息。
   - 使用 `resultType="com.example.entity.UserDetail"` 指定结果映射到 `UserDetail` 对象。

## 运行流程

- 执行 `selectAllUser` 查询时，MyBatis 将从 `user` 表中获取所有用户。
- 对于每个用户，MyBatis 会根据 `association` 元素调用 `selectUserDetails`，传递当前用户的 `id`。
- `selectUserDetails` 查询返回的结果将映射到 `User` 对象的 `detail` 属性中。

# 一对多
```java
@Data
public class User {
    int id;
    String name;
    int age;
    List<Book> books;
}

@Data
public class Book {

    int bid;
    String title;
}
```
```xml
    <select id="selectAllUser" resultMap="UserAndUserDetail">
        select * from user
    </select>

    <select id="selectUserById" resultMap="UserAndUserDetail">
        select * from user where id = #{id}
    </select>

    <resultMap id="UserAndUserDetail" type="com.example.entity.User">
        <id property="id" column="id"/>
        <result property="name" column="name"/>
        <result property="age" column="age"/>
        <collection property="books" column="id" select="selectBook"/>
    </resultMap>

    <select id="selectBook" resultType="com.example.entity.Book">
        select * from book where uid = #{id}
    </select>
```
这段 MyBatis 配置代码用于查询 `user` 表的数据，并通过关联查询获取 `book` 表的数据。以下是详细解释：

## 代码结构

1. **`selectAllUser` 查询**：
   - 从 `user` 表中选择所有用户。
   - 使用 `resultMap="UserAndUserDetail"` 指定结果映射。

2. **`selectUserById` 查询**：
   - 根据 `id` 从 `user` 表中选择特定用户。
   - 同样使用 `resultMap="UserAndUserDetail"`。

3. **`resultMap` (`UserAndUserDetail`)**：
   - 定义了如何将查询结果映射到 `User` 对象。
   - `id` 元素将数据库的 `id` 列映射到 `User` 对象的 `id` 属性。
   - `result` 元素将 `name` 和 `age` 列映射到相应的属性。
   - `collection` 元素用于处理一对多的关联关系：
     - `property="books"` 指定 `User` 对象中 `books` 属性
     - `column="id"` 用于传递给关联查询的参数。
     - `select="selectBook"` 指定关联查询的 ID。

4. **`selectBook` 查询**：
   - 根据用户 `id` 从 `book` 表中获取该用户的书籍。
   - 使用 `resultType="com.example.entity.Book"` 指定结果映射到 `Book` 对象。

## 运行流程

- **`selectAllUser`** 和 **`selectUserById`** 查询：
  - 从 `user` 表中获取用户信息。
  - 对于每个用户，MyBatis 会根据 `collection` 元素调用 `selectBook`，传递当前用户的 `id`。
  - `selectBook` 查询返回的结果将映射到 `User` 对象的 `books` 属性中。


