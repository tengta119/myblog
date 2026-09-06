---
title: SQL学习总结
categories:
  - 数据库
tags:
  - SQL
  - 索引
date: 2025-03-31 20:21:30
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSQL%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png
---
>https://www.bilibili.com/video/BV1UE41147KC
# 第二章

```sql
from -> where -> order by .. (desc) -> limit
```





## SELECT

```sql
select * 
from customers 
where customer_id = 1 
order by first_name;

select first_name, points + 10 as discount_factor from customers 

select distinct state from customers
```



## WHERE

```sql
select * from customers where state != 'VA'
select * from orders where order_date > '2018-01-01'
-- 运算符 >, <, >=, <=, !=, <> 
```



## 运算符：AND, OR, NOT, IN, BETWEEN, LIKE, REGEXP, NULL

```sql
select * from customers where birth_date > '1990-01-01' or points > 1000;
select * from customers where birth_date > '1800-01-01' and points > 1000;
select * from customers where not birth_date > '1990-01-01'

SELECT * FROM products where quantity_in_stock in (49, 38, 72)

SELECT * FROM customers where birth_date between '1990-01-01' and '2000-01-01'

SELECT * FROM customers where address like '%trail%';
SELECT * FROM customers where phone like '%9'

select * from customers where first_name regexp 'ELKA|AMBUR';
select * from customers where last_name regexp 'ey$|on$';
select * from customers where last_name regexp '^my|se';
select * from customers where last_name regexp 'b[ru]';

select * from orders where shipper_id is null;
```



## 字句： ORDER BY, LIMIT

```sql
select * from customers order by points desc limit 3;
```



# 第三章

## JOIN ON

```sql
-- 连接表
select p.name, o.quantity, o.unit_price 
from order_items as o join products as p on o.product_id = p.product_id;

-- 连接另一个数据库
select * from order_items as oi join sql_inventory.products p on oi.product_id = p.product_id

-- 自连接
select e.reports_to, e.first_name, m.first_name as manager 
from employees as e 
join employees as m on e.reports_to = m.employee_id

-- 多表连接
select p.payment_id, c.name, pm.name from payments as p 
	join clients as c on p.client_id = c.client_id
    join payment_methods as pm on p.payment_method = pm.payment_method_id

```
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSQL%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png)


**复合主键**

```sql
-- 复合连接条件
select * from order_items as oi 
	join order_item_notes as oin on oi.order_id = oin.order_Id and oi.product_id = oin.product_id
```



```sql
-- 外连接
select p.product_id, p.name, ot.quantity from products as p 
	left join order_items as ot on p.product_id = ot.product_id;

-- 多表外连接
select os.order_date, os.order_id, cs.first_name, ss.name, oss.name from orders as os 
	left join customers as cs on os.customer_id = cs.customer_id
    left join shippers as ss on os.shipper_id = ss.shipper_id
    left join order_statuses as oss on os.status = oss.order_status_id
    
-- 自外连接
select e.employee_id, e.first_name, m.first_name as manager from employees as e 
	left join employees as m on e.reports_to = m.employee_id
```

```sql
-- using 字句
select ps.date, cs.name as client, ps.amount, pms.name from payments as ps 
	left join clients as cs using(client_id)
    left join payment_methods as pms on ps.payment_method = pms.payment_method_id
```

```sql
-- 交叉连接
select * from shippers cross join products
```

```sql
-- union
select customer_id, first_name, points, 'Bronze' as type from customers 
	where points < 2000 

union
select customer_id, first_name, points, 'Silver' as type from customers 
	where points between 2000 and 3000
union
select customer_id, first_name, points, 'Gold' as type from customers 
	where points > 3000 order by first_name
```





# 第四章

## INSERT, CREATE, UPDATE, DELETE

```sql
-- insert into 
insert into products (name, quantity_in_stock, unit_price) 
value ('apple', 114, 1.14), ('pen', 1145, 1.45), ('banaer', 104, 10.4) 

-- 创建表
create table invoices_archive
	-- 子查询
select invoices.invoice_id, clients.name, invoices.payment_date from invoices 
	left join clients using(client_id) 
    where invoices.payment_date is not null
    
-- 更新多行
update customers set points = points + 50 where birth_date < '1990-01-01'

update orders set comments = 'Gold customer' 
	-- 子查询
	where customer_id in (select customer_id from customers where points > '3000')
	
-- 删除
delete from invoices 
	-- 子查询
	where client_id = (select client_id from clients where name = 'Myworks')
```



# 第五章 

## 聚合函数

```sql
select max(invoice_total), 
	   min(invoice_total), 
	   avg(invoice_total), 
	   sum(invoice_total), 
	   count(distinct client_id) as highest 
from invoices
where invoice_date > '2019-07-01'
```



## ORDER BY, HAVING, WITH ROLLUP

```sql
-- 除了from 其他关键字是可选的
from -> where -> group by -> order by
```



```sql
select client_id, sum(invoice_total) as total_sales 
from invoices 
where invoice_date >= '2019-07-01'
group by client_id
order by total_sales desc

select ps.date, pms.name as payment_method, sum(ps.amount) as total_payments 
from payments as ps
left join payment_methods as pms on ps.payment_method = pms.payment_method_id
group by ps.date, pms.name 

-- having 根据聚合后的数据判断，where根据表中的数据进行判断
--  在 orders 表中先根据 customer_id 进行分组，每一组都有一些 order_id ,连接 order_items 表，根据 order_id查询  quantity 和 unit_price，这样 customer_id 对应多个 order_id ， 而 order_id 又对应多个 product_id，最后调用 sum()方法
select os.customer_id, cs.first_name, sum(ois.quantity * ois.unit_price) as money from orders as os
join customers as cs using(customer_id)
join order_items as ois using(order_id)
where cs.state = 'VA'
group by os.customer_id
having money > 100

-- with rollup 汇总数据 
select pms.name, sum(amount) from payments as ps
join payment_methods as pms on ps.payment_method = pms.payment_method_id 
group by pms.name with rollup
```



# 第六章 复杂查询

```sql
-- 查找工资高于平均值的员工
select * from employees
where employees.salary > (select avg(employees.salary) from employees)

select * from clients
where clients.client_id not in (select invoices.client_id from invoices)

-- 查询购买了 lettuce(product_id = 3) 的顾客 
select distinct customer_id, first_name, last_name from customers as c
join orders as o using (customer_id)
join order_items as ois on (o.order_id = ois.order_id) 
where ois.product_id = 3
```



## 关键字 all, any 

```sql
-- invoice_total 大于 all 后面的集合
select * from invoices where invoice_total > all (
	select invoice_total from invoices where client_id = 3
)

-- = any 等价于 in
```



## 相关子查询

```sql
-- 对于每一个用户返回他大于它自己的平均值的帐单
select * from invoices as i
where i.invoice_total > (
	select avg(invoices.invoice_total) from invoices
    where invoices.client_id = i.client_id
)
```

## EXISTS

```sql
-- 这是一条包含子查询的查询语句，子查询会返回一个结果集，例如(1, 2, 3...)，但当数据量很大时会严重印象性能
select * from clients
where client_id in (
    select client_id from invoices
)
-- 这条语句使用了exists，后面实际上会返回一个结果，true 或者 false
select * from clients as c
where exists (
	select client_id
    from invoices
    where client_id = c.client_id
)
SELECT * FROM products 
where not exists (
	select product_id from order_items
	where order_items.product_id = products.product_id
)

```



## SELECT, FROM 中的子查询







# 第七章

## 数值函数

```sql
round()
truncate()
ceiling()
floor()
abs()
rand()
```



## 字符串函数

```sql
length()
upper()
lower()
ltrim()
rtrim()
trim()
left()
right()
substring()
locate()
replace()
concat()

```



## 日期函数

```sql
now()
curdate()
curtime()
extract(day|year from now())

SELECT * 
FROM orders
where year(order_date) >= year(now())
```



## IFNULL, COALESCE

```sql
select order_id, ifnull(shipper_id, 'not assigned') as shipper
from orders
-- coalesce() 返回参数的第一个非空值
select order_id, coalesce(shipper_id, comments, 'not assigned') as shipper
from orders
```



## IF函数, CASE运算符

```sql
select 
	p.product_id, 
    p.name, 
    count(*) as orders,
    if(count(*) > 1, 'Many times', 'Once') as fre
from products as p 
join order_items using(product_id)
group by product_id, name

SELECT 
	concat(first_name, ' ', last_name) as customer,
	case
		when points > 3000 then 'Gold' 
        when points > 2000 then 'Silver'
        else 'Bronze'
	end as 'category'
FROM customers

```



# 第八章 - 视图

视图不存放数据，它只是查询的结果

视图可以简化查询，也可以提供一层抽象

```sql
CREATE VIEW clients_balance AS
SELECT 
  invoices.client_id, 
  clients.`name`,  
  SUM(invoices.invoice_total - invoices.payment_total) as balance 
from invoices
LEFT JOIN clients USING(client_id)
GROUP BY invoices.client_id

-- 如果视图中没有使用 union、聚合函数。。。那么这个视图是可更新的
CREATE OR REPLACE VIEW invoices_with_balance AS
SELECT 
  invoice_id,
  number,
  client_id,
  invoice_total,
  payment_total,
  invoice_total - payment_total as balance,
  invoice_date,
  due_date,
  payment_date
from invoices
where (invoice_total - payment_total) > 0

CREATE OR REPLACE VIEW invoices_with_balance AS
SELECT 
  invoice_id,
  number,
  client_id,
  invoice_total,
  payment_total,
  invoice_total - payment_total as balance,
  invoice_date,
  due_date,
  payment_date
from invoices
where (invoice_total - payment_total) > 0
-- 这条语句会防止 update 或者 delete 将行从视图中删除
WITH CHECK OPTION
```



# 第九章 - 存储过程

存储过程是一组为了完成特定任务而预先编译并存储在数据库中的 SQL 语句集合。你可以把它想象成编程里的函数，它接收输入参数，执行一系列操作，还能返回结果

```sql
delimiter $$
CREATE PROCEDURE get_clients()
BEGIN
  SELECT * from clients;
end$$
delimiter ;

delimiter $$
CREATE PROCEDURE get_invoices_with_balance()
BEGIN
	--          视图
  SELECT * from invoices_with_balance 
  where balance > 0;
end$$
delimiter ;

-- 参数
CREATE DEFINER=`root`@`%` PROCEDURE `get_invoices_by_client`(client_id int)
BEGIN
    SELECT * from invoices 
    WHERE invoices.client_id = client_id;
END

CREATE DEFINER=`root`@`%` PROCEDURE `get_payments`(client_id INT(4), payment_method_id TINYINT(1))
BEGIN
  SELECT * FROM payments
  WHERE payments.client_id = IFNULL(client_id, payments.client_id) AND 
  payments.payment_method = IFNULL(payment_method_id, payments.payment_method);
END
```



## 函数

函数只能返回单一值



# 第十章 触发器

触发器是在插入、更新和删除语句前后自动执行的一堆SQL代码

```sql
delimiter $$

CREATE TRIGGER payments_after_insert
    AFTER INSERT on payments
    -- 每对payments插入数据，都会触发触发器
    FOR EACH ROW
BEGIN
    UPDATE invoices
    SET payment_total = payment_total + NEW.amount
    WHERE invoice_id = NEW.invoice_id;
END $$

delimiter ;


delimiter $$

CREATE TRIGGER payments_after_delete
    AFTER DELETE on payments
    -- 每对payments插入数据，都会触发触发器
    FOR EACH ROW
BEGIN
    UPDATE invoices
    SET payment_total = payment_total - OLD.amount
    WHERE invoice_id = OLD.invoice_id;
END $$

delimiter ;
```

```sql
-- 查找触发器
SHOW TRIGGERS LIKE 'payments%'
-- 删除触发器
DROP TRIGGER if EXISTS payments_after_insert;
```

```sql
delimiter $$

DROP TRIGGER if EXISTS payments_after_insert $$

CREATE TRIGGER payments_after_insert
    AFTER INSERT on payments
    -- 每对payments插入数据，都会触发触发器
    FOR EACH ROW
BEGIN
    UPDATE invoices
    SET payment_total = payment_total + NEW.amount
    WHERE invoice_id = NEW.invoice_id;
    
    INSERT INTO payments_audit
    VALUES (NEW.client_id, NEW.date, NEW.amount, 'Insert', NOW());
END $$

delimiter ;

---------------------------------

delimiter $$

DROP TRIGGER if EXISTS payments_after_delete $$

CREATE TRIGGER payments_after_delete
    AFTER DELETE on payments
    -- 每对payments插入数据，都会触发触发器
    FOR EACH ROW
BEGIN
    UPDATE invoices
    SET payment_total = payment_total - OLD.amount
    WHERE invoice_id = OLD.invoice_id;
    
        INSERT INTO payments_audit
    VALUES (OLD.client_id, OLD.date, OLD.amount, 'Delete', NOW());
END $$

delimiter ;
```



## 事件

事件是根据计划执行的任务或者一些 `SQL` 语句

```sql
DELIMITER $$
CREATE EVENT yearly_delete_stale_audit_rows
ON SCHEDULE
    EVERY 1 YEAR STARTS '2019-01-01' ENDS '2029-01-01'
DO BEGIN
    DELETE FROM payments_audit
    WHERE action_date < NOW() - INTERVAL 1 YEAR;
END $$
DELIMITER ;
```



# 第十一章

**ACID**

* 原子性
* 一致性
* 隔离性
* 持久性

```sql
START TRANSACTION;

INSERT INTO orders (customers_id, order_date, statue)
VALUES (1, '2019-01-01', 1);

INSERT INTO order_items
VALUES (LAST_INSERT_ID(), 1, 1, 1);

-- 提交所有操作
COMMIT;
-- 撤销所有操作
-- ROLLBACK
```



## 并发问题

* 丢失更新
* 脏读
* 不可重复读
* 幻读

## 隔离级别

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSQL%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-02.png)


### 读未提交

会遇到所有并发问题

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED；
START TRANSACTION;
SELECT points
from customers
WHERE customer_id = 1;
COMMIT;

```



### 不可重复读

解决了 **脏读** 问题，但会遇到 **不开重复** 问题

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED；
START TRANSACTION;
SELECT points
from customers
WHERE customer_id = 1;
-- 由于不可重复，第二个查询结果可能会与第一个不一致
SELECT points
from customers
WHERE customer_id = 1;
COMMIT;
```



### 可重复读

解决了 **不可重复** 问题， 但会遇到 **幻读** 问题

```sql
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT *
from customers
WHERE state = 'VA';
COMMIT;

```



# 第十二章 - 数据类型



# 第十三章 - 设计数据库

* 概念模型
* 逻辑模型
* 实体模型

---

* 主键：唯一标识表里每条记录的列
* 外键：
  * 外键约束：
* 复合主键：		

![123](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSQL%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-03.png)




# 第十四章 - 索引

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSQL%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-04.png)


```sql
-- 建立了一个索引
CREATE INDEX idx_state on customers (state);
```

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSQL%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-05.png)




## 前缀索引、全文索引、复合索引

```sql
-- 每个字符串选择前二十个字符建立索引
CREATE INDEX idx_lastname on customers (last_name(20))

-- 全文索引
CREATE FULLTEXT INDEX idx_title_body on posts (title, body);
SELECT *, MATCH(title, body) AGAINST('react redux')
FROM posts
WHERE MATCH(title, body) AGAINST('react redux')

-- 复合索引
-- 在建立索引时，建议基数更大的放在前面
CREATE INDEX idx_state_points ON customers (state, points)
```



## 覆盖索引

在建立二级索引时，主键会自动加入二级索引中


