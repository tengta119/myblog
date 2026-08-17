---
title: SpringBoot3+Vue3 前后端分离项目基于Jwt的校验方案
categories: [项目开发, SpringBoot]
tags: [Java, SpringBoot, Vue3, JWT]
date: 2024-11-27 09:46:41
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost05-01.png
---
>[视频地址](https://www.bilibili.com/video/BV1Pz4y1W7TN?spm_id_from=333.788.videopod.episodes&vd_source=c6c715691c8953e0f936a6f48d833ad9)
# 配置SpringSecurity基本内容

## SecurityConfiguration

```java
@Configuration
public class SecurityConfiguration {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                .authorizeHttpRequests(conf -> conf
                        .requestMatchers("/api/auth/**").permitAll()
                        .anyRequest().authenticated()
                )
                .formLogin(conf -> conf
                        .loginProcessingUrl("/api/auth/login")
                        .successHandler(this::onAuthenticationSuccess)
                        .failureHandler(this::onAuthenticationFailure)
                )
                .logout(conf -> conf
                        .logoutUrl("/api/auth/logout")
                        .logoutSuccessHandler(this::onLogoutSuccess)
                )
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(conf -> conf
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )
                .build();
    }

    public void onAuthenticationSuccess(HttpServletRequest request,
                                        HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(RestBean.success().asJSONString());
    }

    public void onAuthenticationFailure(HttpServletRequest request,
                                        HttpServletResponse response,
                                        AuthenticationException exception) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(RestBean.failure(401,exception.getMessage()).asJSONString());
    }

    public void onLogoutSuccess(HttpServletRequest request,
                                HttpServletResponse response,
                                Authentication authentication) throws IOException, ServletException {

    }
}
```



## RestBean

```java
public record RestBean<T>(int code, T data, String message) {

    public static <T> RestBean<T> success(T data) {
        return new RestBean<>(200, data, "请求成功");
    }

    public static <T> RestBean<T> success() {
        return success(null);
    }

    public static <T> RestBean<T> failure(int code, String message) {
        return new RestBean<>(code, null, message);
    }

    public String asJSONString() {
        return JSONObject.toJSONString(this, JSONWriter.Feature.WriteNulls);
    }
}
```



# Jwt令牌颁发

## JwtUtils

```java
@Component
public class JwtUtils {

    @Value("${spring.security.jwt.key}")
    String key;

    @Value("${spring.security.jwt.expire}")
    int expire;

    public String createJwt(UserDetails details, int id, String username) {
        // 使用 HMAC256 算法和密钥创建算法实例
        Algorithm algorithm = Algorithm.HMAC256(key);

        // 获取 JWT 的过期时间
        Date expireTime = this.expireTime();

        // 创建 JWT 并添加声明
        return JWT.create()
                .withClaim("id", id) // 添加用户 ID 声明
                .withClaim("username", username) // 添加用户名声明
                .withClaim("authorities", details.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList()) // 添加用户权限声明
                .withExpiresAt(expireTime) // 设置过期时间
                .withIssuedAt(new Date()) // 设置签发时间
                .sign(algorithm); // 使用算法签名 JWT
    }

    public Date expireTime() {
        // 获取当前日期和时间
        Calendar calendar = Calendar.getInstance();
        // 添加过期时间（以小时为单位，expire * 24 小时）
        calendar.add(Calendar.HOUR, expire * 24);
        // 返回计算出的过期日期
        return calendar.getTime();
    }
}
```

## entity

### dto

数据库层面用dto

### vo

跟前端交互用vo

提交给前端

```java
@Data
public class AuthorizeVO {
    String username;
    String role;
    String token;
    Date expireTime;
}
```



## SecurityConfiguration

```java
    public void onAuthenticationSuccess(HttpServletRequest request,
                                        HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        User principal = (User) authentication.getPrincipal();
        String token = jwtUtils.createJwt(principal, 1, "小明");

        AuthorizeVO authorizeVO = new AuthorizeVO();
        authorizeVO.setToken(token);
        authorizeVO.setRole("");
        authorizeVO.setExpireTime(jwtUtils.expireTime());
        authorizeVO.setUsername("小明");

        response.getWriter().write(RestBean.success(authorizeVO).asJSONString());
    }
```



# Jwt请求头校验

用户每次向后端请求数据，会携带token，在SpringSecurity过滤链中进行校验

## SecurityConfiguration

```java
@Configuration
public class SecurityConfiguration {

    @Resource
    JwtUtils jwtUtils;

    @Resource
    JwtAuthorizeFilter jwtAuthorizeFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                .authorizeHttpRequests(conf -> conf
                        .requestMatchers("/api/auth/**").permitAll()
                        .anyRequest().authenticated()
                )
                .formLogin(conf -> conf
                        .loginProcessingUrl("/api/auth/login")
                        .successHandler(this::onAuthenticationSuccess)
                        .failureHandler(this::onAuthenticationFailure)
                )
                .logout(conf -> conf
                        .logoutUrl("/api/auth/logout")
                        .logoutSuccessHandler(this::onLogoutSuccess)
                )
                .exceptionHandling(conf -> conf
                        .authenticationEntryPoint(this::commence)
                        .accessDeniedHandler(this::handle)
                )
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(conf -> conf
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )
                .addFilterBefore(jwtAuthorizeFilter, UsernamePasswordAuthenticationFilter.class)

                .build();
    }

    public void onAuthenticationSuccess(HttpServletRequest request,
                                        HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        User principal = (User) authentication.getPrincipal();
        String token = jwtUtils.createJwt(principal, 1, "小明");

        AuthorizeVO authorizeVO = new AuthorizeVO();
        authorizeVO.setToken(token);
        authorizeVO.setRole("");
        authorizeVO.setExpireTime(jwtUtils.expireTime());
        authorizeVO.setUsername("小明");

        response.getWriter().write(RestBean.success(authorizeVO).asJSONString());
    }

    public void onLogoutSuccess(HttpServletRequest request,
                                HttpServletResponse response,
                                Authentication authentication) throws IOException, ServletException {

    }

    public void onAuthenticationFailure(HttpServletRequest request,
                                        HttpServletResponse response,
                                        AuthenticationException exception) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(RestBean.unauthorized(exception.getMessage()).asJSONString());
    }

    public void handle(HttpServletRequest request,
                       HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(RestBean.forbidden(accessDeniedException.getMessage()).asJSONString());
    }

    public void commence(HttpServletRequest request,
                         HttpServletResponse response,
                         AuthenticationException authException) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(RestBean.unauthorized(authException.getMessage()).asJSONString());
    }
}

```

添加过滤**addFilterBefore**

```java
addFilterBefore(jwtAuthorizeFilter, UsernamePasswordAuthenticationFilter.class)
```

## JwtAuthorizeFilter

验证jwt

```java
@Component
public class JwtAuthorizeFilter extends OncePerRequestFilter { //过滤器

    @Resource
    JwtUtils jwtUtils;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String authorization = request.getHeader("Authorization");
        DecodedJWT jwt = jwtUtils.resolveJwt(authorization);
        if (jwt != null) {
            UserDetails user = jwtUtils.toUser(jwt);
            UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities());
            authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(authentication);
            request.setAttribute("id", jwtUtils.toId(jwt));
        }
        filterChain.doFilter(request, response);
    }
}
```





# Jwt退出登录 

[redis基本部署](https://blog.csdn.net/sss1513/article/details/144004502)

使用redis实现黑名单功能，用户在退出登录时会将token的uuid存放在redis数据库上，用户在每次请求数据时，后端会校验**token是否合法**，然后校验**是否在黑名单中**，如果这两项其中有一个不符合要求则拒绝请求

```java
    @Resource
    StringRedisTemplate template;

    //判断token是否有效,如果有效则加入黑名单
    public boolean invalidToken(String headerToken) {
        String token = this.convertToken(headerToken);
        if (token == null) {
            return false;
        }
        Algorithm algorithm = Algorithm.HMAC256(key);
        JWTVerifier jwtVerifier = JWT.require(algorithm).build();
        try{
            DecodedJWT verify = jwtVerifier.verify(token);
            String id = verify.getId();
            return deleteToken(id, verify.getExpiresAt());
        } catch (JWTVerificationException e) {
            return false;
        }
    }

    //将token加入黑名单
    private boolean deleteToken(String uuid, Date time) {
        if (this.isInvalidToken(uuid)) {
            return false;
        }
        Date now = new Date();
        long expire = Math.max(time.getTime() - now.getTime(), 0);
        template.opsForValue().set(Const.JWT_BLACK_LIST + uuid, "", expire, TimeUnit.MICROSECONDS);
        return true;
    }

    //判断token是否在黑名单中
    private boolean isInvalidToken(String uuid) {
        return Boolean.TRUE.equals(template.hasKey(Const.JWT_BLACK_LIST + uuid));
    }

    public DecodedJWT resolveJwt(String headerToken) {
        // 将头部的 token 转换为实际的 JWT token
        String token = this.convertToken(headerToken);
        // 如果 token 为 null，返回 null
        if (token == null) {
            return null;
        }
        // 使用 HMAC256 算法和密钥创建算法实例
        Algorithm algorithm = Algorithm.HMAC256(key);
        // 创建 JWT 验证器
        JWTVerifier jwtVerifier = JWT.require(algorithm).build();
        try {
            // 验证 token 并获取解码后的 JWT
            DecodedJWT verify = jwtVerifier.verify(token);
            // 如果 token 在黑名单中，返回 null
            if (this.isInvalidToken(verify.getId())) {
                return null;
            }
            // 获取 token 的过期时间
            Date expiresAt = verify.getExpiresAt();
            // 如果当前时间在过期时间之后，返回 null，否则返回解码后的 JWT
            return new Date().after(expiresAt) ? null : verify;
        } catch (JWTVerificationException e) {
            // 如果验证失败，返回 null
            return null;
        }
    }
```



# 实现数据库的用户校验

需要从数据库或其他源加载用户信息时，实现 `UserDetailsService` 并配置到 Spring Security 上下文中

实现mapper，service

**AccountServiceImpl**

```java
@Service
public class AccountServiceImpl extends ServiceImpl<AccountMapper, Account> implements AccountService {
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        Account account = this.findAccountByNameOrEmail(username);
        if (account == null) {
            throw new UsernameNotFoundException("用户名或密码错误");
        }
        return User
                .withUsername(username)
                .password(account.getPassword())
                .roles(account.getRole())
                .build();
    }


    @Override
    public Account findAccountByNameOrEmail(String text) {
        return this.query()
                .eq("username", text)
                .or()
                .eq("email", text)
                .one();
    }
}

```



# 基本页面配置



# 登录界面编写



# Axios请求封装



# 跨域手动配置

```java
//解决跨域问题
@Component
@Order(Const.ORDER_CORS)
public class CorsFilter extends HttpFilter {

    @Override
    protected void doFilter(HttpServletRequest request,
                            HttpServletResponse response,
                            FilterChain chain) throws IOException, ServletException {
        this.addCorsHeader(request, response);
        chain.doFilter(request, response);
    }

    private void addCorsHeader(HttpServletRequest request, HttpServletResponse response) {
        response.setHeader("Access-Control-Allow-Origin", request.getHeader("Origin"));
        response.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS, DELETE, PUT");
        response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

    }
}
```

# 退出登录以及路由守卫实现



# 验证码发送

## registerEmailVerifyCode

用户在请求验证码时，后端会将用户的**验证码类型、邮箱、验证码和ip**包装成一个map，并转存到消息队列中，还有将验证码存入到redis中，供后续验证

```java
    @Override
    public String registerEmailVerifyCode(String type, String email, String ip) {
        synchronized (ip.intern()) {
            if (!this.verifyLimit(ip)) {
                return "请求过于频繁";
            }
            Random random = new Random();
            int code = random.nextInt(899999) + 100000;
            Map<String, Object> data = Map.of("type", type, "email", email, "code", code);
            amqpTemplate.convertAndSend("mail", data);
            stringRedisTemplate.opsForValue()
                    .set(Const.VERIFY_EMAIL_DATA + email, String.valueOf(code), 3, TimeUnit.MINUTES);
            return null;
        }
    }

    private boolean verifyLimit(String ip) {
        String key = Const.VERIFY_EMAIL_LIMIT + ip;
        return flowUtils.limitOnceCheck(key,60);
    }
```

## sendMailMessage

在队列的监听器中，监听器根据队列里的内容发送对应邮件

```java
    @RabbitHandler
    public void sendMailMessage(Map<String, Object> data) {
        String email = (String) data.get("email");
        Integer code = (Integer) data.get("code");
        String type = (String) data.get("type");
        SimpleMailMessage message = switch (type) {
            case "register" -> createMessage("注册验证码", "您的验证码是" + code, email);
            case "forget" -> createMessage("忘记密码验证码", "您的验证码是" + code, email);
            default -> null;
        };
        if (message == null) return;
        sender.send(message);
    }

    private SimpleMailMessage createMessage(String title, String content, String email) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setSubject(title);
        message.setText(content);
        message.setTo(email);
        message.setFrom(username);
        return message;
    }
```



**创建队列**

```java
@Configuration
public class RabbitConfiguration {

    @Bean("emailQueue")
    public Queue emailQueue() {
        return QueueBuilder
                .durable("mail")
                .build();
    }

    @Bean
    public Jackson2JsonMessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }

}
```



# 注册接口实现

## register

````java
    @PostMapping("/register")
    public RestBean<Void> register(@RequestBody @Validated EmailRegisterVO emailRegisterVO) {
        return this.messageHandle(() -> accountService.registerEmailAccount(emailRegisterVO));
    }
````

## registerEmailAccount

```java
    public String registerEmailAccount(EmailRegisterVO emailRegisterVO) {
        String email = emailRegisterVO.getEmail();
        String code = stringRedisTemplate.opsForValue().get(Const.VERIFY_EMAIL_DATA + email);
        if (code == null || !code.equals(emailRegisterVO.getCode())) {
            return "验证码错误";
        }
        if (this.existsAccountByEmail(email)) {
            return "邮箱已被注册";
        }
        if (this.existsAccountByUsername(emailRegisterVO.getUsername())) {
            return "用户名已被注册";
        }
        Account account = new Account(null, emailRegisterVO.getUsername(), passwordEncoder.encode(emailRegisterVO.getPassword()), email, "user", new Date());
        if (this.save(account)) {
            stringRedisTemplate.delete(Const.VERIFY_EMAIL_DATA + email);
            return null;
        } else {
            return "内部错误，请稍后再试";
        }
    }
```



# 注册界面编写



# 完善注册操作



# 密码重置页面



# 密码重置接口设计

首先用户向后端请求验证码，来验证邮箱是否正确，以此来判断用户是否可以重置密码


接口**restConfirm**

```java
    @PostMapping("/reset-confirm")
    public RestBean<Void> restConfirm(@RequestBody @Valid ConfirmResetVO vo) {
        return this.messageHandle(() -> accountService.restConfirm(vo));
    }
```

```java
    @Override
    public String restConfirm(ConfirmResetVO vo) {
        String email = vo.getEmail();
        String code = stringRedisTemplate.opsForValue().get(Const.VERIFY_EMAIL_DATA + email);
        if (code == null) {
            return "请先获取验证码";
        }
        if (!code.equals(vo.getCode())) {
            return "验证码错误";
        }
        return null;

    }
```

然后进行重置密码，此操作也需要判断验证码是否正确

接口

```java
    @PostMapping("/reset-password")
    public RestBean<Void> restConfirm(@RequestBody @Valid EmailRestVO vo) {
        return this.messageHandle(() -> accountService.restEmailAccountPassword(vo));
    }
```

```java
    @Override
    public String restEmailAccountPassword(EmailRestVO vo) {
        String email = vo.getEmail();
        String verify = this.restConfirm(new ConfirmResetVO(email, vo.getCode()));
        if (verify != null) {
            return verify;
        }
        String password = passwordEncoder.encode(vo.getPassword());
        boolean update = this.update().eq("email", email).set("password", password).update();
        if(update){
            stringRedisTemplate.delete(Const.VERIFY_EMAIL_DATA + email);
        }
        return null;
    }
```



# 实现限流操作

```java
@Component
@Order(Const.ORDER_LIMIT)
public class FlowLimitFilter extends HttpFilter {

    @Resource
    StringRedisTemplate template;

    @Override
    protected void doFilter(HttpServletRequest request, HttpServletResponse response, FilterChain chain) throws IOException, ServletException {
        String address = request.getRemoteAddr();
        if (this.tryCount(address)) {
            chain.doFilter(request, response);
        } else {
            this.writeBlockMessage(response);
        }

    }

    private void writeBlockMessage(HttpServletResponse response) throws IOException {
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(RestBean.forbidden("操作频繁，请稍后重试").asJSONString());
    }


    private boolean tryCount(String ip) {
        synchronized (ip.intern()) {
            if(Boolean.TRUE.equals(template.hasKey(Const.FLOW_LIMIT_BLOCK + ip))) {
                return false;
            }
            return this.limitPeriodCheck(ip);
        }
    }

    private boolean limitPeriodCheck(String ip) {
        if (Boolean.TRUE.equals(template.hasKey(Const.FLOW_LIMIT_COUNTER + ip))) {
            Long increment = Optional.ofNullable(template.opsForValue().increment(Const.FLOW_LIMIT_COUNTER + ip)).orElse(0L);
            if (increment > 0) {
                template.opsForValue().set(Const.FLOW_LIMIT_BLOCK + ip, "", 30, TimeUnit.SECONDS);
            }
        } else {
            template.opsForValue().set(Const.FLOW_LIMIT_COUNTER + ip, "1", 3, TimeUnit.SECONDS);
        }
        return true;
    }
}

```



# 适配深色模式

# 补充1：JWT
* 用户在登录时**UserDetailsService类**中的**loadUserByUsername方法**会根据用户发来的信息（例如账户名）来查询账户信息，与用户发来的账户信息比较，若验证通过，则会调用**onAuthenticationSuccess方法**生成token并返回前端
 * 用户在登录成功，在发起其他请求时会携带该token，先通过**JwtAuthorizeFilter过滤器**根据token生成user，并设置到上下文，供后续过滤器验证
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost05-01.png)










