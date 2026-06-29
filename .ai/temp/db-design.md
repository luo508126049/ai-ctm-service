# ai-ctm-service 数据库设计

## 1. 设计边界

本设计面向 AI 智能客服与业务助手场景，覆盖客户、订单、售后、业务流程、AI 对话、工具调用审计、统计汇总和知识库元数据。当前项目尚未接入真实数据库，本设计作为 database-first 权威 Schema 输入，后续 Java 工程实现实体、Mapper、Repository 或 Migration 时应以 `db-init.sql` 为准。

默认数据库目标为 MySQL 8.0，字符集 `utf8mb4`，排序规则 `utf8mb4_0900_ai_ci`。所有业务表使用 `tenant_id` 支持多租户隔离，使用应用层全局过滤实现租户隔离；数据库层不启用强外键，避免高并发写入、离线导入和未来分库分表时产生耦合。

## 2. 逻辑数据模型

核心领域划分：

- 租户与账号：`tenants`、`users`
- 客户域：`customers`
- 订单域：`orders`、`order_events`
- 售后域：`after_sales_requests`
- 流程域：`business_processes`
- AI 对话域：`ai_conversations`、`ai_messages`、`ai_tool_invocations`
- 统计域：`customer_daily_statistics`
- 知识库域：`knowledge_documents`

关系说明：

- 一个租户拥有多个用户、客户、订单、售后单、流程单和 AI 对话。
- 一个客户可以拥有多个订单、售后单和对话。
- 一个订单可以拥有多个订单事件和售后单。
- 一个 AI 对话包含多条消息和多次工具调用。
- 统计表按租户、统计日期、统计范围预聚合，供 AI 工具快速查询。

## 3. 关键设计决策

- 主键统一使用 `BIGINT UNSIGNED AUTO_INCREMENT`，便于早期单库快速开发；分布式部署后可切换为雪花 ID，由应用层生成。
- 状态字段统一使用 `TINYINT UNSIGNED`，在字段 COMMENT 中声明枚举映射，减少字符串状态带来的存储和索引成本。
- PII 字段只保留加密值或脱敏展示值。手机号、邮箱、姓名等字段在数据库层标注安全要求，应用层负责 AES-256-GCM 加密与脱敏。
- AI 消息内容和工具参数使用 `JSON`，保留模型交互上下文和工具调用审计能力。
- 大表按时间和租户设计复合索引。`ai_messages`、`ai_tool_invocations`、`order_events` 数据量超过 100 万行后建议按月归档或按 `created_at` 分区。
- 不启用 DB 外键。引用完整性由应用层和事务控制保证，查询通过索引字段关联。

## 4. 表设计

### tenants（租户表）

**业务用途**：保存系统租户，用于隔离客户、订单、AI 对话和统计数据。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_code | VARCHAR(64) | NOT NULL, UNIQUE | - | 租户编码，由应用层提供 | - |
| tenant_name | VARCHAR(128) | NOT NULL | - | 租户名称 | - |
| status | TINYINT UNSIGNED | NOT NULL | 1 | 1启用 2停用 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户，0表示系统 | - |
| is_deleted | TINYINT(1) | NOT NULL | 0 | 逻辑删除 | - |
| deleted_at | DATETIME | NULL | NULL | 删除时间 | - |

**索引设计**：`uk_tenants_tenant_code` 支持按租户编码定位；`idx_tenants_status` 支持后台筛选启停状态。

### users（用户表）

**业务用途**：保存客服、管理员、系统执行账号，用于审计字段和业务操作归属。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| username | VARCHAR(64) | NOT NULL | - | 登录名 | - |
| display_name | VARCHAR(128) | NOT NULL | '' | 展示名 | PII，返回时脱敏可选 |
| role_code | VARCHAR(64) | NOT NULL | 'agent' | 角色编码 | - |
| status | TINYINT UNSIGNED | NOT NULL | 1 | 1启用 2停用 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_users_tenant_username` 防止同租户登录名重复；`idx_users_tenant_status` 支持租户内用户列表。

### customers（客户表）

**业务用途**：保存对话服务对象和业务查询对象，是订单、售后和对话的归属主体。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| customer_no | VARCHAR(64) | NOT NULL | - | 客户编号 | - |
| real_name_enc | VARBINARY(512) | NULL | NULL | 真实姓名密文 | PII, AES-256-GCM |
| phone_hash | CHAR(64) | NULL | NULL | 手机号 SHA-256，用于等值查询 | PII Hash |
| phone_masked | VARCHAR(32) | NOT NULL | '' | 手机号脱敏值，如 138****8888 | PII Masked |
| email_hash | CHAR(64) | NULL | NULL | 邮箱 SHA-256 | PII Hash |
| level_code | VARCHAR(32) | NOT NULL | 'normal' | 客户等级 | - |
| status | TINYINT UNSIGNED | NOT NULL | 1 | 1正常 2冻结 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_customers_tenant_customer_no` 支持客户编号定位；`idx_customers_tenant_phone_hash` 支持手机号精确查询。

### orders（订单表）

**业务用途**：保存订单概要，供 AI 工具按订单号查询支付、物流和履约状态。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| customer_id | BIGINT UNSIGNED | NOT NULL | - | 客户 ID | - |
| order_no | VARCHAR(64) | NOT NULL | - | 订单号 | - |
| payment_status | TINYINT UNSIGNED | NOT NULL | 0 | 0待支付 1已支付 2退款中 3已退款 | - |
| order_status | TINYINT UNSIGNED | NOT NULL | 0 | 0待处理 1已确认 2已出库 3已完成 4已取消 | - |
| logistics_status | TINYINT UNSIGNED | NOT NULL | 0 | 0无物流 1待揽收 2运输中 3已签收 4异常 | - |
| total_amount | DECIMAL(18,4) | NOT NULL | 0.0000 | 订单金额 | - |
| paid_at | DATETIME | NULL | NULL | 支付时间 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_orders_tenant_order_no` 支持订单号查询；`idx_orders_tenant_customer_created` 支持客户订单列表；`idx_orders_tenant_created_status` 支持统计聚合。

### order_events（订单事件表）

**业务用途**：保存订单状态时间线，用于 AI 回复订单处理过程。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| order_id | BIGINT UNSIGNED | NOT NULL | - | 订单 ID | - |
| event_type | VARCHAR(64) | NOT NULL | - | 事件类型，如 paid/shipped/signed | - |
| event_title | VARCHAR(128) | NOT NULL | - | 事件标题 | - |
| event_detail | VARCHAR(512) | NOT NULL | '' | 事件详情 | 可能含业务敏感信息 |
| occurred_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 事件发生时间 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`idx_order_events_order_time` 支持订单时间线；超过 100 万行后按月归档历史事件。

### after_sales_requests（售后单表）

**业务用途**：保存退款、退货、补发等售后请求，支撑售后查询和统计。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| request_no | VARCHAR(64) | NOT NULL | - | 售后单号 | - |
| order_id | BIGINT UNSIGNED | NOT NULL | - | 订单 ID | - |
| customer_id | BIGINT UNSIGNED | NOT NULL | - | 客户 ID | - |
| request_type | TINYINT UNSIGNED | NOT NULL | 1 | 1退款 2退货 3补发 4人工复核 | - |
| status | TINYINT UNSIGNED | NOT NULL | 0 | 0待处理 1处理中 2通过 3拒绝 4关闭 | - |
| reason | VARCHAR(512) | NOT NULL | '' | 售后原因 | 可能含敏感信息 |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_after_sales_tenant_request_no` 支持单号查询；`idx_after_sales_tenant_created_status` 支持售后统计。

### business_processes（业务流程表）

**业务用途**：保存 AI 或人工发起的流程处理单，如退款、售后、补发、人工复核。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| process_no | VARCHAR(64) | NOT NULL | - | 流程号 | - |
| business_type | VARCHAR(64) | NOT NULL | - | 业务类型 | - |
| target_type | VARCHAR(64) | NOT NULL | - | 目标类型，如 order/after_sales/customer | - |
| target_no | VARCHAR(64) | NOT NULL | - | 目标业务编号 | - |
| status | TINYINT UNSIGNED | NOT NULL | 0 | 0已创建 1处理中 2已完成 3已拒绝 4已取消 | - |
| reason | VARCHAR(512) | NOT NULL | '' | 发起原因 | 可能含敏感信息 |
| source | TINYINT UNSIGNED | NOT NULL | 1 | 1人工 2AI工具 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_business_processes_tenant_process_no` 支持流程号查询；`idx_business_processes_target` 支持按目标对象查询流程。

### ai_conversations（AI 对话表）

**业务用途**：保存一次会话的上下文元信息，用于追踪用户对话和工具调用。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| customer_id | BIGINT UNSIGNED | NULL | NULL | 客户 ID，匿名对话可为空 | - |
| conversation_no | VARCHAR(64) | NOT NULL | - | 会话编号 | - |
| channel | VARCHAR(32) | NOT NULL | 'web' | 渠道 | - |
| model_provider | VARCHAR(32) | NOT NULL | '' | deepseek/ollama 等 | - |
| model_name | VARCHAR(128) | NOT NULL | '' | 模型名称 | - |
| status | TINYINT UNSIGNED | NOT NULL | 1 | 1进行中 2已结束 3异常 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_ai_conversations_tenant_no` 支持会话定位；`idx_ai_conversations_customer_created` 支持客户历史对话。

### ai_messages（AI 消息表）

**业务用途**：保存用户、助手、工具消息内容，支撑审计、问题复盘和上下文回放。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| conversation_id | BIGINT UNSIGNED | NOT NULL | - | 会话 ID | - |
| role | TINYINT UNSIGNED | NOT NULL | 1 | 1user 2assistant 3tool 4system | - |
| content | MEDIUMTEXT | NOT NULL | - | 消息正文，由应用层强制提供 | 可能含 PII，建议加密或脱敏存储 |
| token_count | INT UNSIGNED | NOT NULL | 0 | token 数 | - |
| created_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 创建时间 | - |

**索引设计**：`idx_ai_messages_conversation_id` 支持会话消息读取；超过 100 万行后按月归档。

### ai_tool_invocations（AI 工具调用表）

**业务用途**：记录模型调用工具的请求、响应、耗时和结果，是安全审计核心表。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| conversation_id | BIGINT UNSIGNED | NOT NULL | - | 会话 ID | - |
| tool_name | VARCHAR(128) | NOT NULL | - | 工具名称 | - |
| request_payload | JSON | NOT NULL | - | 工具入参 JSON | 可能含 PII，应用层脱敏 |
| response_payload | JSON | NULL | NULL | 工具响应 JSON | 可能含敏感业务数据 |
| status | TINYINT UNSIGNED | NOT NULL | 0 | 0开始 1成功 2失败 3拒绝 | - |
| duration_ms | INT UNSIGNED | NOT NULL | 0 | 耗时毫秒 | - |
| error_message | VARCHAR(512) | NOT NULL | '' | 错误摘要 | - |
| created_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 调用时间 | - |

**索引设计**：`idx_ai_tool_invocations_conversation` 支持会话审计；`idx_ai_tool_invocations_tool_time` 支持工具使用统计。

### customer_daily_statistics（客服日统计表）

**业务用途**：按天预聚合客服核心指标，供 `query_customer_statistics` 工具快速返回。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| stat_date | DATE | NOT NULL | - | 统计日期 | - |
| order_count | INT UNSIGNED | NOT NULL | 0 | 订单数 | - |
| after_sales_count | INT UNSIGNED | NOT NULL | 0 | 售后数 | - |
| manual_transfer_count | INT UNSIGNED | NOT NULL | 0 | 转人工数 | - |
| satisfaction_score | DECIMAL(5,2) | NOT NULL | 0.00 | 满意度评分 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |

**索引设计**：`uk_customer_daily_statistics_tenant_date` 保证每日一条；统计查询直接走租户+日期范围。

### knowledge_documents（知识库文档表）

**业务用途**：保存知识库文件元数据，未来支持替代本地 `knowledge_base` 文件目录。

| 字段名 | 类型 | 约束 | 默认值 | 说明 | 安全标注 |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT UNSIGNED | PK, AUTO_INCREMENT | - | 主键 | - |
| tenant_id | BIGINT UNSIGNED | NOT NULL | - | 租户 ID | RLS |
| document_code | VARCHAR(64) | NOT NULL | - | 文档编码 | - |
| title | VARCHAR(256) | NOT NULL | - | 文档标题 | - |
| content_hash | CHAR(64) | NOT NULL | - | 内容 SHA-256 | - |
| storage_uri | VARCHAR(512) | NOT NULL | '' | 存储地址 | 可能含内部路径 |
| status | TINYINT UNSIGNED | NOT NULL | 1 | 1启用 2停用 | - |
| created_at/updated_at | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 审计时间 | - |
| created_by/updated_by | BIGINT UNSIGNED | NOT NULL | 0 | 审计用户 | - |
| is_deleted/deleted_at | TINYINT(1)/DATETIME | NOT NULL/NULL | 0/NULL | 逻辑删除 | - |

**索引设计**：`uk_knowledge_documents_tenant_code` 支持文档编码定位；`idx_knowledge_documents_status` 支持启用文档扫描。

## 5. 性能与容量

- `ai_messages`、`ai_tool_invocations`、`order_events` 是增长最快的表。超过 100 万行后，按月归档；超过 1000 万行后，按 `created_at` 做 RANGE 分区。
- 统计查询优先使用 `customer_daily_statistics`，避免每次 AI 对话实时扫描订单和售后明细。
- 大表分页禁止深 `OFFSET`，推荐使用 `WHERE id > last_id ORDER BY id LIMIT n`。
- 查询订单详情时，先按 `orders.order_no` 定位订单，再批量查询 `order_events`，避免 N+1。

## 6. 安全与合规

- 租户隔离由 `tenant_id` + 应用层强制过滤实现，所有业务查询必须带租户条件。
- 客户姓名使用 AES-256-GCM 加密；手机号、邮箱使用 SHA-256 Hash 支持精确匹配，同时保存脱敏展示值。
- AI 消息与工具参数可能包含敏感数据，生产环境建议进行内容脱敏或字段级加密。
- 工具调用写操作必须记录 `ai_tool_invocations`，便于审计 AI 是否触发流程变更。

## 7. 事务边界

- 创建业务流程时，`business_processes` 与 `ai_tool_invocations` 成功记录应在同一业务事务或可靠补偿流程内完成。
- 创建售后单时，`after_sales_requests` 与相关 `business_processes` 需要事务保护。
- 订单状态变更时，`orders` 与 `order_events` 需要同事务提交，保证状态和时间线一致。

## 8. 交付文件

- 设计文档：`.ai/temp/db-design.md`
- 初始化脚本：`.ai/temp/db-init.sql`
