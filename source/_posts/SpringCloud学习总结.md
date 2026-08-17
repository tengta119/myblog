---
title: SpringCloud学习总结
categories: [后端开发, 微服务]
tags: [Java, SpringCloud]
date: 2025-01-31 21:52:29
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png
---
>[仓库地址](https://gitee.com/lbwxxc/cloud/tree/master/cloud-demo)
>[视频地址](https://www.bilibili.com/video/BV1UJc2ezEFU)



* 分布式：一个大应用分拆成多个小应用分布部署在各个机器上
	* 微服务(Spring Boot)（自治）：独立部署，数据隔离，单点故障
	 * 注册中心(Spring Cloud Alibaba Nacos)：服务发现，服务注册，配置中心
	 * 远程调用（Spring Cloud Open Feign）
     * 服务熔断（Spring Cloud Alibaba Sentinel）：快速失败，服务雪崩
     * 网关（Spring Cloud Gateway）：请求的路由，负载均衡
     * 分布式事务（Spring Cloud Alibaba Seata）
# Nacos 
## 注册中心
将微服务注册在nacos上
```yaml
spring:
  application:
    name: service-product
  cloud:
    nacos:
      server-addr: 127.0.0.1:8848
      config:
        import-check:
          enabled: false #禁用导入检查，如果没有导入会报错
server:
  port: 9000 #端口
```
并在主类中添加@EnableDiscoveryClient
```java
@EnableDiscoveryClient //开启服务发现
@SpringBootApplication
public class ProductMainApplication {
    public static void main(String[] args) {
        SpringApplication.run(ProductMainApplication.class, args);

    }
}
```
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png)
A 服务调用 B 服务，A 服务并不知道 B 服务当前在哪几台服务器有，哪些正常的，哪些服务已经下线。解决这个问题可以引入注册中心；
![nacos](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-02.png)
如果某些服务下线，我们其他人可以实时的感知到其他服务的状态，从而避免调用不可用的服务

##  RestTemplate
某些微服务可能有多个实例部署在不同的服务器上，通过负载均衡算法调用微服务减轻服务器的压力
```java
    @Autowired
    LoadBalancerClient loadBalancerClient;
    //负载均衡发送请求
    private Product getProductFromRemoteWithLoadBalance(Long productId) {
        ServiceInstance instance = loadBalancerClient.choose("service-product");
        //远程URL
        String address = "http://" + instance.getHost() + ":" + instance.getPort() + "/product/" + productId;

        RestTemplate restTemplate = new RestTemplate();
        log.info("远程请求：{}", address);
        return restTemplate.getForObject(address, Product.class);
    }
```
```java
@Configuration
public class OrderConfig {

    @LoadBalanced //注解式负载均衡
    @Bean
    RestTemplate restTemplate() {
        return new RestTemplate();
    }
}

    //基于注解的负载均衡
    private Product getProductFromRemoteWithLoadBalanceAnnotation(Long productId) {

        //"service-product"会被动态替换
        String address = "http://service-product/product/" + productId;

        log.info("远程请求：{}", address);
        return restTemplate.getForObject(address, Product.class);
    }
```
**restTemplate**第一次发起请求时，会首先向注册中心获取微服务访问地址列表，存入实例缓存，此后**实例缓存**会与**注册中心**实时更新，然后**restTemplate**根据**负载均衡算法**选择实例发起请求访问

## 配置中心
集中管理配置：将所有服务的配置信息统一管理，方便运维人员进行集中维护和管理
动态配置更新：当配置信息发生变化时，应用程序可以实时感知并自动更新配置，无需重启服务
* 名称空间（Namespace）：区分多套环境

* 分组（Group）：区分多种微服务

  * 数据集（Data-id）：区分多种配置


先在nacos中编写配置
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-03.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-04.png)

然后再application.yml中导入配置
```yaml
server:
  port: 8000
spring:
  profiles:
    active: dev
  application:
    name: service-order
  cloud:
    nacos:
      server-addr: 127.0.0.1:8848
      config:
        import-check:
          enabled: false
        namespace: ${spring.profiles.active:test}
---
spring:
  config:
    import:
      - nacos:common.yml?group=order
      - nacos:database.yml?group=order
    activate:
      on-profile: dev
---
spring:
  config:
    import:
      - nacos:common.yml?group=order
      - nacos:database.yml?group=order
    activate:
      on-profile: test
---
spring:
  config:
    import:
      - nacos:common.yml?group=order
      - nacos:database.yml?group=order
    activate:
      on-profile: prod
```
最后可以向正常的配置信息使用
```java
@RefreshScope //激活配置中心的自动刷新
@RestController()
public class OrderController {
    @Value("${order.timeout}")
    String orderTimeout;
    @Value("${order.auto-confirm}")
    String orderAutoConfirm;
}
```

# OpenFeign
## 远程调用
先在主类加上@EnableFeignClients开启开启Feign远程调用功能
```java
@FeignClient(value = "service-product", fallback = ProductFeignClientFallback.class) //Feign客户端
public interface ProductFeignClient {

    //mvc注解的两套使用逻辑
    //1、标注在controller上，是接收这样的请求
    //2、标注在FeignClient上，是发送这样的请求
    @GetMapping("/product/{id}")
    Product getProductById(@PathVariable("id") Long id);
}
```
```java
//兜底回调：如果远程调用失败则调用该类的相关方法
@Component
public class ProductFeignClientFallback implements ProductFeignClient {

    @Override
    public Product getProductById(Long id) {
        Product product = new Product();
        product.setId(id);
        product.setPrice(new BigDecimal("100.00"));
        product.setProductName("兜底数据 - " + product.getId());
        product.setNum(10);
        return product;
    }
}
```
## 超时控制
```yaml
spring:
    cloud:
        openfeign:
            client:
                config:
                    default: #默认
                        connect-timeout: 3000
                        read-timeout: 3000
                    service-product:
                        connect-timeout: 3000 #连接超时
                        read-timeout: 3000 #读取超时
```

# Sentinel
Sentinel 能在流量控制、熔断降级、系统负载保护等方面保障服务的稳定性与可靠性
* 定义资源：
  * 主流框架自动适配（Web Servlet、Dubbo、Spring Cloud、gRPC、Spring WebFlux、Reactor）；所有Web接口均为资源
  * 编程式：SphU API
  * 声明式：@SentinelResource
* 定义规则：
	* 流量控制规则
    * 熔断降级规则
    * 系统保护规则
    * 来源访问控制规则
   * 热点参数规则

设置sentinel
```yaml
spring:
    cloud:
        openfeign:
            client:
                config:
                    default: #默认
                        connect-timeout: 3000
                        read-timeout: 3000
                    service-product:
                        connect-timeout: 3000 #连接超时
                        read-timeout: 3000 #读取超时
        sentinel:
            transport:
                dashboard: 127.0.0.1:8858
            eager: true
            web-context-unify: false #是否为上下文
feign:
    sentinel:
        enabled: true
```

```yaml
spring:
    cloud:
        sentinel:
            transport:
                dashboard: 127.0.0.1:8858
            eager: true
            web-context-unify: false #是否为上下文
```
* `spring.cloud.sentinel.transport.dashboard`：指定 Sentinel 控制台的地址。这里设置为 127.0.0.1:8858，表示应用会将自身的监控信息发送到本地运行在 8858 端口的 Sentinel 控制台，方便在控制台上查看应用的流量、熔断等监控数据，并进行规则配置。
* `spring.cloud.sentinel.eager`：设置为 true 表示 Sentinel 在应用启动时就会主动连接 Sentinel 控制台，而不是在第一次请求时才去连接，这样可以更快地将应用的信息注册到控制台上。
* `spring.cloud.sentinel.web-context-unify`：设置为 false 表示关闭 Web 上下文统一处理。在这种情况下，Sentinel 会为每个不同的请求路径创建独立的上下文，从而可以针对不同的请求路径设置独立的限流规则和进行精准的流量统计。

```yaml
feign:
    sentinel:
        enabled: true
```
* `feign.sentinel.enabled`：设置为 true 表示开启 Feign 与 Sentinel 的集成。这样在使用 OpenFeign 进行远程调用时，Sentinel 会对这些调用进行监控和保护。当远程调用出现异常、超阈值等情况时，Sentinel 可以根据配置的规则进行熔断、限流等操作，从而提高系统的稳定性和可靠性。

```java
    @SentinelResource(value = "createOrder", blockHandler = "createOrderFallback") //定义资源
    @Override
    public Order createOrder(Long productId, Long userId) {
        Order order = new Order();
        //Product product = getProductFromRemoteWithLoadBalanceAnnotation(productId);
        Product product = productFeignClient.getProductById(productId);
        order.setUserId(userId);
        // 总金额
        order.setTotalAmount(product.getPrice().multiply(new BigDecimal(product.getNum())));
        order.setId(1L);
        order.setAddress("127.0.0.1");

        // 远程查询商品列表
        order.setProductList(Arrays.asList(product));
        return order;
    }

```
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-05.png)

以下是为你补充完整的关于 Sentinel 规则中流控、熔断、热点规则相关的详细介绍：

## 规则
### 流控
流量控制（简称流控）是一种通过对系统的输入流量进行调节，以确保系统在承受范围内稳定运行的机制。在 Sentinel 中，流控规则用于限制某个资源（如接口、方法等）的请求流量，防止过多的请求涌入导致系统过载、响应变慢甚至崩溃。
- **资源名**：唯一标识一个资源，通常为接口的路径或方法名。
- **阈值类型**：
    - **QPS（每秒查询率）**：限制资源每秒的请求数量。例如，将某个接口的 QPS 阈值设置为 100，表示该接口每秒最多处理 100 个请求。
    - **线程数**：限制同时处理该资源请求的线程数量。当并发线程数达到阈值时，新的请求将被拒绝。
 - **流控模式**：
 	- **直接**：这是 Sentinel 流控的默认模式，直接对配置规则的资源进行流量控制。一旦该资源的请求流量（根据设定的阈值类型，如 QPS 或线程数）超过设定的阈值，就会立即触发限流操作
 	- **关联**：该模式关注两个资源之间的关联关系。当关联资源的请求流量超过阈值时，会对当前配置规则的资源进行限流。即一个资源的流量情况会影响另一个关联资源的访问
 	- **链路**：根据请求的调用链路来进行流量控制。它只对从指定入口资源进入的请求进行限流，也就是说，只有当请求是从特定的入口资源发起并访问到当前配置规则的资源时，才会应用该限流规则 		
- **控制效果**：
    - **快速失败**：当请求超过阈值时，直接拒绝该请求，并抛出 `FlowException` 异常。
    - **Warm Up**：系统刚启动时，允许的请求量较低，随着时间推移逐渐增加到设定的阈值。适用于系统启动后需要一段时间来达到最佳性能的场景。
    - **排队等待**：将超过阈值的请求放入队列中，按照固定的速率依次处理，以平滑请求流量。
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-06.png)
![流控模式](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-07.png)
![流控效果](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-08.png)
### 熔断
熔断机制是一种在系统出现异常或故障时，自动切断对某个资源的访问，以防止故障扩散和保护系统稳定性的策略。当资源的调用出现大量错误或响应时间过长时，Sentinel 会触发熔断规则，暂时拒绝后续对该资源的请求，直到一段时间后再尝试恢复。
- **资源名**：标识要进行熔断保护的资源。
- **熔断策略**：
    - **慢调用比例**：当资源的响应时间超过设定的慢调用阈值，并且在统计时长内慢调用的比例超过设定的阈值时，触发熔断。例如，慢调用阈值为 500 毫秒，统计时长为 10 秒，慢调用比例阈值为 0.5，表示在 10 秒内，如果响应时间超过 500 毫秒的请求比例超过 50%，则触发熔断。
    - **异常比例**：当资源的异常调用比例超过设定的阈值时，触发熔断。例如，异常比例阈值为 0.2，表示在统计时长内，异常调用的请求比例超过 20% 时，触发熔断。
    - **异常数**：当资源在统计时长内的异常调用数量超过设定的阈值时，触发熔断。
- **熔断时长**：熔断触发后，拒绝请求的持续时间。
- **最小请求数**：在进行熔断判断前，需要满足的最小请求数量。只有当请求数达到该值时，才会进行熔断规则的判断。
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-09.png)
### 熔断降级
**断路器**：
![断路器](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-10.png)
**工作原理**：
![工作原理](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-11.png)
**熔断与兜底**:
![熔断与兜底](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-12.png)

### 热点
热点参数限流是一种针对资源调用中某些特定参数值的限流方式。在实际业务场景中，某些参数值可能会被频繁访问，成为热点数据。Sentinel 的热点规则可以对这些热点参数值进行单独的限流控制，以避免因热点数据的高并发访问导致系统性能下降。
- **资源名**：标识要进行热点限流的资源。
- **参数索引**：指定要进行限流的参数在方法参数列表中的索引位置。例如，方法 `public void doSomething(String param1, int param2)` 中，如果要对 `param2` 进行热点限流，则参数索引为 1。
- **单机阈值**：针对每个热点参数值的单机限流阈值。
- **统计窗口时长**：统计热点参数访问次数的时间窗口长度，单位为秒。
- **例外项**：可以针对某些特定的参数值设置不同的限流阈值。例如，对于大部分参数值，单机阈值为 100，但对于参数值为 `1001` 的情况，单机阈值可以设置为 200。

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-13.png)
## 抛出异常
如果资源违反规则会抛出异常
* Web接口
```java
@Component
public class MyBlockExceptionHandler implements BlockExceptionHandler {

    private ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void handle(HttpServletRequest httpServletRequest, HttpServletResponse httpServletResponse, String s, BlockException e) throws Exception {

        httpServletResponse.setStatus(429);
        httpServletResponse.setContentType("application/json;charset=utf-8");
        PrintWriter writer = httpServletResponse.getWriter();
        R error = R.error(500, s + "被Sentinel限制了，原因：" + e.getClass());
        String json = objectMapper.writeValueAsString(error);
        writer.write(json);
        writer.flush();
        writer.close();
    }
}
```
* @SentinelResource
```java
    @SentinelResource(value = "createOrder", blockHandler = "createOrderFallback") //定义资源
    @Override
    public Order createOrder(Long productId, Long userId) {
        Order order = new Order();
        //Product product = getProductFromRemoteWithLoadBalanceAnnotation(productId);
        Product product = productFeignClient.getProductById(productId);
        order.setUserId(userId);
        // 总金额
        order.setTotalAmount(product.getPrice().multiply(new BigDecimal(product.getNum())));
        order.setId(1L);
        order.setAddress("127.0.0.1");

        // 远程查询商品列表
        order.setProductList(Arrays.asList(product));
        return order;
    }

    //若"createOrder"违反规则，则调用createOrderFallback
    public Order createOrderFallback(Long productId, Long userId, BlockException e) {
        Order order = new Order();
        order.setId(0L);
        order.setUserId(userId);
        order.setTotalAmount(BigDecimal.ZERO);
        order.setNickName("未知用户");
        order.setAddress("异常信息:" + e.getClass());
        return order;
    }
```

# Gateway
所有业务集群请求的入口，前端不需要记住每一个微服务的地址

* 统一入口
* 请求路由   
* 负载均衡
* 流量控制
* 身份认证
* 协议转换
* 系统监控
* 安全防护

![功能](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-14.png)
**application.yml**
```yaml
spring:
    application:
        name: gateway
    cloud:
        nacos:
            server-addr: 127.0.0.1:8848
    profiles:
        include: route
server:
    port: 80
```
**application-route.yml**
```yaml
spring:
    cloud:
        gateway:
            globalcors:
                cors-configurations:
                  '[/**]':
                      allowed-origin-patterns: '*'
                      allowed-headers: '*'
                      allowed-methods: '*'
            routes:
                - id: order-service
                  uri: lb://service-order
                  predicates: #断言
                    - name: Path
                      args:
                          patterns: /api/order/**
                  filters:
                    - RewritePath=/api/order/?(?<segment>.*), /$\{segment}
                    - OnceToken=X-Response-Token, uuid
                   
                - id: product-route
                  uri: lb://service-product
                  predicates:
                    - Path=/api/product/**
                  filters:
                    - RewritePath=/api/product/?(?<segment>.*), /$\{segment}
                    
                - id: bing-route
                  uri: https://cn.bing.com/
                  predicates:
                      - name: Path
                        args:
                          patterns: /search
                          
                      - name: Vip #自定义断言
                        args:
                          param: user
                          value: lei
```
## 自定义断言
```java
@Component //自定义断言
public class VipRoutePredicateFactory extends AbstractRoutePredicateFactory<VipRoutePredicateFactory.Config> {

    public VipRoutePredicateFactory() {
        super(Config.class);
    }

    @Override
    public List<String> shortcutFieldOrder() {
        return Arrays.asList("param", "value");
    }

    @Override
    public Predicate<ServerWebExchange> apply(Config config) {
        return new GatewayPredicate() {
            @Override
            public boolean test(ServerWebExchange serverWebExchange) {
                ServerHttpRequest request = serverWebExchange.getRequest();
                HttpCookie first = request.getCookies().getFirst(config.param);
                if (first != null && first.equals(config.value)) {
                    return true;
                }
                return false;
            }
        };
    }

    @Validated
    public static class Config {

        @NotEmpty
        private String param;
        @NotEmpty
        private String value;

        public String getParam() {
            return param;
        }

        public void setParam(String param) {
            this.param = param;
        }

        public String getValue() {
            return value;
        }

        public void setValue(String value) {
            this.value = value;
        }
    }
}
```
```yaml
                - id: bing-route
                  uri: https://cn.bing.com/
                  predicates:
                      - name: Vip #自定义断言
                        args:
                          param: user
                          value: lei
```
此断言判断https://cn.bing.com/user=lei，如果user不等于lei则拒绝访问

## 过滤器的基本使用
```yaml
                  filters:
                    - RewritePath=/api/order/?(?<segment>.*), /$\{segment} # 路径重写
                    - AddResponseHeader=X-Response-Abc, 123 # 添加响应头
```
```yaml
            default-filters:
                - AddResponseHeader=X-Response-Abc, 123 # 默认过滤器
```

## GlobalFilter
```java
@Slf4j
@Component
public class RtGlobalFilter implements GlobalFilter, Ordered {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        String uri = request.getURI().toString();
        long start = System.currentTimeMillis();
        log.info("请求{}开始，时间：{}", uri, start);
        //=========================以上为前置逻辑=========================
        Mono<Void> filter = chain.filter(exchange) //异步编程
                .doFinally(signal -> {
                    //=========================以下为后置逻辑=========================
                    long end = System.currentTimeMillis();
                    log.info("请求{}结束，时间：{}，总耗时：{}", uri, end, end - start);
                });

        return filter;
    }

    //优先级
    @Override
    public int getOrder() {
        return -1;
    }
}
```
## 自定义过滤器工厂
```java
@Component
public class OnceTokenGatewayFilterFactory extends AbstractNameValueGatewayFilterFactory {


    @Override
    public GatewayFilter apply(NameValueConfig config) {

        return new GatewayFilter() {
            @Override
            public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {

                return chain.filter(exchange).then(Mono.fromRunnable(() -> {
                    ServerHttpResponse response = exchange.getResponse();
                    HttpHeaders headers = response.getHeaders();
                    String name = config.getName();
                    String value = config.getValue();
                    if ("uuid".equalsIgnoreCase(value)) {
                        value = UUID.randomUUID().toString();
                    }

                    if ("jwt".equalsIgnoreCase(value)) {
                        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoiZ3Vlc3QiLCJyb2xlIjoidmlzaXRvciJ9.AwQV8c2xJw2V1f7l8p7x9v9m6n7k5y7u7i7w6f7a7d7e7s7t7";
                    }
                    headers.add(name, value);
                }));
            }
        };
    }
}
```
```yaml
                  filters:
                    - OnceToken=X-Response-Token, uuid
```

# Seata
* TC：事务协调者
* TM：事务管理器
* RM：资源管理器


在每个微服务中，添加配置信息
```conf
service {
  #transaction service group mapping
  vgroupMapping.default_tx_group = "default"
  #only support when registry.type=file, please don't set multiple addresses
  default.grouplist = "127.0.0.1:8091"
  #degrade, current not support
  enableDegrade = false
  #disable seata
  disableGlobalTransaction = false
}
```
在主事务中添加 ==@GlobalTransactional== 注解，在各个分事务添加 ==@Transactional== 注解
```java
@Service
public class BusinessServiceImpl implements BusinessService {


    @Autowired
    StorageFeignClient storageFeignClient;
    @Autowired
    OrderFeignClient orderFeignClient;

    @GlobalTransactional
    @Override
    public void purchase(String userId, String commodityCode, int orderCount) {
        //1. 扣减库存
        storageFeignClient.deduct(commodityCode, orderCount);
        //2. 创建订单
        orderFeignClient.create(userId, commodityCode, orderCount);
    }
}

```
```java
@Service
public class OrderServiceImpl implements OrderService {

    @Autowired
    OrderTblMapper orderTblMapper;
    @Autowired
    AccountFeignClient accountFeignClient;

    @Transactional
    @Override
    public OrderTbl create(String userId, String commodityCode, int orderCount) {
        //1、计算订单价格
        int orderMoney = calculate(commodityCode, orderCount);

        // 2、扣减账户余额
        accountFeignClient.debit(userId, orderMoney);
        //3、保存订单
        OrderTbl orderTbl = new OrderTbl();
        orderTbl.setUserId(userId);
        orderTbl.setCommodityCode(commodityCode);
        orderTbl.setCount(orderCount);
        orderTbl.setMoney(orderMoney);

        orderTblMapper.insert(orderTbl);

        return orderTbl;
    }

    // 计算价格
    private int calculate(String commodityCode, int orderCount) {
        return 9*orderCount;
    }
}
```
```java
@Service
public class StorageServiceImpl implements StorageService {

    @Autowired
    StorageTblMapper storageTblMapper;

    @Transactional
    @Override
    public void deduct(String commodityCode, int count) {
        storageTblMapper.deduct(commodityCode, count);
        if (count == 5) {
            throw new RuntimeException("库存不足");
        }
    }
}
```
```java
    @Transactional //本地事务
    @Override
    public void debit(String userId, int money) {
        // 扣减账户余额
        accountTblMapper.debit(userId,money);
    }
```
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-15.png)


## 二阶提交协议流程
![二阶提交协议](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgSpringCloud%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-16.png)

