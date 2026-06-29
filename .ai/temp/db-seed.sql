USE ai_ctm_service;

INSERT INTO users
  (id, tenant_id, username, display_name, role_code, status, created_by, updated_by)
VALUES
  (11, 1, 'agent_chen', '客服陈晨', 'agent', 1, 1, 1),
  (12, 1, 'agent_li', '客服李敏', 'agent', 1, 1, 1),
  (13, 1, 'ops_wang', '运营王强', 'admin', 1, 1, 1)
ON DUPLICATE KEY UPDATE
  display_name = VALUES(display_name),
  role_code = VALUES(role_code),
  status = VALUES(status),
  updated_by = VALUES(updated_by);

INSERT INTO customers
  (id, tenant_id, customer_no, real_name_enc, phone_hash, phone_masked, email_hash, level_code, status, created_by, updated_by)
VALUES
  (101, 1, 'CUST202606270001', UNHEX('00112233445566778899AABBCCDDEEFF'), REPEAT('a', 64), '138****8001', REPEAT('1', 64), 'vip', 1, 11, 11),
  (102, 1, 'CUST202606270002', UNHEX('102132435465768798A9BACBDCEDFE0F'), REPEAT('b', 64), '139****8002', REPEAT('2', 64), 'normal', 1, 11, 11),
  (103, 1, 'CUST202606270003', UNHEX('2031425364758697A8B9CADBECFD0E1F'), REPEAT('c', 64), '137****8003', REPEAT('3', 64), 'normal', 1, 12, 12),
  (104, 1, 'CUST202606270004', UNHEX('30415263748596A7B8C9DAEBFC0D1E2F'), REPEAT('d', 64), '136****8004', REPEAT('4', 64), 'vip', 1, 12, 12),
  (105, 1, 'CUST202606270005', UNHEX('405162738495A6B7C8D9EAFB0C1D2E3F'), REPEAT('e', 64), '135****8005', REPEAT('5', 64), 'normal', 2, 13, 13)
ON DUPLICATE KEY UPDATE
  phone_masked = VALUES(phone_masked),
  level_code = VALUES(level_code),
  status = VALUES(status),
  updated_by = VALUES(updated_by);

INSERT INTO orders
  (id, tenant_id, customer_id, order_no, payment_status, order_status, logistics_status, total_amount, paid_at, created_by, updated_by)
VALUES
  (1001, 1, 101, 'SO202606270001', 1, 2, 2, 1299.0000, NOW() - INTERVAL 5 DAY, 11, 11),
  (1002, 1, 101, 'SO202606270002', 1, 3, 3, 299.0000, NOW() - INTERVAL 12 DAY, 11, 11),
  (1003, 1, 102, 'SO202606270003', 1, 1, 1, 588.0000, NOW() - INTERVAL 2 DAY, 12, 12),
  (1004, 1, 103, 'SO202606270004', 0, 0, 0, 899.0000, NULL, 12, 12),
  (1005, 1, 104, 'SO202606270005', 2, 2, 4, 1688.0000, NOW() - INTERVAL 8 DAY, 11, 11),
  (1006, 1, 104, 'SO202606270006', 3, 4, 0, 199.0000, NOW() - INTERVAL 20 DAY, 11, 11),
  (1007, 1, 105, 'SO202606270007', 1, 2, 2, 459.0000, NOW() - INTERVAL 1 DAY, 13, 13),
  (1008, 1, 102, 'SO202606270008', 1, 3, 3, 79.0000, NOW() - INTERVAL 15 DAY, 12, 12)
ON DUPLICATE KEY UPDATE
  payment_status = VALUES(payment_status),
  order_status = VALUES(order_status),
  logistics_status = VALUES(logistics_status),
  total_amount = VALUES(total_amount),
  paid_at = VALUES(paid_at),
  updated_by = VALUES(updated_by);

INSERT INTO order_events
  (id, tenant_id, order_id, event_type, event_title, event_detail, occurred_at, created_by, updated_by)
VALUES
  (2001, 1, 1001, 'paid', '订单已支付', '客户完成支付，等待仓库处理', NOW() - INTERVAL 5 DAY, 11, 11),
  (2002, 1, 1001, 'shipped', '仓库已出库', '包裹已交由物流承运商', NOW() - INTERVAL 4 DAY, 11, 11),
  (2003, 1, 1001, 'in_transit', '物流运输中', '预计2天内送达', NOW() - INTERVAL 2 DAY, 11, 11),
  (2004, 1, 1002, 'signed', '订单已签收', '客户已确认收货', NOW() - INTERVAL 9 DAY, 11, 11),
  (2005, 1, 1003, 'paid', '订单已支付', '等待仓库拣货', NOW() - INTERVAL 2 DAY, 12, 12),
  (2006, 1, 1005, 'exception', '物流异常', '客户反馈包裹停滞，已转人工复核', NOW() - INTERVAL 3 DAY, 11, 11),
  (2007, 1, 1006, 'refunded', '订单已退款', '退款已原路返回', NOW() - INTERVAL 18 DAY, 11, 11),
  (2008, 1, 1008, 'signed', '订单已签收', '订单履约完成', NOW() - INTERVAL 12 DAY, 12, 12)
ON DUPLICATE KEY UPDATE
  event_title = VALUES(event_title),
  event_detail = VALUES(event_detail),
  occurred_at = VALUES(occurred_at),
  updated_by = VALUES(updated_by);

INSERT INTO after_sales_requests
  (id, tenant_id, request_no, order_id, customer_id, request_type, status, reason, created_by, updated_by)
VALUES
  (3001, 1, 'AS202606270001', 1005, 104, 4, 1, '物流异常超过48小时，客户要求人工复核', 11, 11),
  (3002, 1, 'AS202606270002', 1006, 104, 1, 2, '客户取消订单后申请退款', 11, 11),
  (3003, 1, 'AS202606270003', 1002, 101, 2, 0, '客户反馈商品尺寸不合适', 12, 12),
  (3004, 1, 'AS202606270004', 1007, 105, 3, 1, '客户反馈配件缺失，申请补发', 13, 13)
ON DUPLICATE KEY UPDATE
  request_type = VALUES(request_type),
  status = VALUES(status),
  reason = VALUES(reason),
  updated_by = VALUES(updated_by);

INSERT INTO business_processes
  (id, tenant_id, process_no, business_type, target_type, target_no, status, reason, source, created_by, updated_by)
VALUES
  (4001, 1, 'BP202606270001', 'manual_review', 'order', 'SO202606270005', 1, 'AI识别物流异常并发起人工复核', 2, 1, 11),
  (4002, 1, 'BP202606270002', 'refund', 'order', 'SO202606270006', 2, '客户取消订单，退款流程已完成', 1, 11, 11),
  (4003, 1, 'BP202606270003', 'resend', 'order', 'SO202606270007', 1, '客户反馈配件缺失，进入补发流程', 2, 1, 13),
  (4004, 1, 'BP202606270004', 'after_sales', 'after_sales', 'AS202606270003', 0, '客户申请退货，等待客服审核', 1, 12, 12),
  (4005, 1, 'BP202606270005', 'manual_review', 'customer', 'CUST202606270005', 3, '客户状态冻结，拒绝自动处理', 2, 1, 13)
ON DUPLICATE KEY UPDATE
  status = VALUES(status),
  reason = VALUES(reason),
  source = VALUES(source),
  updated_by = VALUES(updated_by);

INSERT INTO ai_conversations
  (id, tenant_id, customer_id, conversation_no, channel, model_provider, model_name, status, created_by, updated_by)
VALUES
  (5001, 1, 101, 'CONV202606270001', 'web', 'deepseek', 'deepseek-chat', 2, 1, 1),
  (5002, 1, 104, 'CONV202606270002', 'web', 'deepseek', 'deepseek-chat', 2, 1, 1),
  (5003, 1, NULL, 'CONV202606270003', 'web', 'ollama', 'qwen2.5:32b', 1, 1, 1)
ON DUPLICATE KEY UPDATE
  customer_id = VALUES(customer_id),
  model_provider = VALUES(model_provider),
  model_name = VALUES(model_name),
  status = VALUES(status),
  updated_by = VALUES(updated_by);

INSERT INTO ai_messages
  (id, tenant_id, conversation_id, role, content, token_count, created_at)
VALUES
  (6001, 1, 5001, 1, '帮我查询订单SO202606270001现在到哪了', 18, NOW() - INTERVAL 1 HOUR),
  (6002, 1, 5001, 2, '订单SO202606270001已出库，目前物流运输中，预计2天内送达。', 36, NOW() - INTERVAL 59 MINUTE),
  (6003, 1, 5002, 1, '这个物流异常订单帮我发起人工复核', 20, NOW() - INTERVAL 40 MINUTE),
  (6004, 1, 5002, 2, '已为订单SO202606270005创建人工复核流程，流程号BP202606270001。', 38, NOW() - INTERVAL 39 MINUTE),
  (6005, 1, 5003, 1, '查询本月客服统计数据', 12, NOW() - INTERVAL 10 MINUTE)
ON DUPLICATE KEY UPDATE
  content = VALUES(content),
  token_count = VALUES(token_count),
  created_at = VALUES(created_at);

INSERT INTO ai_tool_invocations
  (id, tenant_id, conversation_id, tool_name, request_payload, response_payload, status, duration_ms, error_message, created_at)
VALUES
  (7001, 1, 5001, 'query_order_result',
    JSON_OBJECT('orderNo', 'SO202606270001'),
    JSON_OBJECT('orderNo', 'SO202606270001', 'paymentStatus', 'PAID', 'orderStatus', 'SHIPPED', 'logisticsState', 'IN_TRANSIT'),
    1, 126, '', NOW() - INTERVAL 59 MINUTE),
  (7002, 1, 5002, 'create_business_process',
    JSON_OBJECT('businessType', '人工复核', 'targetNo', 'SO202606270005', 'reason', '物流异常超过48小时'),
    JSON_OBJECT('processNo', 'BP202606270001', 'status', 'CREATED'),
    1, 188, '', NOW() - INTERVAL 39 MINUTE),
  (7003, 1, 5003, 'query_customer_statistics',
    JSON_OBJECT('timeRange', '本月'),
    JSON_OBJECT('orderCount', 1280, 'afterSalesCount', 96, 'manualTransferCount', 42, 'satisfactionScore', 4.7),
    1, 92, '', NOW() - INTERVAL 9 MINUTE)
ON DUPLICATE KEY UPDATE
  request_payload = VALUES(request_payload),
  response_payload = VALUES(response_payload),
  status = VALUES(status),
  duration_ms = VALUES(duration_ms),
  error_message = VALUES(error_message),
  created_at = VALUES(created_at);

INSERT INTO customer_daily_statistics
  (id, tenant_id, stat_date, order_count, after_sales_count, manual_transfer_count, satisfaction_score, created_by, updated_by)
VALUES
  (8001, 1, CURRENT_DATE - INTERVAL 6 DAY, 156, 11, 7, 4.62, 0, 0),
  (8002, 1, CURRENT_DATE - INTERVAL 5 DAY, 182, 12, 8, 4.70, 0, 0),
  (8003, 1, CURRENT_DATE - INTERVAL 4 DAY, 175, 14, 6, 4.66, 0, 0),
  (8004, 1, CURRENT_DATE - INTERVAL 3 DAY, 193, 13, 5, 4.81, 0, 0),
  (8005, 1, CURRENT_DATE - INTERVAL 2 DAY, 201, 17, 7, 4.75, 0, 0),
  (8006, 1, CURRENT_DATE - INTERVAL 1 DAY, 184, 15, 4, 4.73, 0, 0),
  (8007, 1, CURRENT_DATE, 189, 14, 5, 4.78, 0, 0)
ON DUPLICATE KEY UPDATE
  order_count = VALUES(order_count),
  after_sales_count = VALUES(after_sales_count),
  manual_transfer_count = VALUES(manual_transfer_count),
  satisfaction_score = VALUES(satisfaction_score),
  updated_by = VALUES(updated_by);
