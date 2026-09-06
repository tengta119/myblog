---
title: 小型支付系统（MVC、DDD）
categories:
  - 后端开发
  - 架构设计
tags:
  - Java
  - MVC
  - DDD
  - 支付宝
  - 微信公众号
date: 2025-05-23 11:30:00
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-01.png
---
# 开发运维

## natapp - 内网穿透

[NATAPP](https://natapp.cn/tunnel/lists)
```ini
# https://natapp.cn/ - 支持免费使用，但付费会更稳定一些  
# 将本文件放置于natapp同级目录 程序将读取 [default] 段  
# 在命令行参数模式如 natapp -authtoken=xxx 等相同参数将会覆盖掉此配置  
# 命令行参数 -config= 可以指定任意config.ini文件  
[default]  
authtoken=79f9d0d50e929248      #对应一条隧道的authtoken，你需要更换为你的。否则不能正常启动。  
clienttoken=                    #对应客户端的clienttoken,将会忽略authtoken,若无请留空,  
log=none                        #log 日志文件,可指定本地文件, none=不做记录,stdout=直接屏幕输出 ,默认为none  
loglevel=ERROR                  #日志等级 DEBUG, INFO, WARNING, ERROR 默认为 DEBUGhttp_proxy=                     #代理设置 如 http://10.123.10.10:3128 非代理上网用户请务必留空
```
配置完环境后直接打开 exe 程序，启动内网穿透
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-01.png)
之后 `http://lbwxxc.natapp1.cc` 就可以替代 `http://localhost:8080` 了

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-02.png)
```java
@SpringBootApplication  
@RestController()  
@RequestMapping("/api/")  
public class Application {  
  
    public static void main(String[] args) {  
        SpringApplication.run(Application.class);  
    }  
  
    /**  
     * http://localhost:8080/api/test     
     * http://lbwxxc.natapp1.cc/api/test    
     */    
    @RequestMapping(value = "/test", method = RequestMethod.GET)  
    public ResponseBodyEmitter test(HttpServletResponse response) {  
        response.setContentType("text/event-stream");  
        response.setCharacterEncoding("UTF-8");  
        response.setHeader("Cache-Control", "no-cache");  
  
        ResponseBodyEmitter emitter = new ResponseBodyEmitter();  
  
        String[] words = new String[]{"恭喜💐 ", "你的", " NatApp 内网穿透 ", "部", "署", "测", "试", "成", "功", "了啦🌶！"};  
        new Thread(() -> {  
            for (String word : words) {  
                try {  
                    emitter.send(word);  
                    Thread.sleep(250);  
                } catch (IOException | InterruptedException e) {  
                    throw new RuntimeException(e);  
                }  
            }  
        }).start();  
  
        return emitter;  
    }  
  
}
```
## 微信公众号
### 接口配置信息


* 平台地址：[微信公众平台](https://mp.weixin.qq.com/debug/cgi-bin/sandbox?t=sandbox/login) - 每个人都可以申请。进入后会看到官网文档。

* 接入文档：[开始开发 / 接入指南](https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Access_Overview.html)

* 错误码说明：[开发前必读 / 全局返回码说明](https://developers.weixin.qq.com/doc/offiaccount/Getting_Started/Global_Return_Code.html)

* 微信公众号开发文档： [开发前必读 / 入门指引](https://developers.weixin.qq.com/doc/offiaccount/Getting_Started/Getting_Started_Guide.html)

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-03.png)
* **URL** ：当微信平台验证 **接口配置信息** 时，会向这个 URL 发送 GET 请求，包含 Token

| 参数        | 描述                                                        |
| --------- | --------------------------------------------------------- |
| signature | 微信加密签名，signature结合了开发者填写的token参数和请求中的timestamp参数、nonce参数。 |
| timestamp | 时间戳                                                       |
| nonce     | 随机数                                                       |
| echostr   | 随机字符串                                                     |

```java
@Slf4j  
@RestController()  
@CrossOrigin("*")  
@RequestMapping("/api/v1/weixin/portal/")  
public class WeixinPortalController {  
  
    @Value("${weixin.config.originalid}")  
    private String originalid;  
    @Value("${weixin.config.token}")  
    private String token;  
  
    @GetMapping(value = "receive", produces = "text/plain;charset=utf-8")  
    public String validate(@RequestParam(value = "signature", required = false) String signature,  
                           @RequestParam(value = "timestamp", required = false) String timestamp,  
                           @RequestParam(value = "nonce", required = false) String nonce,  
                           @RequestParam(value = "echostr", required = false) String echostr) {  
        try {  
            log.info("微信公众号验签信息开始 [{}, {}, {}, {}]", signature, timestamp, nonce, echostr);  
            if (StringUtils.isAnyBlank(signature, timestamp, nonce, echostr)) {  
                throw new IllegalArgumentException("请求参数非法，请核实!");  
            }  
            boolean check = SignatureUtil.check(token, signature, timestamp, nonce);  
            log.info("微信公众号验签信息完成 check：{}", check);  
            if (!check) {  
                return null;  
            }  
            return echostr;  
        } catch (Exception e) {  
            log.error("微信公众号验签信息失败 [{}, {}, {}, {}]", signature, timestamp, nonce, echostr, e);  
            return null;  
        }  
    }  
  
}
```

当微信平台进行验证时，就会请求这个方法，当返回 echostr 时，微信平台就会认为此端口配置正确

### 发送文本消息

```java
    @PostMapping(value = "receive", produces = "application/xml; charset=UTF-8")
    public String post(@RequestBody String requestBody,
                       @RequestParam("signature") String signature,
                       @RequestParam("timestamp") String timestamp,
                       @RequestParam("nonce") String nonce,
                       @RequestParam("openid") String openid,
                       @RequestParam(name = "encrypt_type", required = false) String encType,
                       @RequestParam(name = "msg_signature", required = false) String msgSignature) {
        try {
            log.info("接收微信公众号信息请求{}开始\n{}", openid, requestBody);
            // 消息转换
            MessageTextEntity message = XmlUtil.xmlToBean(requestBody, MessageTextEntity.class);
            return buildMessageTextEntity(openid, "你好，" + message.getContent());
        } catch (Exception e) {
            log.error("接收微信公众号信息请求{}失败 {}", openid, requestBody, e);
            return "";
        }
    }
```

当有用户向公众号发送文本消息时，微信平台会将信息转发到这个方法，该方法处理完请求后，会把信息返回给微信平台，再有微信平台把处理后的消息发送给用户

```xml
<xml>
  <ToUserName><![CDATA[toUser]]></ToUserName>
  <FromUserName><![CDATA[fromUser]]></FromUserName>
  <CreateTime>1348831860</CreateTime>
  <MsgType><![CDATA[text]]></MsgType>
  <Content><![CDATA[this is a test]]></Content>
  <MsgId>1234567890123456</MsgId>
  <MsgDataId>xxxx</MsgDataId>
  <Idx>xxxx</Idx>
</xml>
```
| 参数           | 描述                          |
| :----------- | :-------------------------- |
| ToUserName   | 开发者微信号                      |
| FromUserName | 发送方账号（一个OpenID）             |
| CreateTime   | 消息创建时间 （整型）                 |
| MsgType      | 消息类型，文本为text                |
| Content      | 文本消息内容                      |
| MsgId        | 消息id，64位整型                  |
| MsgDataId    | 消息的数据ID（消息如果来自文章时才有）        |
| Idx          | 多图文时第几篇文章，从1开始（消息如果来自文章时才有） |

## Alipay  沙箱支付

**支付宝|开放平台** 地址： [沙箱应用 - 开放平台](https://open.alipay.com/develop/sandbox/app) 

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-04.png)
### 配置信息

```java
    // 「沙箱环境」应用ID - 您的APPID，收款账号既是你的APPID对应支付宝账号。获取地址；https://open.alipay.com/develop/sandbox/app
    public static String app_id = "";
    // 「沙箱环境」商户私钥，你的PKCS8格式RSA2私钥 -【秘钥工具】所创建的公户私钥
    public static String merchant_private_key = "";
    // 「沙箱环境」支付宝公钥 -【秘钥填写】后提供给你的支付宝公钥
    public static String alipay_public_key = "";
    // 「沙箱环境」服务器异步通知回调地址
    public static String notify_url = "http://lbwxxc.natapp1.cc/api/v1/alipay/alipay_notify_url";
    // 「沙箱环境」页面跳转同步通知页面路径 需http://格式的完整路径，不能加?id=123这类自定义参数，必须外网可以正常访问
    public static String return_url = "https://gaga.plus";
    // 「沙箱环境」
    public static String gatewayUrl = "https://openapi-sandbox.dl.alipaydev.com/gateway.do";
    // 签名方式
    public static String sign_type = "RSA2";
    // 字符编码格式
    public static String charset = "utf-8";
```

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-05.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-06.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-07.png)

### 发送订单
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-08.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-09.png)
```java
    /**
     * 	http://lbwxxc.natapp1.cc/api/v1/alipay/alipay_notify_url
     */
    @RequestMapping(value = "alipay_notify_url", method = RequestMethod.POST)
    public String payNotify(HttpServletRequest request) throws AlipayApiException {
        log.info("支付回调，消息接收 {}", request.getParameter("trade_status"));

        if (!request.getParameter("trade_status").equals("TRADE_SUCCESS")) {
            return "false";
        }

        Map<String, String> params = new HashMap<>();
        Map<String, String[]> requestParams = request.getParameterMap();
        for (String name : requestParams.keySet()) {
            params.put(name, request.getParameter(name));
        }

        String tradeNo = params.get("out_trade_no");
        String gmtPayment = params.get("gmt_payment");
        String alipayTradeNo = params.get("trade_no");

        String sign = params.get("sign");
        String content = AlipaySignature.getSignCheckContentV1(params);
        boolean checkSignature = AlipaySignature.rsa256CheckContent(content, sign, alipayPublicKey, "UTF-8"); // 验证签名
        // 支付宝验签
        if (!checkSignature) {
            return "false";
        }

        // 验签通过
        log.info("支付回调，交易名称: {}", params.get("subject"));

        return "success";
    }
```

当用户付款后，就会触发这个回调方法

```xml
25-05-16.16:39:01.052 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，消息接收 TRADE_SUCCESS
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，交易名称: 测试商品
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，交易状态: TRADE_SUCCESS
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，支付宝交易凭证号: 2025051622001489770505612628
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，商户订单号: xfg2024092711320005
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，交易金额: 113.00
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，买家在支付宝唯一id: 2088722067789772
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，买家付款时间: 2025-05-16 16:39:52
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，买家付款金额: 113.00
25-05-16.16:39:01.067 [http-nio-8080-exec-1] INFO  AliPayController       - 支付回调，支付回调，更新订单 xfg2024092711320005
```

# 功能实现 - MVC

## MVC 工程框架搭建、基础配置  

在父工程的 pom 文件里

```xml
<!--    定义信息，规范版本，根据模块自身需要单独引入-->
    <dependencyManagement>
		...
    </dependencyManagement>
```

在 Application 中

```java
/**
 * @description 启动入口，会扫 Application 所在目录及子目录的 Bean，所以 Application 要在根目录
 * @create 2024-09-27 16:56
 */
@SpringBootApplication
@Configurable
@EnableScheduling
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class);
    }

}
```
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-10.png)
	1、用户点击登录需要二维码，而二维码生成是「不需要走服务端」，直接调用微信的接口「https://mp.weixin.qq.com/cgi-bin/showqrcode?ticket...」，可是这个接口需要一个 ticket，这个ticket就需要服务端提供了，因此才会去请求「/api/v1/login/weixin_qrcode_ticket」接口，如果浏览器本身就缓存了一个可用的ticket，是可以不需要请求服务端的。

​	2、因此，在步骤1的情况下，关键就是拿到ticket !!! 而 ticket 怎么拿？就是请求服务端接口「/api/v1/login/weixin_qrcode_ticket」。服务端怎么拿ticket？请求微信接口「https://api.weixin.qq.com/cgi-bin/qrcode/create?ac...」，这时会发现，又需要一个参数 access_token。同样的，如果服务端已经缓存了access_token，就不需要请求微信接口来拿 access_token 了。

​	3、继续，那如果请求微信接口，这个access_toke怎么拿？「https://api.weixin.qq.com/cgi-bin/token?grant_type...」，这个接口需要的参数appid、secret就是配置里面的了，填充就行～

​	【重点】4、最后，就是从结果反向推导各个流程：请求二维码需要ticket ---没有ticket---> 请求服务端拿ticket ---没有ticket---> 请求ticket需要access_token --- 没有access_toke---> 请求access_toke需要appid&secret「这两个参数现成的，填充上去即可」

### 代码细节

```java
@Slf4j
@Configuration
public class Retrofit2Config {

    // 请求的根地址
    private static final String BASE_URL = "https://api.weixin.qq.com/";

    @Bean
    public Retrofit retrofit() {
        return new Retrofit.Builder()
                .baseUrl(BASE_URL)
                .addConverterFactory(JacksonConverterFactory.create()).build();
    }

    // IWeixinApiService 实例化
    @Bean
    public IWeixinApiService weixinApiService(Retrofit retrofit) {
        return retrofit.create(IWeixinApiService.class);
    }

}
```

retrofit 实例化 IWeixinApiService

```java
/**
 * @description 微信API服务 retrofit2、获取 Access token、获取凭据 ticket、发送微信公众号模板消息
 * @create 2024-09-28 13:30
 */
public interface IWeixinApiService {

    /**
     * 获取 Access token
     * 文档：https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Get_access_token.html Get_access_token
     * 参数	        是否必须	        说明
     * grant_type	是	            获取 access_token 填写 client_credential
     * appid	    是	            第三方用户唯一凭证
     * secret	    是	            第三方用户唯一凭证密钥，即appsecret
     */
    @GET("cgi-bin/token")
    Call<WeixinTokenRes> getToken(@Query("grant_type") String grantType,
                                  @Query("appid") String appId,
                                  @Query("secret") String appSecret);

    /**
     * 凭借此ticket可以在有效时间内换取二维码
     * 文档：https://developers.weixin.qq.com/doc/offiaccount/Account_Management/Generating_a_Parametric_QR_Code.html
     *      https://mp.weixin.qq.com/cgi-bin/showqrcode?ticket=TICKET 前端根据凭证展示二维码
     *
     * @param accessToken            getToken 获取的 token 信息
     * @param weixinQrCodeReq        入参对象
     * @return                       应答结果
     *
     * 参数	               说明
     * expire_seconds	   该二维码有效时间，以秒为单位。 最大不超过2592000（即30天），此字段如果不填，则默认有效期为60秒。
     * action_name	       二维码类型，QR_SCENE为临时的整型参数值，QR_STR_SCENE为临时的字符串参数值，QR_LIMIT_SCENE为永久的整型参数值，QR_LIMIT_STR_SCENE为永久的字符串参数值
     * action_info	       二维码详细信息
     * scene_id	           场景值ID，临时二维码时为32位非0整型，永久二维码时最大值为100000（目前参数只支持1--100000）
     * scene_str	       场景值ID（字符串形式的ID），字符串类型，长度限制为1到64
     *
     */
    @POST("cgi-bin/qrcode/create")
    Call<WeixinQrCodeRes> createQrCode(@Query("access_token") String accessToken, @Body WeixinQrCodeReq weixinQrCodeReq);


    /**
     * 发送微信公众号模板消息
     * 文档：https://mp.weixin.qq.com/debug/cgi-bin/readtmpl?t=tmplmsg/faq_tmpl
     *
     * @param accessToken              getToken 获取的 token 信息
     * @param weixinTemplateMessageVO  入参对象
     * @return 应答结果
     */
    @POST("cgi-bin/message/template/send")
    Call<Void> sendMessage(@Query("access_token") String accessToken, @Body WeixinTemplateMessageVO weixinTemplateMessageVO);

}
```

获取 Access token、获取凭据 ticket、发送微信公众号模板消息


```java
/**  
 * http://lbwxxc.natapp1.cc/api/v1/login/weixin_qrcode_ticket * @return  
 */  
@RequestMapping(value = "weixin_qrcode_ticket", method = RequestMethod.GET)  
public Response<String> weixinQrCodeTicket() {  
    try {  
        String qrCodeTicket = loginService.createQrCodeTicket();  
        log.info("生成微信扫码登录 ticket:{}", qrCodeTicket);  
        return Response.<String>builder()  
                .code(Constants.ResponseCode.SUCCESS.getCode())  
                .info(Constants.ResponseCode.SUCCESS.getInfo())  
                .data(qrCodeTicket)  
                .build();  
  
    } catch (Exception e) {  
        log.error("生成微信扫码登录 ticket 失败", e);  
        return Response.<String>builder()  
                .code(Constants.ResponseCode.UN_ERROR.getCode())  
                .info(Constants.ResponseCode.UN_ERROR.getInfo())  
                .build();  
    }  
}
```

用户向服务端请求 ticket，用户可以凭借此 ticket 获取二维码

```java
@PostMapping(value = "receive", produces = "application/xml; charset=UTF-8")  
public String post(@RequestBody String requestBody,  
                   @RequestParam("signature") String signature,  
                   @RequestParam("timestamp") String timestamp,  
                   @RequestParam("nonce") String nonce,  
                   @RequestParam("openid") String openid,  
                   @RequestParam(name = "encrypt_type", required = false) String encType,  
                   @RequestParam(name = "msg_signature", required = false) String msgSignature) {  
    try {  
        log.info("接收微信公众号信息请求 {} 开始\n{}", openid, requestBody);  
        // 消息转换  
        MessageTextEntity message = XmlUtil.xmlToBean(requestBody, MessageTextEntity.class);  
  
        // 事件类型  
        if ("event".equals(message.getMsgType()) && "SCAN".equals(message.getEvent())) {  
            loginService.saveLoginState(message.getTicket(), openid);  
            return buildMessageTextEntity(openid, "登录成功");  
        }  
  
        return buildMessageTextEntity(openid, "你好，" + message.getContent());  
    } catch (Exception e) {  
        log.error("接收微信公众号信息请求{}失败 {}", openid, requestBody, e);  
        return "";  
    }  
}
```

当用户扫码成功后，微信会请求这个接口，服务端可以保存用户的登录状态

```java
/**  
 * http://lbwxxc.natapp1.cc/api/v1/login/check_login 
 */
@RequestMapping(value = "check_login", method = RequestMethod.GET)  
public Response<String> checkLogin(@RequestParam String ticket) {  
    try {  
        String openidToken = loginService.checkLogin(ticket);  
        log.info("扫码检测登录结果 ticket:{} openidToken:{}", ticket, openidToken);  
        if (StringUtils.isNotBlank(openidToken)) {  
            return Response.<String>builder()  
                    .code(Constants.ResponseCode.SUCCESS.getCode())  
                    .info(Constants.ResponseCode.SUCCESS.getInfo())  
                    .data(openidToken)  
                    .build();  
        } else {  
            return Response.<String>builder()  
                    .code(Constants.ResponseCode.NO_LOGIN.getCode())  
                    .info(Constants.ResponseCode.NO_LOGIN.getInfo())  
                    .build();  
        }  
  
    } catch (Exception e) {  
        log.error("扫码检测登录结果失败 ticket:{}", ticket, e);  
        return Response.<String>builder()  
                .code(Constants.ResponseCode.UN_ERROR.getCode())  
                .info(Constants.ResponseCode.UN_ERROR.getInfo())  
                .build();  
    }  
}
```

用户会轮询检测自己是否登录成功，如果成功会获取 token并跳转页面

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-11.png)
### 代码细节

```java
@Bean("alipayClient")  
public AlipayClient alipayClient(AliPayConfigProperties properties) {  
    return new DefaultAlipayClient(properties.getGatewayUrl(),  
            properties.getApp_id(),  
            properties.getMerchant_private_key(),  
            properties.getFormat(),  
            properties.getCharset(),  
            properties.getAlipay_public_key(),  
            properties.getSign_type());  
}
```


创建支付宝客户端 (AlipayClient) 的 Bean，并将其注册到 Spring 容器中。这个客户端实例可以用于后续与支付宝支付系统的交互，如创建订单、查询交易状态


```java
private PayOrder doPrepayOrder(String productId, String productName, String orderId, BigDecimal totalAmount) throws AlipayApiException {  
    AlipayTradePagePayRequest request = new AlipayTradePagePayRequest();  
    request.setNotifyUrl(notifyUrl);  
    request.setReturnUrl(returnUrl);  
  
    JSONObject bizContent = new JSONObject();  
    bizContent.put("out_trade_no", orderId);  
    bizContent.put("total_amount", totalAmount.toString());  
    bizContent.put("subject", productName);  
    bizContent.put("product_code", "FAST_INSTANT_TRADE_PAY");  
    request.setBizContent(bizContent.toString());  
  
    String form = alipayClient.pageExecute(request).getBody();  
  
    PayOrder payOrder = new PayOrder();  
    payOrder.setOrderId(orderId);  
    payOrder.setPayUrl(form);  
    payOrder.setStatus(Constants.OrderStatusEnum.PAY_WAIT.getCode());  
  
    orderDao.updateOrderPayInfo(payOrder);  
  
    return payOrder;  
}
```

成功创建的订单会返回一个 form 表单，用户可以访问这个表单进行支付

```java
/**  
 * http://xfg-studio.natapp1.cc/api/v1/alipay/alipay_notify_url */@RequestMapping(value = "alipay_notify_url", method = RequestMethod.POST)  
public String payNotify(HttpServletRequest request) throws AlipayApiException {  
    log.info("支付回调，消息接收 {}", request.getParameter("trade_status"));  
  
    if (!request.getParameter("trade_status").equals("TRADE_SUCCESS")) {  
        return "false";  
    }  
  
    Map<String, String> params = new HashMap<>();  
    Map<String, String[]> requestParams = request.getParameterMap();  
    for (String name : requestParams.keySet()) {  
        params.put(name, request.getParameter(name));  
    }  
  
    String tradeNo = params.get("out_trade_no");  
    String gmtPayment = params.get("gmt_payment");  
    String alipayTradeNo = params.get("trade_no");  
  
    String sign = params.get("sign");  
    String content = AlipaySignature.getSignCheckContentV1(params);  
    boolean checkSignature = AlipaySignature.rsa256CheckContent(content, sign, alipayPublicKey, "UTF-8"); // 验证签名  
    // 支付宝验签  
    if (!checkSignature) {  
        return "false";  
    }  
  
    // 验签通过  
    log.info("支付回调，交易状态: {}", params.get("trade_status"));  

  
    // 可以增加 code 10000 与 tradeStatus TRADE_SUCCESS 判断，写入数据库，订单完成  
    orderService.changeOrderPaySuccess(tradeNo);  
  
    return "success";  
}
```

用户支付完成后，支付宝会进行异步回调访问这个这个接口，服务端可以进行相应的处理

# 改造为 DDD

* s-pay-mall-app ： 启动、配置项
* s-pay-mall-api ： 接口，方便其他模块调用
* s-pay-mall-trigger : 引用 api 包， 一个平台，接收什么请求，实现请求
* s-pay-mall-domain ：分领域，比如说一个登录领域，建立一个登录包，专门放有关登录的对象，充血对象和充血包，存放原 service 的实现
* s-pay-mall-infrastructure ：基础设施层，依赖倒置，会实现 domain 层的接口
* s-pay-mall-types : 一般类

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-12.png)
在 domain 一个领域中，分为：

* adapter：外部接口适配器层，当需要调用外部接口时，则创建出这一层，并定义接口，之后由基础设施层的 adapter 层具体实现
	* port ： 当需要调用外部接口时，则创建出这一层，并定义接口，之后由基础设施层的 adapter 层具体实现
	* repository ： 定义仓储接口，之后由基础设施层做具体实现
* model ：对象
	* aggregate ： 聚合对象，聚合实体和值对象
	* entity ： 实体对象，一般和数据库持久化对象1v1的关系
	* valobj ： 值对象，用于描述对象属性的值
* service ：具体业务逻辑的实现

在 infrastructure 基础设施层，分为：

* adapter ： 适配器，实现 domain 接口
* dao ：操作数据库
* gateway ：定义http、rpc接口，调用外部。在 adapter 中调用这部分内容。

在 trigger 中 ：

* http ：实现 http 接口
* job ：
* listener ：

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-13.png)
如图所示将 mvc 中的 web 模块中的配置项拆分到 ddd 中的 app 模块

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-14.png)
先将 mvc 中的 web 模块中的可以对外提供接口的 `controller` 抽象为接口放入到 ddd 中的 api 模块，如果 web 模块中有些 `controller` 不需要对外提供接口，则可以不需要抽象

在 ddd 的 trigger 模块中，实现 api 的两个接口

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-15.png)
将 mvc 的 service 模块按领域拆分到 ddd 中的 domain 中，变为充血模型，domain 中各个领域中的 port 和 repository 通过依赖倒置的方式交由 infrastructure 实现

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%B0%8F%E5%9E%8B%E6%94%AF%E4%BB%98%E7%B3%BB%E7%BB%9F%EF%BC%88MVC%E3%80%81DDD%EF%BC%89-16.png)
infrastructure 实现数据库操作，实现 port 和 repository，以及调用外部接口





