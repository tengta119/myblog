---
title: 体检预防系统
categories:
  - 后端开发
  - SpringBoot
tags:
  - Java
  - SpringBoot
  - MyBatis
  - Vue3
  - MySQL
date: 2024-11-17 17:14:31
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/avatar.jpg
---

# 前言
* 此项目是学完springboot所敲的第一个项目，后端只涉及springboot,MyBatis，没有其他额外的技术，因此比较简单
* 此项目中比较有意思的是套餐式体检预约，会在此文章详细介绍
---
# 一、实现功能
登录注册，修改密码，单项目体检预约，套餐式体检预约，数据统计
**套餐预约**
![演示01](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imghealth-01.png#pic_center)
**数据统计**
![演示02](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imghealth-02.png#pic_center)

# 二、数据库设计
![演示03](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imghealth-03.png#pic_center)
**examination_order**为体检订单，既可以是套餐体检也可以是普通体检，**examination_package**为套餐体检，里面可以包含多个普通体检，**physical_examination**就是普通体检，而**examination_type**为体检类型，指名普通体检是什么类型例如预防性体检项目、健康筛查体检
**examination_order**
![演示04](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imghealth-04.png#pic_center)
```sql
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for examination_order
-- ----------------------------
DROP TABLE IF EXISTS `examination_order`;
CREATE TABLE `examination_order`  (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '订单号',
  `user_id` int(11) NULL DEFAULT NULL COMMENT '用户id',
  `doctor_id` int(11) NULL DEFAULT NULL COMMENT '医生id',
  `examination_id` int(11) NULL DEFAULT NULL COMMENT '体检项目id',
  `order_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '订单类型',
  `reserve_date` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '预约日期',
  `start_time` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '开始时间',
  `end_time` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '结束时间',
  `file` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '检测报告地址',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '评语',
  `money` int(255) NULL DEFAULT NULL COMMENT '费用',
  `status` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '订单状态',
  `create_time` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '创建时间',
  `check_time` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '检查时间',
  `feedback` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '审批反馈',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 23 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci COMMENT = '体检预约订单' ROW_FORMAT = DYNAMIC;

SET FOREIGN_KEY_CHECKS = 1;
```
# 三、用户预约
```java
    public void add(ExaminationOrder examinationOrder) {
        examinationOrder.setCreateTime(DateUtil.now());
        Account currentUser = TokenUtils.getCurrentUser();

        examinationOrder.setUserId(currentUser.getId());

        //预约的项目
        Integer examinationId = examinationOrder.getExaminationId();
        if ("普通体检".equals(examinationOrder.getOrderType())) {

            // 判断当前是否存在相同项目待审批的订单
            ExaminationOrder order = examinationOrderMapper.selectByExaminationIdAndOrderType(examinationOrder.getReserveDate(), examinationId, "普通体检", currentUser.getId());
            if (order != null) {
                throw new CustomException("500", "您已经预约过该项目" + order.getReserveDate() + "的检查，请不要重复预约");
            }
            PhysicalExamination physicalExamination = physicalExaminationService.selectById(examinationId);
            examinationOrder.setMoney(physicalExamination.getMoney());
            examinationOrder.setDoctorId(physicalExamination.getDoctorId());
        } else {
            //套餐体检
            ExaminationOrder order = examinationOrderMapper.selectByExaminationIdAndOrderType(examinationOrder.getReserveDate(), examinationId, "套餐体检", currentUser.getId());
            if (order != null) {
                throw new CustomException("500", "您已经预约过该项目" + order.getReserveDate() + "的检查，请不要重复预约");
            }
            ExaminationPackage examinationPackage = examinationPackageService.selectById(examinationId);
            examinationOrder.setMoney(examinationPackage.getMoney());
            examinationOrder.setDoctorId(examinationPackage.getDoctorId());
        }
        Date date = new Date();
        String orderNo = DateUtil.format(date, "yyyyMMdd") + date.getTime();
        examinationOrder.setOrderNo(orderNo);
        examinationOrder.setStatus("待审批");
        examinationOrderMapper.insert(examinationOrder);
    }
```

# 四、数据统计
```java
    @GetMapping("/getCountData")
    public Result getCountData() {
        List<ExaminationOrder> examinationOrders = examinationOrderMapper.selectAll(null);
        //普通体检金额统计
        Integer PhysicalExaminationMoney = examinationOrders.stream()
                .filter(o -> o.getOrderType().equals("普通体检"))
                .filter(o -> o.getStatus().equals("待检查") || o.getStatus().equals("待上传报告") || o.getStatus().equals("已完成"))
                .map(ExaminationOrder::getMoney)
                .reduce(Integer::sum).orElse(0);
        //体检套餐金额统计
        Integer PhysicalExaminationPackageMoney = examinationOrders.stream()
                .filter(o -> o.getOrderType().equals("套餐体检"))
                .filter(o -> o.getStatus().equals("待检查") || o.getStatus().equals("待上传报告") || o.getStatus().equals("已完成"))
                .map(ExaminationOrder::getMoney)
                .reduce(Integer::sum).orElse(0);
        // 普通体检项目数量统计
        long physicalExaminationCount = physicalExaminationMapper.selectAll(null).size();
        // 套餐体检项目数量统计
        long examinationPackageCount = examinationPackageMapper.selectAll(null).size();

        HashMap<Object, Object> map = new HashMap<>();
        map.put("PhysicalExaminationMoney", PhysicalExaminationMoney);
        map.put("PhysicalExaminationPackageMoney", PhysicalExaminationPackageMoney);
        map.put("physicalExaminationCount", physicalExaminationCount);
        map.put("examinationPackageCount", examinationPackageCount);
        return Result.success(map);
    }

    @GetMapping("/lineData") //折线图
    public Result getLineData() {
        List<ExaminationOrder> examinationOrders = examinationOrderMapper.selectAll(null);
        //获取一个月的日期
        Date date = new Date();
        DateTime start = DateUtil.offsetDay(date, -30); //30天之前的日期、
        List<DateTime> dateTimes = DateUtil.rangeToList(start, date, DateField.DAY_OF_YEAR);
        List<String> dateStrList = dateTimes.stream().map(DateUtil::formatDate).sorted(Comparator.naturalOrder()).collect(Collectors.toList());
        ArrayList<Integer> moneyList = new ArrayList<>();
        for (String day : dateStrList) {
            // 统计当天的销售额
            Integer money = examinationOrders.stream().filter(o -> o.getCreateTime().contains(day))
                    .filter(o -> o.getStatus().equals("待检查") || o.getStatus().equals("待上传报告") || o.getStatus().equals("已完成"))
                    .map(ExaminationOrder::getMoney).reduce(Integer::sum).orElse(0);
            moneyList.add(money);
        }
        HashMap<Object, Object> map = new HashMap<>();
        map.put("dateStrList", dateStrList);
        map.put("moneyList", moneyList);
        return Result.success(map);
    }

    @GetMapping("/pieData") //柱状图
    public Result getPieData() {
        //name和value
        List<Title> titleList = titleService.selectAll(null);
        List<Map<String, Object>> list = new ArrayList<>();
        for (Title title : titleList) {
            HashMap<String, Object> map = new HashMap<>();
            map.put("name", title.getName());
            Integer count = doctorService.selectByTitleId(title.getId());
            map.put("value", count);
            list.add(map);
        }
        return Result.success(list);
    }

    @GetMapping("/barData") //饼状图
    public Result getBarData() {
        List<Office> officeList = officeService.selectAll(null);
        List<String> officeNames = officeList.stream().map(Office::getName).collect(Collectors.toList());
        ArrayList<Integer> list = new ArrayList<>();
        for (Office office : officeList) {
            // 统计当天的销售额
            Integer count = doctorService.selectByOfficeId(office.getId());
            list.add(count);
        }
        HashMap<Object, Object> map = new HashMap<>();
        map.put("officeList", officeNames);
        map.put("countList", list);
        return Result.success(map);
    }
```
# 五、关联查询
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imghealth-05.png#pic_center)
```xml
<!DOCTYPE mapper
        PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.example.mapper.ExaminationOrderMapper">

    <select id="selectAll" resultType="com.example.entity.ExaminationOrder">
        select examination_order.*, user.name as userName, doctor.name as doctorName, physical_examination.name as examinationName
        from `examination_order`
        left join user on examination_order.user_id = user.id
        left join doctor on examination_order.doctor_id = doctor.id
        left join physical_examination on examination_order.examination_id = physical_examination.id
        <where>
            <if test="orderNo != null"> and examination_order.order_no = #{orderNo}</if>
            <if test="orderType != null"> and examination_order.order_type = #{orderType}</if>
            <if test="status != null"> and examination_order.status = #{status}</if>
            <if test="userId != null"> and examination_order.user_id = #{userId}</if>
            <if test="doctorId != null"> and examination_order.doctor_id = #{doctorId}</if>
            <if test="reserveDate != null"> and examination_order.reserve_date = #{reserveDate}</if>
        </where>
        order by examination_order.id desc
    </select>

    <delete id="deleteById">
        delete from `examination_order`
        where id = #{id}
    </delete>

    <!-- insert into examinationOrder (username, password, ...) values ('examinationOrder', 'examinationOrder', ...) -->
    <insert id="insert" parameterType="com.example.entity.ExaminationOrder" useGeneratedKeys="true">
        insert into `examination_order`
        <trim prefix="(" suffix=")" suffixOverrides=",">
            <if test="id != null">id,</if>
            <if test="orderNo != null">order_no,</if>
            <if test="userId != null">user_id,</if>
            <if test="doctorId != null">doctor_id,</if>
            <if test="examinationId != null">examination_id,</if>
            <if test="orderType != null">order_type,</if>
            <if test="reserveDate != null">reserve_date,</if>
            <if test="startTime != null">start_time,</if>
            <if test="endTime != null">end_time,</if>
            <if test="file != null">file,</if>
            <if test="comment != null">comment,</if>
            <if test="money != null">money,</if>
            <if test="status != null">status,</if>
            <if test="createTime != null">create_time,</if>
            <if test="checkTime != null">check_time,</if>
            <if test="feedback != null">feedback,</if>
        </trim>
        <trim prefix="values (" suffix=")" suffixOverrides=",">
            <if test="id != null">#{id},</if>
            <if test="orderNo != null">#{orderNo},</if>
            <if test="userId != null">#{userId},</if>
            <if test="doctorId != null">#{doctorId},</if>
            <if test="examinationId != null">#{examinationId},</if>
            <if test="orderType != null">#{orderType},</if>
            <if test="reserveDate != null">#{reserveDate},</if>
            <if test="startTime != null">#{startTime},</if>
            <if test="endTime != null">#{endTime},</if>
            <if test="file != null">#{file},</if>
            <if test="comment != null">#{comment},</if>
            <if test="money != null">#{money},</if>
            <if test="status != null">#{status},</if>
            <if test="createTime != null">#{createTime},</if>
            <if test="checkTime != null">#{checkTime},</if>
            <if test="feedback != null">#{feedback},</if>
        </trim>
    </insert>

    <update id="updateById" parameterType="com.example.entity.ExaminationOrder">
        update `examination_order`
        <set>
            <if test="orderNo != null">
                order_no = #{orderNo},
            </if>
            <if test="userId != null">
                user_id = #{userId},
            </if>
            <if test="doctorId != null">
                doctor_id = #{doctorId},
            </if>
            <if test="examinationId != null">
                examination_id = #{examinationId},
            </if>
            <if test="orderType != null">
                order_type = #{orderType},
            </if>
            <if test="reserveDate != null">
                reserve_date = #{reserveDate},
            </if>
            <if test="startTime != null">
                start_time = #{startTime},
            </if>
            <if test="endTime != null">
                end_time = #{endTime},
            </if>
            <if test="file != null">
                file = #{file},
            </if>
            <if test="comment != null">
                comment = #{comment},
            </if>
            <if test="money != null">
                money = #{money},
            </if>
            <if test="status != null">
                status = #{status},
            </if>
            <if test="createTime != null">
                create_time = #{createTime},
            </if>
            <if test="checkTime != null">
                check_time = #{checkTime},
            </if>
            <if test="feedback != null">
                feedback = #{feedback},
            </if>
        </set>
        where id = #{id}
    </update>

</mapper>
```
<font color="red">注意</font>属性的名称前端与后端要保持一致，否则文字会无法显示

