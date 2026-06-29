# ai-ctm-service

AI 智能客服与业务助手服务。项目基于 Spring Boot 构建，前端静态页面由后端直接托管，后端通过 Spring AI 对接大模型，并使用 `@Tool` 将统计查询、订单查询、流程处理等业务能力开放给 AI 在对话中调用。

## 项目定位

本项目用于验证和沉淀“对话式业务操作”能力：

- 用户通过前端聊天窗口发起自然语言请求。
- 后端将请求交给 Spring AI `ChatClient`。
- 大模型根据意图决定是否调用 `@Tool` 标注的业务工具。
- 工具返回结构化结果后，AI 将结果整理成自然语言回复给前端。

典型场景包括：

- 查询客服统计数据。
- 查询订单、支付、物流、售后状态。
- 发起退款、售后、补发、人工复核等业务流程。
- 在本地使用云端 DeepSeek 测试，在服务器无互联网环境使用 Ollama + Qwen 本地模型。

## 技术栈

- Java 17
- Spring Boot 4.1.0
- Spring AI 2.0.0
- Spring MVC / WebFlux
- Maven Wrapper
- DeepSeek Chat
- Ollama / Qwen 本地模型预埋
- 原生 HTML / CSS / JavaScript 静态前端

## 目录结构

```text
.
├── pom.xml
├── scripts/
│   ├── frontend.cmd
│   └── frontend.ps1
├── src/main/java/org/ai/
│   ├── common/
│   │   ├── controller/ChatController.java
│   │   ├── service/CustomerService.java
│   │   └── tool/CustomerBusinessTools.java
│   └── customer/CustomerApplication.java
└── src/main/resources/
    ├── application.yaml
    ├── application-local.yaml
    ├── application-server.yaml
    ├── knowledge_base/
    └── static/
```

## 核心模块

### ChatController

提供前端调用入口：

- `POST /api/chat`：普通对话接口。
- `GET /api/chat-stream`：SSE 流式对话接口。

### CustomerService

封装 Spring AI `ChatClient` 调用流程，统一注入系统提示词，并将业务工具传递给模型。

### CustomerBusinessTools

集中声明可被 AI 调用的业务工具。当前示例包括：

- `query_customer_statistics`：查询客服统计数据。
- `query_order_result`：查询订单结果。
- `create_business_process`：创建业务流程处理单。

后续接入真实业务时，优先在这些工具方法内部调用业务 Service，不要把数据库、HTTP 调用或流程编排逻辑写到 Controller 中。

## 模型配置

项目使用 Spring Profile 区分本地开发和服务器部署。

### local

本地默认 profile，使用 DeepSeek：

```yaml
spring:
  ai:
    model:
      chat: deepseek
```

API Key 优先读取环境变量：

```text
DEEPSEEK_API_KEY
```

### server

服务器 profile，使用 Ollama 本地模型：

```yaml
spring:
  ai:
    model:
      chat: ollama
```

默认模型配置为：

```text
qwen2.5:32b
```

可通过环境变量覆盖：

```text
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_CHAT_MODEL=qwen2.5:32b
AI_CHAT_TEMPERATURE=0.3
```

服务器部署前需要提前拉取模型：

```bash
ollama pull qwen2.5:32b
```

## 启动方式

### Windows 一键脚本

默认使用 `local` profile：

```powershell
scripts\frontend.cmd restart
```

显式指定本地 DeepSeek：

```powershell
scripts\frontend.cmd restart local
```

指定服务器 Ollama profile：

```powershell
scripts\frontend.cmd restart server
```

查看状态：

```powershell
scripts\frontend.cmd status
```

停止服务：

```powershell
scripts\frontend.cmd stop
```

启动后访问：

```text
http://localhost:8984/
```

### Maven 启动

```powershell
.\mvnw.cmd spring-boot:run
```

指定 profile：

```powershell
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=server
```

## 验证命令

编译与测试：

```powershell
.\mvnw.cmd test
```

测试 server profile 容器加载：

```powershell
.\mvnw.cmd test '-Dspring.profiles.active=server'
```

测试对话接口：

```powershell
curl.exe -s -X POST "http://localhost:8984/api/chat" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "message=帮我查询本月客服统计数据"
```

## 开发约定

- Controller 只负责协议适配，不写业务逻辑。
- Service 负责 AI 编排、业务编排和事务边界。
- `tool` 包只放可被 AI 调用的工具入口。
- `@Tool` 方法必须有明确、稳定、可被模型理解的名称和描述。
- 写操作类工具必须在提示词和工具描述中表达清楚行为边界。
- 本地开发优先使用 `local` profile。
- 无互联网服务器使用 `server` profile，并提前准备 Ollama 模型。

## 注意事项

- 当前 `CustomerBusinessTools` 中的统计、订单和流程结果是示例数据，需要接入真实业务服务后才能用于生产。
- 服务器无互联网环境下，必须提前准备 Maven 依赖、JDK、Ollama 安装包和模型文件。
- 大模型工具调用能力依赖模型本身对 tool/function calling 的支持，替换模型后需要重新做对话烟测。
- 不建议在配置文件中提交真实 API Key，生产环境应使用环境变量或外部配置中心。
