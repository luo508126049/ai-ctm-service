CREATE DATABASE IF NOT EXISTS ai_ctm_service
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE ai_ctm_service;

CREATE TABLE tenants (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_code VARCHAR(64) NOT NULL COMMENT '租户编码，由应用层强制提供',
  tenant_name VARCHAR(128) NOT NULL COMMENT '租户名称，最大128个Unicode字符',
  status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '租户状态：1启用，2停用',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间，服务器本地时区',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间，服务器本地时区',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_tenants_tenant_code (tenant_code),
  KEY idx_tenants_status (status)
) ENGINE=InnoDB COMMENT='租户表';

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  username VARCHAR(64) NOT NULL COMMENT '登录名，同租户内唯一',
  display_name VARCHAR(128) NOT NULL DEFAULT '' COMMENT '展示名，可能包含个人信息',
  role_code VARCHAR(64) NOT NULL DEFAULT 'agent' COMMENT '角色编码：admin/agent/system',
  status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '用户状态：1启用，2停用',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_tenant_username (tenant_id, username),
  KEY idx_users_tenant_status (tenant_id, status)
) ENGINE=InnoDB COMMENT='用户表';

CREATE TABLE customers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  customer_no VARCHAR(64) NOT NULL COMMENT '客户编号，同租户内唯一',
  real_name_enc VARBINARY(512) NULL DEFAULT NULL COMMENT '真实姓名密文，AES-256-GCM加密',
  phone_hash CHAR(64) NULL DEFAULT NULL COMMENT '手机号SHA-256哈希，用于等值查询',
  phone_masked VARCHAR(32) NOT NULL DEFAULT '' COMMENT '手机号脱敏展示值，例如138****8888',
  email_hash CHAR(64) NULL DEFAULT NULL COMMENT '邮箱SHA-256哈希，用于等值查询',
  level_code VARCHAR(32) NOT NULL DEFAULT 'normal' COMMENT '客户等级编码：normal/vip/blacklist',
  status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '客户状态：1正常，2冻结',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_customers_tenant_customer_no (tenant_id, customer_no),
  KEY idx_customers_tenant_phone_hash (tenant_id, phone_hash),
  KEY idx_customers_tenant_status (tenant_id, status)
) ENGINE=InnoDB COMMENT='客户表';

CREATE TABLE orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  customer_id BIGINT UNSIGNED NOT NULL COMMENT '客户ID，引用customers.id，应用层维护完整性',
  order_no VARCHAR(64) NOT NULL COMMENT '订单号，同租户内唯一',
  payment_status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '支付状态：0待支付，1已支付，2退款中，3已退款',
  order_status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '订单状态：0待处理，1已确认，2已出库，3已完成，4已取消',
  logistics_status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '物流状态：0无物流，1待揽收，2运输中，3已签收，4异常',
  total_amount DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '订单金额，精确到4位小数',
  paid_at DATETIME NULL DEFAULT NULL COMMENT '支付时间，未支付为空',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_orders_tenant_order_no (tenant_id, order_no),
  KEY idx_orders_tenant_customer_created (tenant_id, customer_id, created_at),
  KEY idx_orders_tenant_created_status (tenant_id, created_at, order_status, payment_status)
) ENGINE=InnoDB COMMENT='订单表';

CREATE TABLE order_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  order_id BIGINT UNSIGNED NOT NULL COMMENT '订单ID，引用orders.id，应用层维护完整性',
  event_type VARCHAR(64) NOT NULL COMMENT '事件类型，例如paid/shipped/signed/refunded',
  event_title VARCHAR(128) NOT NULL COMMENT '事件标题，面向用户展示',
  event_detail VARCHAR(512) NOT NULL DEFAULT '' COMMENT '事件详情，可能包含业务敏感信息',
  occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '事件发生时间',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  KEY idx_order_events_order_time (tenant_id, order_id, occurred_at),
  KEY idx_order_events_tenant_time (tenant_id, occurred_at)
) ENGINE=InnoDB COMMENT='订单事件表';

CREATE TABLE after_sales_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  request_no VARCHAR(64) NOT NULL COMMENT '售后单号，同租户内唯一',
  order_id BIGINT UNSIGNED NOT NULL COMMENT '订单ID，引用orders.id，应用层维护完整性',
  customer_id BIGINT UNSIGNED NOT NULL COMMENT '客户ID，引用customers.id，应用层维护完整性',
  request_type TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '售后类型：1退款，2退货，3补发，4人工复核',
  status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0待处理，1处理中，2通过，3拒绝，4关闭',
  reason VARCHAR(512) NOT NULL DEFAULT '' COMMENT '售后原因，可能包含敏感业务信息',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_after_sales_tenant_request_no (tenant_id, request_no),
  KEY idx_after_sales_tenant_created_status (tenant_id, created_at, status),
  KEY idx_after_sales_order (tenant_id, order_id),
  KEY idx_after_sales_customer (tenant_id, customer_id)
) ENGINE=InnoDB COMMENT='售后单表';

CREATE TABLE business_processes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  process_no VARCHAR(64) NOT NULL COMMENT '流程号，同租户内唯一',
  business_type VARCHAR(64) NOT NULL COMMENT '业务类型，例如refund/after_sales/resend/manual_review',
  target_type VARCHAR(64) NOT NULL COMMENT '目标类型，例如order/after_sales/customer',
  target_no VARCHAR(64) NOT NULL COMMENT '目标业务编号，例如订单号或售后单号',
  status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '流程状态：0已创建，1处理中，2已完成，3已拒绝，4已取消',
  reason VARCHAR(512) NOT NULL DEFAULT '' COMMENT '流程发起原因，可能包含敏感业务信息',
  source TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '来源：1人工，2AI工具',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_business_processes_tenant_process_no (tenant_id, process_no),
  KEY idx_business_processes_target (tenant_id, target_type, target_no),
  KEY idx_business_processes_status_time (tenant_id, status, created_at)
) ENGINE=InnoDB COMMENT='业务流程表';

CREATE TABLE ai_conversations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  customer_id BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '客户ID，匿名对话为空',
  conversation_no VARCHAR(64) NOT NULL COMMENT '会话编号，同租户内唯一',
  channel VARCHAR(32) NOT NULL DEFAULT 'web' COMMENT '对话渠道：web/api/admin',
  model_provider VARCHAR(32) NOT NULL DEFAULT '' COMMENT '模型提供方，例如deepseek/ollama',
  model_name VARCHAR(128) NOT NULL DEFAULT '' COMMENT '模型名称，例如deepseek-chat/qwen2.5:32b',
  status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '会话状态：1进行中，2已结束，3异常',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_ai_conversations_tenant_no (tenant_id, conversation_no),
  KEY idx_ai_conversations_customer_created (tenant_id, customer_id, created_at),
  KEY idx_ai_conversations_status_time (tenant_id, status, created_at)
) ENGINE=InnoDB COMMENT='AI对话表';

CREATE TABLE ai_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  conversation_id BIGINT UNSIGNED NOT NULL COMMENT '会话ID，引用ai_conversations.id，应用层维护完整性',
  role TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '消息角色：1user，2assistant，3tool，4system',
  content MEDIUMTEXT NOT NULL COMMENT '消息正文，可能包含PII，生产环境建议脱敏或加密',
  token_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '消息token数量',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_ai_messages_conversation_id (tenant_id, conversation_id, id),
  KEY idx_ai_messages_tenant_time (tenant_id, created_at)
) ENGINE=InnoDB COMMENT='AI消息表';

CREATE TABLE ai_tool_invocations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  conversation_id BIGINT UNSIGNED NOT NULL COMMENT '会话ID，引用ai_conversations.id，应用层维护完整性',
  tool_name VARCHAR(128) NOT NULL COMMENT '工具名称，例如query_customer_statistics',
  request_payload JSON NOT NULL COMMENT '工具请求参数JSON，可能包含PII，应用层应脱敏',
  response_payload JSON NULL DEFAULT NULL COMMENT '工具响应JSON，可能包含业务敏感数据',
  status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '调用状态：0开始，1成功，2失败，3拒绝',
  duration_ms INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '工具执行耗时，单位毫秒',
  error_message VARCHAR(512) NOT NULL DEFAULT '' COMMENT '错误摘要，成功时为空字符串',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '调用时间',
  PRIMARY KEY (id),
  KEY idx_ai_tool_invocations_conversation (tenant_id, conversation_id, created_at),
  KEY idx_ai_tool_invocations_tool_time (tenant_id, tool_name, created_at, status)
) ENGINE=InnoDB COMMENT='AI工具调用审计表';

CREATE TABLE customer_daily_statistics (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  stat_date DATE NOT NULL COMMENT '统计日期',
  order_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '订单数量',
  after_sales_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '售后数量',
  manual_transfer_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '转人工次数',
  satisfaction_score DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT '满意度评分，范围0.00到5.00',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  PRIMARY KEY (id),
  UNIQUE KEY uk_customer_daily_statistics_tenant_date (tenant_id, stat_date)
) ENGINE=InnoDB COMMENT='客服日统计表';

CREATE TABLE knowledge_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID，应用层强制按租户过滤',
  document_code VARCHAR(64) NOT NULL COMMENT '文档编码，同租户内唯一',
  title VARCHAR(256) NOT NULL COMMENT '文档标题，最大256个Unicode字符',
  content_hash CHAR(64) NOT NULL COMMENT '文档内容SHA-256哈希',
  storage_uri VARCHAR(512) NOT NULL DEFAULT '' COMMENT '文档存储地址，可能包含内部路径',
  status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '文档状态：1启用，2停用',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  created_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人用户ID，0表示系统',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  updated_by BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '更新人用户ID，0表示系统',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除标记：0否，1是',
  deleted_at DATETIME NULL DEFAULT NULL COMMENT '逻辑删除时间，未删除为空',
  PRIMARY KEY (id),
  UNIQUE KEY uk_knowledge_documents_tenant_code (tenant_id, document_code),
  KEY idx_knowledge_documents_status (tenant_id, status, updated_at)
) ENGINE=InnoDB COMMENT='知识库文档表';

INSERT INTO tenants (id, tenant_code, tenant_name, status, created_by, updated_by)
VALUES (1, 'default', '默认租户', 1, 0, 0);

INSERT INTO users (id, tenant_id, username, display_name, role_code, status, created_by, updated_by)
VALUES
  (1, 1, 'system', '系统', 'system', 1, 0, 0),
  (2, 1, 'admin', '管理员', 'admin', 1, 0, 0);

INSERT INTO customer_daily_statistics
  (tenant_id, stat_date, order_count, after_sales_count, manual_transfer_count, satisfaction_score, created_by, updated_by)
VALUES
  (1, CURRENT_DATE, 1280, 96, 42, 4.70, 0, 0);

INSERT INTO knowledge_documents
  (tenant_id, document_code, title, content_hash, storage_uri, status, created_by, updated_by)
VALUES
  (1, 'shipping_faq', '物流常见问题', REPEAT('0', 64), 'classpath:knowledge_base/shipping_faq.txt', 1, 0, 0),
  (1, 'return_policy', '退换货政策', REPEAT('0', 64), 'classpath:knowledge_base/return_policy.txt', 1, 0, 0),
  (1, 'membership_points', '会员积分说明', REPEAT('0', 64), 'classpath:knowledge_base/membership_points.txt', 1, 0, 0);
