---
title: AI 应用开发
categories:
  - AI
tags:
  - AI
  - SpringAI
  - MCP
  - RAG
  - Agent
date: 2025-10-27 11:45:14
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgAI%20%E5%BA%94%E7%94%A8%E5%BC%80%E5%8F%91-01.png
---
# 流式对话
```yml
spring:
    ai:
        ollama:
            base-url: http://127.0.0.1:11434
            embedding:
                options:
                    model: text-embedding-ada-002
        openai:
            base-url: https://api.vveai.com
            api-key: sk-vArxm5LJ7SY8vUIM343869E1813544C5B80cEb7226BaB806
            embedding:
                options:
                    model: text-embedding-ada-002
```

```java
    @Bean
    public OpenAiApi openAiApi(@Value("${spring.ai.openai.base-url}") String baseUrl, @Value("${spring.ai.openai.api-key}") String apikey) {
        return OpenAiApi.builder()
                .baseUrl(baseUrl)
                .apiKey(apikey)
                .build();
    }
```
注入 OpenAiApi，OpenAiApi 是真正“干活”与 OpenAI 服务器对话的工具，后续 SpringAI 的封装层，比如说 `OpenAiChatClient`，其内部持有 `OpenAiApi` 的实例

```java
@RestController
@RequestMapping("/api/v1/openai/")
@CrossOrigin("*")
public class OpenAiController implements IAiService {

    @Resource
    private OpenAiChatClient chatClient;
    @Resource
    private PgVectorStore pgVectorStore;

    @RequestMapping(value = "generate", method = RequestMethod.GET)
    @Override
    public ChatResponse generate(@RequestParam String model, @RequestParam String message) {
        return chatClient.call(new Prompt(
                message,
                OpenAiChatOptions.builder()
                        .withModel(model)
                        .build()
        ));
    }

    /**
     * curl <a href="http://localhost:8090/api/v1/openai/generate_stream?model=gpt-4o&message=1+1">...</a>
     */
    @RequestMapping(value = "generate_stream", method = RequestMethod.GET)
    public Flux<ChatResponse> generateStream(@RequestParam String model, @RequestParam String message) {
        return chatClient.stream(new Prompt(
                message,
                OpenAiChatOptions.builder()
                        .withModel(model)
                        .build()
        ));
    }
}
```
`generateStream()` 方法产生流式对话

# 静态知识库

```java
    @Bean
    public OpenAiEmbeddingModel openAiEmbeddingModel(OpenAiApi openAiApi) {
        return new OpenAiEmbeddingModel(openAiApi);
    }

    @Bean("openAiPgVectorStore")
    public PgVectorStore pgVectorStore(OpenAiApi openAiApi, JdbcTemplate jdbcTemplate, OpenAiEmbeddingModel embeddingModel) {
        return PgVectorStore.builder(jdbcTemplate, embeddingModel)
                .vectorTableName("vector_store_openai")
                .build();
    }

    @Bean
    public TokenTextSplitter tokenTextSplitter() {
        return new TokenTextSplitter();
    }
```
* `OpenAiEmbeddingModel` ：“文本向量化”工具
调用 OpenAI 的 API 来生成“词嵌入”（Embeddings）。词嵌入是一种将文本（如单词、句子）转换为数值向量（一串数字）的技术，这些向量能捕捉文本的语义含义。
* `PgVectorStore `：连接到 PostgreSQL 的“向量数据库”
存储、管理和检索由上一个 Bean（embeddingModel）生成的向量。这通常用于实现语义搜索（即“查找含义相似的文本”）
* `TokenTextSplitter` ：创建一个文本分割器
大语言模型处理的文本长度是有限的。当你需要处理一篇长文章时，这个工具可以把它智能地分割成模型可以接受的小块，同时确保语义的完整性

```java
    @Test
    public void upload() {
    			// 读取数据
        TikaDocumentReader documentReader = new TikaDocumentReader("./data/file.txt");
        List<Document> documents = documentReader.get();
        List<Document> documentList = tokenTextSplitter.apply(documents);

        documents.forEach(doc -> doc.getMetadata().put("knowledge", "v1"));
        documentList.forEach(doc -> doc.getMetadata().put("knowledge", "v1"));

        pgVectorStore.accept(documentList);

        log.info("上传完成");
    }
```
```java
	documents.forEach(doc -> doc.getMetadata().put("knowledge", "v1"));
	documentList.forEach(doc -> doc.getMetadata().put("knowledge", "v1"));
```
功能: 添加元数据（Metadata）。

`doc.getMetadata().put(...)`: Document 对象不仅包含文本内容，还可以携带“元数据”（描述数据的数据）。

"knowledge", "v1": 在这里，开发者给原始文档（documents）和分割后的文档块（documentList）都打上了一个标签，键是 "knowledge"，值是 "v1"。

用途: 以后可以根据这个元数据来查询（“只搜索 v1 版本的知识”）或进行更新/删除（“删除所有 v1 的数据”）。

```java
    @Test
    public void chat() {
        String message = "王大瓜今年几岁";

        String SYSTEM_PROMPT = """
                Use the information from the DOCUMENTS section to provide accurate answers but act as if you knew this information innately.
                If unsure, simply state that you don't know.
                Another thing you need to note is that your reply must be in Chinese!
                DOCUMENTS:
                    {documents}
                """;

        SearchRequest request = SearchRequest.builder()
                .query(message)
                .topK(5)
                .filterExpression("knowledge == 'v1'")
                .build();

        List<Document> documents = pgVectorStore.similaritySearch(request);

        String documentsCollectors = documents == null ? "" : documents.stream().map(Document::getText).collect(Collectors.joining());

        Message ragMessage = new SystemPromptTemplate(SYSTEM_PROMPT).createMessage(Map.of("documents", documentsCollectors));
        ArrayList<Message> messages = new ArrayList<>();
        messages.add(ragMessage);
        messages.add(new UserMessage(message));

        ChatResponse chatResponse = openAiChatModel.call(new Prompt(messages, OpenAiChatOptions.builder().model("gpt-3.5-turbo").build()));

        log.info("测试结果:{}", JSON.toJSONString(chatResponse));
    }
```
这段代码展示了根据一个特定的问题，先从向量数据库中检索相关知识，然后将这些知识连同问题一起交给 AI 模型，最后由 AI 模型生成一个基于所提供知识的回答
```java
        SearchRequest request = SearchRequest.builder()
                .query(message)
                .topK(5)
                .filterExpression("knowledge == 'v1'")
                .build();
 ```
 query(message)： 使用用户的问题 "王大瓜今年几岁" 作为语义搜索的查询词。

topK(5)： 指示数据库返回最相似的 5 个文档块。

filterExpression("knowledge == 'v1'")： 这是一个元数据过滤器。它要求数据库只在那些元数据中包含 knowledge == 'v1' 的文档中进行搜索。这与上一个 upload 方法中设置的元数据 doc.getMetadata().put("knowledge", "v1") 对应。

pgVectorStore.similaritySearch(request)： 在 PostgreSQL 向量数据库中执行搜索，返回一个包含 5 个最相关 Document 对象的列表。

# MCP
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgAI%20%E5%BA%94%E7%94%A8%E5%BC%80%E5%8F%91-01.png)
mcp：ai 能理解的协议
ai 可以通过这个“协议”调用一些开发者写好的功能，比如说查询数据库
mcp 分为客户端和服务端

## 客户端
```json
{
  "mcpServers": {
    "mcp-server-computer": {
      "command": "java",
      "args": [
        "-Dfile.encoding=utf-8",
        "-Dspring.ai.mcp.server.stdio=true",
        "-jar",
        "D:\\project\\xiaofuge\\ai-mcp-knowledge\\mcp-server-computer\\target\\mcp-server-computer-1.0.0.jar"
      ]
    }
  }
}
```
```yml
spring:
    ai:
        mcp:
            client:
                request-timeout: 360s
                stdio:
                    servers-configuration: classpath:/config/mcp-servers-config.json
```
```java
    @Autowired
    private ToolCallbackProvider tools;
```

**工作流程如下：**

1.  **加载客户端配置 (YAML)**：
    * Spring Boot 启动时，会读取 `application.yml` (或 `.properties`) 文件。
    * 它找到了 `spring.ai.mcp.client` 配置，并得知 MCP 客户端需要去 `classpath:/config/mcp-servers-config.json` 这个路径下查找服务器的定义。

2.  **加载服务器定义 (JSON)**：
    * Spring AI 的 MCP 客户端会读取 `mcp-servers-config.json` 文件。
    * 它发现了一个名为 `mcp-server-computer` 的服务器。

3.  **启动外部服务 (子进程)**：
    * MCP 客户端会根据 JSON 中定义的 `command` 和 `args`，在本地**启动一个新的 Java 进程**（即 `java -jar ... mcp-server-computer-1.0.0.jar`）。
    * `Dspring.ai.mcp.server.stdio=true` 这个参数告诉那个被启动的 `jar` 包，它应该通过**标准输入/输出 (Stdio)** 来与父进程（即您的主 Spring Boot 应用）进行 MCP 协议通信。

4.  **工具发现与注册**：
    * 一旦子进程（`mcp-server-computer`）启动，它会通过 Stdio 告诉主应用（MCP 客户端）：“你好，我已经启动了，我提供了以下工具（Tool/Function）：[工具A, 工具B, ...]”。
    * Spring AI 的 MCP 客户端接收到这个工具列表后，会**自动**为 `mcp-server-computer` 提供的**每一个工具**动态地创建一个 `ToolCallback` Bean。

5.  **注入 `ToolCallbackProvider`**：
    * `ToolCallbackProvider` 是 Spring AI 中用于管理和提供**所有**可用 `ToolCallback` 的核心接口。
    * 当您使用 `@Autowired private ToolCallbackProvider tools;` 时，Spring 注入的是一个**包含了所有已注册工具**的提供者实例。
    * 这其中**就包括了**在第 4 步中从 `mcp-server-computer` 子进程动态发现并注册的那些工具。

**总结一下：**

**不需要**手动创建 `ToolCallback`。只需要通过 JSON 和 YAML **声明** MCP 服务的存在和启动方式，Spring AI 的自动配置就会负责启动它、发现它提供的工具，并将这些工具自动注册到 `ToolCallbackProvider` 中，使其在应用中立即可用。

```java
@Slf4j
@RunWith(SpringRunner.class)
@SpringBootTest
public class MCPTest {

    @Resource
    private ChatClient.Builder chatClientBuilder;

    @Autowired
    private ToolCallbackProvider tools;

    @Test
    public void test_tool() {
        String userInput = "有哪些工具可以使用";
        var chatClient = chatClientBuilder
                .defaultTools(tools)
                .defaultOptions(OpenAiChatOptions.builder()
                        .model("gpt-3.5-turbo")
                        .build())
                .build();

        System.out.println("\n>>> QUESTION: " + userInput);
        System.out.println("\n>>> ASSISTANT: " + chatClient.prompt(userInput).call().content());
    }

    @Test
    public void test() {
        String userInput = "获取电脑配置";
//        userInput = "在 /Users/fuzhengwei/Desktop 文件夹下，创建 电脑.txt";
        userInput = "获取电脑配置 在 D:\\project\\xiaofuge\\ai-rag-knowledge\\lbwxxc-ai-rag-knowledge\\xfg-dev-tech-app\\cloned-repo 文件夹下，创建 电脑.txt 把电脑配置写入 电脑.txt";
        String mysqlInput = "获取所有订单";
        var chatClient = chatClientBuilder
                .defaultTools(tools)
                .defaultOptions(OpenAiChatOptions.builder()
                        .model("gpt-4o")
                        .build())
                .build();

        System.out.println("\n>>> QUESTION: " + mysqlInput);
        System.out.println("\n>>> ASSISTANT: " + chatClient.prompt(mysqlInput).call().content());
    }

}
```

## 服务端
创建两个 Bean，Bean 内部想想要对 ai 开放的方法加上 @Tool 注解
```java
@Slf4j
@Service
public class ComputerService {

    @Tool(description = "获取电脑配置")
    public ComputerFunctionResponse queryConfig(ComputerFunctionRequest request) {
        log.info("获取电脑配置信息 {}", request.getComputer());
        // 获取系统属性
        Properties properties = System.getProperties();

        // 操作系统名称
        String osName = properties.getProperty("os.name");
        // 操作系统版本
        String osVersion = properties.getProperty("os.version");
        // 操作系统架构
        String osArch = properties.getProperty("os.arch");
        // 用户的账户名称
        String userName = properties.getProperty("user.name");
        // 用户的主目录
        String userHome = properties.getProperty("user.home");
        // 用户的当前工作目录
        String userDir = properties.getProperty("user.dir");
        // Java 运行时环境版本
        String javaVersion = properties.getProperty("java.version");

        String osInfo = "";
        // 根据操作系统执行特定的命令来获取更多信息
        if (osName.toLowerCase().contains("win")) {
            // Windows特定的代码
            osInfo = getWindowsSpecificInfo();
        } else if (osName.toLowerCase().contains("mac")) {
            // macOS特定的代码
            osInfo = getMacSpecificInfo();
        } else if (osName.toLowerCase().contains("nix") || osName.toLowerCase().contains("nux")) {
            // Linux特定的代码
            osInfo = getLinuxSpecificInfo();
        }

        ComputerFunctionResponse response = new ComputerFunctionResponse();
        response.setOsName(osName);
        response.setOsVersion(osVersion);
        response.setOsArch(osArch);
        response.setUserName(userName);
        response.setUserHome(userHome);
        response.setUserDir(userDir);
        response.setJavaVersion(javaVersion);
        response.setOsInfo(osInfo);

        return response;
    }
	......
}
```
```java
@Data
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ComputerFunctionRequest {

    @JsonProperty(required = true, value = "computer")
    @JsonPropertyDescription("电脑名称")
    private String computer;

}
```
```java
@Data
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ComputerFunctionResponse {

    @JsonProperty(required = true, value = "osName")
    @JsonPropertyDescription("操作系统名称")
    private String osName;

    @JsonProperty(required = true, value = "osVersion")
    @JsonPropertyDescription("操作系统版本")
    private String osVersion;

    @JsonProperty(required = true, value = "osArch")
    @JsonPropertyDescription("操作系统架构")
    private String osArch;

    @JsonProperty(required = true, value = "userName")
    @JsonPropertyDescription("用户的账户名称")
    private String userName;

    @JsonProperty(required = true, value = "userHome")
    @JsonPropertyDescription("用户的主目录")
    private String userHome;

    @JsonProperty(required = true, value = "userDir")
    @JsonPropertyDescription("用户的当前工作目录")
    private String userDir;

    @JsonProperty(required = true, value = "javaVersion")
    @JsonPropertyDescription("Java 运行时环境版本")
    private String javaVersion;

    @JsonProperty(required = true, value = "osInfo")
    @JsonPropertyDescription("系统信息")
    private String osInfo;

}
```
服务端的方法
```java
@Slf4j
@SpringBootApplication
@Configurable
public class McpServerComputerApplication implements CommandLineRunner {

    public static void main(String[] args) {
        SpringApplication.run(McpServerComputerApplication.class, args);
    }

    @Bean
    public ToolCallbackProvider computerTools(ComputerService computerService, OrderService orderService) {
        return MethodToolCallbackProvider.builder().toolObjects(computerService, orderService).build();
    }

    @Override
    public void run(String... args) throws Exception {
        log.info("mcp server computer success!");
    }

}
```

这段代码是 **MCP 服务器（`mcp-server-computer`）的** **Spring Boot 启动类**。

这正是您上一段 JSON 配置中 `java -jar ... mcp-server-computer-1.0.0.jar` 命令所运行的那个 `.jar` 文件的**主程序**。

它的**核心用途**是：**定义并向 Spring AI 框架注册一组可供 AI 调用的工具（Tools）**。

-----
**1\. 核心功能：`@Bean computerTools`**

```java
    @Bean
    public ToolCallbackProvider computerTools(ComputerService computerService, OrderService orderService) {
        return MethodToolCallbackProvider.builder().toolObjects(computerService, orderService).build();
    }
```

  * **`@Bean`**: 告诉 Spring 框架，这是一个需要被管理的 Bean（组件）。
  * **`ToolCallbackProvider`**: 这是 Spring AI 用来管理“工具回调”的核心接口。
  * **`MethodToolCallbackProvider.builder()`**: 这是一个具体的实现，它能**自动扫描**一个或多个对象（Object）中被特定注解（如 `@Tool` 或 `@Description`）标记的**方法**，并将这些方法转换为 AI 可调用的工具。
  * **`toolObjects(computerService, orderService)`**: 这是关键所在。它告诉 Spring AI：
    1.  请自动注入 `ComputerService` 和 `OrderService` 这两个服务。
    2.  请**扫描**这两个服务里的所有公开方法。
    3.  将那些符合规范（被注解）的方法注册为 AI 工具。

**简而言之：这个 Bean 的作用就是向 AI 声明：“我这里有两套工具，一套是 `ComputerService` 里的，一套是 `OrderService` 里的，你可以调用它们”。**

-----

**2\. 启动和确认：`CommandLineRunner`**

```java
    @Override
    public void run(String... args) throws Exception {
        log.info("mcp server computer success!");
    }
```

  * **`implements CommandLineRunner`**: 这个接口让 `run` 方法会在 Spring Boot 应用**完全启动并加载完所有 Bean**（包括上面那个 `ToolCallbackProvider`）之后被自动执行。
  * **`log.info(...)`**: 它会在控制台打印一条日志 "mcp server computer success\!"。

这条日志有两个重要作用：

1.  **给开发者看**：表明这个服务（`.jar` 包）已经成功启动，没有报错。
2.  **给 MCP 客户端（父进程）看**：在 `stdio`（标准输入输出）通信模式下，父进程会监视这个子进程的输出。看到这条 "success" 日志，父进程就知道这个 MCP 服务器已经准备就绪，可以开始向它请求工具列表了。

# AI Agent - SpringAI 1.0.0
```yml
# 数据库配置；启动时配置数据库资源信息
spring:
    datasource:
        username: 
        password: 
        url: 
        driver-class-name: org.postgresql.Driver
        type: com.zaxxer.hikari.HikariDataSource
        hikari:
            pool-name: Retail_HikariCP
            minimum-idle: 15 #最小空闲连接数量
            idle-timeout: 180000 #空闲连接存活最大时间，默认600000（10分钟）
            maximum-pool-size: 25 #连接池最大连接数，默认是10
            auto-commit: true  #此属性控制从池返回的连接的默认自动提交行为,默认值：true
            max-lifetime: 1800000 #此属性控制池中连接的最长生命周期，值0表示无限生命周期，默认1800000即30分钟
            connection-timeout: 30000 #数据库连接超时时间,默认30秒，即30000
            connection-test-query: SELECT 1
    ai:
        openai:
            base-url: 
            api-key: 
```
构建 MCP 工具
```java
    public McpSyncClient mcpAsyncClientSystem() {
        ServerParameters stdioParams = ServerParameters.builder("java")
                .args("-Dfile.encoding=utf-8",
                        "-Dspring.ai.mcp.server.stdio=true",
                        "-jar",
                        "D:\\project\\xiaofuge\\ai-mcp-knowledge\\mcp-server-computer\\target\\mcp-server-computer-1.0.0.jar")
                .build();

        McpSyncClient mcpSyncClient = McpClient.sync(new StdioClientTransport(stdioParams)).requestTimeout(Duration.ofSeconds(10)).build();

        McpSchema.InitializeResult initialize = mcpSyncClient.initialize();

        System.out.println("Stdio MCP Initialized: " + initialize);

        return mcpSyncClient;
    }
```
初始化
```java
    private ChatModel chatModel;

    private ChatClient chatClient;

    @Resource
    private PgVectorStore vectorStore;

    @Before
    public void init() {
        OpenAiApi openAiApi = OpenAiApi.builder()
                .baseUrl("https://api.vveai.com")
                .apiKey("sk-vArxm5LJ7SY8vUIM343869E1813544C5B80cEb7226BaB806")
                .completionsPath("v1/chat/completions")
                .embeddingsPath("v1/embeddings")
                .build();

        chatModel = OpenAiChatModel.builder()
                .openAiApi(openAiApi)
                .defaultOptions(OpenAiChatOptions.builder()
                        .model("gpt-4.1-mini")
                        .toolCallbacks(new SyncMcpToolCallbackProvider(mcpAsyncClientSystem()).getToolCallbacks())
                        .build())
                .build();

        chatClient = ChatClient.builder(chatModel)
                .defaultSystem("""
                        	 你是一个 AI Agent 智能体，，今天是 {current_date}。
                        
                        	 你可以分析系统配置和查询订单记录
                        """)
                .defaultAdvisors(
                        PromptChatMemoryAdvisor.builder(
                                MessageWindowChatMemory.builder()
                                        .maxMessages(100)
                                        .build()
                        ).build(),
                        new RagAnswerAdvisor(vectorStore, SearchRequest.builder()
                                .topK(5)
                                .filterExpression("knowledge == 'article-prompt-words'")
                                .build()),
                        SimpleLoggerAdvisor.builder().build()
                )
                .build();
    }
```
## 多数据源和 Mapper 配置
```yml
# 数据库配置；启动时配置数据库资源信息
spring:
    datasource:
        mysql:
            username: 
            password: 
            url: 
            driver-class-name: com.mysql.cj.jdbc.Driver
            type: com.zaxxer.hikari.HikariDataSource
            hikari:
                pool-name: Retail_HikariCP
                minimum-idle: 15 #最小空闲连接数量
                idle-timeout: 180000 #空闲连接存活最大时间，默认600000（10分钟）
                maximum-pool-size: 25 #连接池最大连接数，默认是10
                auto-commit: true  #此属性控制从池返回的连接的默认自动提交行为,默认值：true
                max-lifetime: 1800000 #此属性控制池中连接的最长生命周期，值0表示无限生命周期，默认1800000即30分钟
                connection-timeout: 30000 #数据库连接超时时间,默认30秒，即30000
                connection-test-query: SELECT 1
        pgvector:
            username: 
            password: 
            url: 
            driver-class-name: org.postgresql.Driver
            type: com.zaxxer.hikari.HikariDataSource
            hikari:
                pool-name: Retail_HikariCP
                minimum-idle: 15 #最小空闲连接数量
                idle-timeout: 180000 #空闲连接存活最大时间，默认600000（10分钟）
                maximum-pool-size: 25 #连接池最大连接数，默认是10
                auto-commit: true  #此属性控制从池返回的连接的默认自动提交行为,默认值：true
                max-lifetime: 1800000 #此属性控制池中连接的最长生命周期，值0表示无限生命周期，默认1800000即30分钟
                connection-timeout: 30000 #数据库连接超时时间,默认30秒，即30000
                connection-test-query: SELECT 1
```
```java
@Configuration
public class DataSourceConfig {

    @Bean("mysqlDataSource")
    @Primary
    public DataSource mysqlDataSource(@Value("${spring.datasource.mysql.driver-class-name}") String driverClassName,
                                      @Value("${spring.datasource.mysql.url}") String url,
                                      @Value("${spring.datasource.mysql.username}") String username,
                                      @Value("${spring.datasource.mysql.password}") String password,
                                      @Value("${spring.datasource.mysql.hikari.maximum-pool-size:10}") int maximumPoolSize,
                                      @Value("${spring.datasource.mysql.hikari.minimum-idle:5}") int minimumIdle,
                                      @Value("${spring.datasource.mysql.hikari.idle-timeout:30000}") long idleTimeout,
                                      @Value("${spring.datasource.mysql.hikari.connection-timeout:30000}") long connectionTimeout,
                                      @Value("${spring.datasource.mysql.hikari.max-lifetime:1800000}") long maxLifetime) {
        // 连接池配置
        HikariDataSource dataSource = new HikariDataSource();
        dataSource.setDriverClassName(driverClassName);
        dataSource.setJdbcUrl(url);
        dataSource.setUsername(username);
        dataSource.setPassword(password);

        dataSource.setMaximumPoolSize(maximumPoolSize);
        dataSource.setMinimumIdle(minimumIdle);
        dataSource.setIdleTimeout(idleTimeout);
        dataSource.setConnectionTimeout(connectionTimeout);
        dataSource.setMaxLifetime(maxLifetime);
        dataSource.setPoolName("MainHikariPool");

        return dataSource;
    }

    @Bean("sqlSessionFactoryBean")
    public SqlSessionFactoryBean sqlSessionFactory(@Qualifier("mysqlDataSource") DataSource mysqlDataSource) throws Exception {
        SqlSessionFactoryBean sqlSessionFactoryBean = new SqlSessionFactoryBean();
        sqlSessionFactoryBean.setDataSource(mysqlDataSource);

        // 设置MyBatis配置文件位置
        PathMatchingResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();
        sqlSessionFactoryBean.setConfigLocation(resolver.getResource("classpath:/mybatis/config/mybatis-config.xml"));

        // 设置Mapper XML文件位置
        sqlSessionFactoryBean.setMapperLocations(resolver.getResources("classpath:/mybatis/mapper/*.xml"));

        return sqlSessionFactoryBean;
    }

    @Bean("sqlSessionTemplate")
    public SqlSessionTemplate sqlSessionTemplate(@Qualifier("sqlSessionFactoryBean") SqlSessionFactoryBean sqlSessionFactory) throws Exception {
        return new SqlSessionTemplate(Objects.requireNonNull(sqlSessionFactory.getObject()));
    }

    @Bean("pgVectorDataSource")
    public DataSource pgVectorDataSource(@Value("${spring.datasource.pgvector.driver-class-name}") String driverClassName,
                                         @Value("${spring.datasource.pgvector.url}") String url,
                                         @Value("${spring.datasource.pgvector.username}") String username,
                                         @Value("${spring.datasource.pgvector.password}") String password,
                                         @Value("${spring.datasource.pgvector.hikari.maximum-pool-size:5}") int maximumPoolSize,
                                         @Value("${spring.datasource.pgvector.hikari.minimum-idle:2}") int minimumIdle,
                                         @Value("${spring.datasource.pgvector.hikari.idle-timeout:30000}") long idleTimeout,
                                         @Value("${spring.datasource.pgvector.hikari.connection-timeout:30000}") long connectionTimeout) {
        // 连接池配置
        HikariDataSource dataSource = new HikariDataSource();
        dataSource.setDriverClassName(driverClassName);
        dataSource.setJdbcUrl(url);
        dataSource.setUsername(username);
        dataSource.setPassword(password);

        dataSource.setMaximumPoolSize(maximumPoolSize);
        dataSource.setMinimumIdle(minimumIdle);
        dataSource.setIdleTimeout(idleTimeout);
        dataSource.setConnectionTimeout(connectionTimeout);

        // 确保在启动时连接数据库
        dataSource.setInitializationFailTimeout(1);  // 设置为1ms，如果连接失败则快速失败
        dataSource.setConnectionTestQuery("SELECT 1"); // 简单的连接测试查询
        dataSource.setAutoCommit(true);
        dataSource.setPoolName("PgVectorHikariPool");
        return dataSource;
    }

    @Bean("pgVectorJdbcTemplate")
    public JdbcTemplate pgVectorJdbcTemplate(@Qualifier("pgVectorDataSource") DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }

}
```

## 动态实例化对话模型、实例化对话客户端
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgAI%20%E5%BA%94%E7%94%A8%E5%BC%80%E5%8F%91-02.png)
```java
    protected String doApply(ArmoryCommandEntity requestParameter, DefaultArmoryStrategyFactory.DynamicContext dynamicContext) throws Exception {
        log.info("Ai Agent 构建，API 构建节点 {}", JSON.toJSONString(requestParameter));

        List<AiClientApiVO> aiClientApiList = dynamicContext.getValue(AiAgentEnumVO.AI_CLIENT_API.getDataName());

        if (aiClientApiList == null || aiClientApiList.isEmpty()) {
            log.warn("没有需要被初始化的 ai client api");
            return null;
        }

        for (AiClientApiVO aiClientApiVO : aiClientApiList) {
            // 构建 OpenAiApi
            OpenAiApi openAiApi = OpenAiApi.builder()
                    .baseUrl(aiClientApiVO.getBaseUrl())
                    .apiKey(aiClientApiVO.getApiKey())
                    .completionsPath(aiClientApiVO.getCompletionsPath())
                    .embeddingsPath(aiClientApiVO.getEmbeddingsPath())
                    .build();

            // 注册 OpenAiApi Bean 对象
            registerBean(AiAgentEnumVO.AI_CLIENT_API.getBeanName(aiClientApiVO.getApiId()), OpenAiApi.class, openAiApi);
        }

        return router(requestParameter, dynamicContext);
    }
```
实例化 OpenAiApi，并注册为 Bean

```java
    @Override
    protected String doApply(ArmoryCommandEntity requestParameter, DefaultArmoryStrategyFactory.DynamicContext dynamicContext) throws Exception {
        log.info("Ai Agent 构建节点，Tool MCP 工具配置{}", JSON.toJSONString(requestParameter));

        List<AiClientToolMcpVO> aiClientToolMcpList = dynamicContext.getValue(dataName());

        if (aiClientToolMcpList == null || aiClientToolMcpList.isEmpty()) {
            log.warn("没有需要被初始化的 ai client tool mcp");
            return router(requestParameter, dynamicContext);
        }

        for (AiClientToolMcpVO mcpVO : aiClientToolMcpList) {
            // 创建 MCP 服务
            McpSyncClient mcpSyncClient = createMcpSyncClient(mcpVO);

            // 注册 MCP 对象
            registerBean(beanName(mcpVO.getMcpId()), McpSyncClient.class, mcpSyncClient);
        }

        return router(requestParameter, dynamicContext);
    }

    @Override
    public StrategyHandler<ArmoryCommandEntity, DefaultArmoryStrategyFactory.DynamicContext, String> get(ArmoryCommandEntity armoryCommandEntity, DefaultArmoryStrategyFactory.DynamicContext dynamicContext) throws Exception {
        return aiClientModelNode;
    }

    private McpSyncClient createMcpSyncClient(AiClientToolMcpVO aiClientToolMcpVO) {
        String transportType = aiClientToolMcpVO.getTransportType();

        switch (transportType) {
            case "sse" -> {
                AiClientToolMcpVO.TransportConfigSse transportConfigSse = aiClientToolMcpVO.getTransportConfigSse();
                // http://127.0.0.1:9999/sse?apikey=DElk89iu8Ehhnbu
                String originalBaseUri = transportConfigSse.getBaseUri();
                String baseUri;
                String sseEndpoint;

                int queryParamStartIndex = originalBaseUri.indexOf("sse");
                if (queryParamStartIndex != -1) {
                    baseUri = originalBaseUri.substring(0, queryParamStartIndex - 1);
                    sseEndpoint = originalBaseUri.substring(queryParamStartIndex - 1);
                } else {
                    baseUri = originalBaseUri;
                    sseEndpoint = transportConfigSse.getSseEndpoint();
                }

                sseEndpoint = StringUtils.isBlank(sseEndpoint) ? "/sse" : sseEndpoint;

                HttpClientSseClientTransport sseClientTransport = HttpClientSseClientTransport
                        .builder(baseUri) // 使用截取后的 baseUri
                        .sseEndpoint(sseEndpoint) // 使用截取或默认的 sseEndpoint
                        .build();

                McpSyncClient mcpSyncClient = McpClient.sync(sseClientTransport).requestTimeout(Duration.ofMinutes(aiClientToolMcpVO.getRequestTimeout())).build();
                var init_sse = mcpSyncClient.initialize();

                log.info("Tool SSE MCP Initialized {}", init_sse);
                return mcpSyncClient;
            }
            case "stdio" -> {
                AiClientToolMcpVO.TransportConfigStdio transportConfigStdio = aiClientToolMcpVO.getTransportConfigStdio();
                Map<String, AiClientToolMcpVO.TransportConfigStdio.Stdio> stdioMap = transportConfigStdio.getStdio();
                AiClientToolMcpVO.TransportConfigStdio.Stdio stdio = stdioMap.get(aiClientToolMcpVO.getMcpName());

                // https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem
                var stdioParams = ServerParameters.builder(stdio.getCommand())
                        .args(stdio.getArgs())
                        .env(stdio.getEnv())
                        .build();

                var mcpClient = McpClient.sync(new StdioClientTransport(stdioParams))
                        .requestTimeout(Duration.ofSeconds(aiClientToolMcpVO.getRequestTimeout())).build();
                var init_stdio = mcpClient.initialize();

                log.info("Tool Stdio MCP Initialized {}", init_stdio);
                return mcpClient;
            }
        }

        throw new RuntimeException("err! transportType " + transportType + " not exist!");
    }
```

实例化MCP 并注册为 Bean

```java
    @Override
    protected String doApply(ArmoryCommandEntity requestParameter, DefaultArmoryStrategyFactory.DynamicContext dynamicContext) throws Exception {
        log.info("Ai Agent 构建节点，Node 对话模型{}", JSON.toJSONString(requestParameter));

        List<AiClientModelVO> aiClientModelList = dynamicContext.getValue(dataName());

        if (aiClientModelList == null || aiClientModelList.isEmpty()) {
            log.warn("没有需要被初始化的 ai client model");
            return router(requestParameter, dynamicContext);
        }

        for (AiClientModelVO modelVO : aiClientModelList) {

            // 获取当前模型关联的 API Bean 对象
            OpenAiApi openAiApi = getBean(AiAgentEnumVO.AI_CLIENT_API.getBeanName(modelVO.getApiId()));
            if (null == openAiApi) {
                throw new RuntimeException("mode 2 api is null");
            }

            // 获取当前模型关联的 Tool MCP Bean 对象
            List<McpSyncClient> mcpSyncClients = new ArrayList<>();
            for (String toolMcpId : modelVO.getToolMcpIds()) {
                McpSyncClient mcpSyncClient = getBean(AiAgentEnumVO.AI_CLIENT_TOOL_MCP.getBeanName(toolMcpId));
                mcpSyncClients.add(mcpSyncClient);
            }

            // 实例化对话模型（如果有其他模型对接，可以使用 one-api 服务，转换为 openai 模型格式）
            OpenAiChatModel chatModel = OpenAiChatModel.builder()
                    .openAiApi(openAiApi)
                    .defaultOptions(
                            OpenAiChatOptions.builder()
                                    .model(modelVO.getModelName())
                                    .toolCallbacks(new SyncMcpToolCallbackProvider(mcpSyncClients).getToolCallbacks())
                                    .build())
                    .build();

            // 注册 Bean 对象
            registerBean(beanName(modelVO.getModelId()), OpenAiChatModel.class, chatModel);
        }

        return router(requestParameter, dynamicContext);
    }
```
根据 openAiApi、MCP 的 Bean，实例化 OpenAiChatModel

```java
@Slf4j
@Service
public class AiClientNode extends AbstractArmorySupport {

    @Override
    protected String doApply(ArmoryCommandEntity requestParameter, DefaultArmoryStrategyFactory.DynamicContext dynamicContext) throws Exception {
        log.info("Ai Agent 构建节点，客户端{}", JSON.toJSONString(requestParameter));

        List<AiClientVO> aiClientList = dynamicContext.getValue(dataName());

        if (null == aiClientList || aiClientList.isEmpty()) {
            return router(requestParameter, dynamicContext);
        }

        Map<String, AiClientSystemPromptVO> systemPromptMap = dynamicContext.getValue(AiAgentEnumVO.AI_CLIENT_SYSTEM_PROMPT.getDataName());

        for (AiClientVO aiClientVO : aiClientList) {
            // 1. 预设话术
            StringBuilder defaultSystem = new StringBuilder("Ai 智能体 \r\n");
            List<String> promptIdList = aiClientVO.getPromptIdList();
            for (String promptId : promptIdList) {
                AiClientSystemPromptVO aiClientSystemPromptVO = systemPromptMap.get(promptId);
                defaultSystem.append(aiClientSystemPromptVO.getPromptContent());
            }

            // 2. 对话模型
            OpenAiChatModel chatModel = getBean(aiClientVO.getModelBeanName());

            // 3. MCP 服务
            List<McpSyncClient> mcpSyncClients = new ArrayList<>();
            List<String> mcpBeanNameList = aiClientVO.getMcpBeanNameList();
            for (String mcpBeanName : mcpBeanNameList) {
                mcpSyncClients.add(getBean(mcpBeanName));
            }

            // 4. advisor 顾问角色
            List<Advisor> advisors = new ArrayList<>();
            List<String> advisorBeanNameList = aiClientVO.getAdvisorBeanNameList();
            for (String advisorBeanName : advisorBeanNameList) {
                advisors.add(getBean(advisorBeanName));
            }

            Advisor[] advisorArray = advisors.toArray(new Advisor[]{});

            // 5. 构建对话客户端
            ChatClient chatClient = ChatClient.builder(chatModel)
                    .defaultSystem(defaultSystem.toString())
                    .defaultToolCallbacks(new SyncMcpToolCallbackProvider(mcpSyncClients.toArray(new McpSyncClient[]{})))
                    .defaultAdvisors(advisorArray)
                    .build();

            registerBean(beanName(aiClientVO.getClientId()), ChatClient.class, chatClient);
        }

        return router(requestParameter, dynamicContext);
    }

    @Override
    public StrategyHandler<ArmoryCommandEntity, DefaultArmoryStrategyFactory.DynamicContext, String> get(ArmoryCommandEntity requestParameter, DefaultArmoryStrategyFactory.DynamicContext dynamicContext) throws Exception {
        return defaultStrategyHandler;
    }

    @Override
    protected String beanName(String id) {
        return AiAgentEnumVO.AI_CLIENT.getBeanName(id);
    }

    @Override
    protected String dataName() {
        return AiAgentEnumVO.AI_CLIENT.getDataName();
    }

}
```

