package org.ai.common.tool;

import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Component
public class CustomerBusinessTools {

    /**
     * 查询客服业务统计数据。
     *
     * @param timeRange 统计时间范围
     * @return 统计数据
     */
    @Tool(
            name = "query_customer_statistics",
            description = "查询客服业务统计数据。适用于用户询问订单量、售后量、满意度、响应时长等统计指标。"
    )
    public CustomerStatistics queryCustomerStatistics(
            @ToolParam(description = "统计时间范围，例如：今天、本周、本月、2026-06") String timeRange) {
        return new CustomerStatistics(
                timeRange,
                1280,
                96,
                42,
                4.7,
                "当前为示例统计数据，请在此方法中接入真实统计服务。"
        );
    }

    /**
     * 按订单号查询订单与履约结果。
     *
     * @param orderNo 订单号
     * @return 订单查询结果
     */
    @Tool(
            name = "query_order_result",
            description = "按订单号查询订单、支付、物流和售后状态。适用于用户询问某个订单当前处理结果。"
    )
    public OrderQueryResult queryOrderResult(
            @ToolParam(description = "订单号，例如：SO202606270001") String orderNo) {
        return new OrderQueryResult(
                orderNo,
                "PAID",
                "SHIPPED",
                "IN_TRANSIT",
                "预计 2 天内送达",
                List.of("订单已支付", "仓库已出库", "物流运输中")
        );
    }

    /**
     * 创建业务流程处理单。
     *
     * @param businessType 业务类型
     * @param targetNo     业务对象编号
     * @param reason       处理原因
     * @return 流程创建结果
     */
    @Tool(
            name = "create_business_process",
            description = "创建业务流程处理单。适用于用户要求发起退款、售后、补发、人工复核等流程。"
    )
    public BusinessProcessResult createBusinessProcess(
            @ToolParam(description = "业务类型，例如：退款、售后、补发、人工复核") String businessType,
            @ToolParam(description = "业务对象编号，例如订单号、售后单号、客户编号") String targetNo,
            @ToolParam(description = "流程发起原因") String reason) {
        var processNo = "BP" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
        return new BusinessProcessResult(
                processNo,
                businessType,
                targetNo,
                "CREATED",
                reason,
                "当前为示例流程创建结果，请在此方法中接入真实工作流或业务服务。"
        );
    }

    /**
     * 客服统计数据。
     *
     * @param timeRange           统计时间范围
     * @param orderCount          订单数
     * @param afterSalesCount     售后数
     * @param manualTransferCount 转人工数
     * @param satisfactionScore   满意度评分
     * @param remark              备注
     */
    public record CustomerStatistics(
            String timeRange,
            int orderCount,
            int afterSalesCount,
            int manualTransferCount,
            double satisfactionScore,
            String remark
    ) {
    }

    /**
     * 订单查询结果。
     *
     * @param orderNo        订单号
     * @param paymentStatus  支付状态
     * @param orderStatus    订单状态
     * @param logisticsState 物流状态
     * @param summary        摘要
     * @param timeline       处理时间线
     */
    public record OrderQueryResult(
            String orderNo,
            String paymentStatus,
            String orderStatus,
            String logisticsState,
            String summary,
            List<String> timeline
    ) {
    }

    /**
     * 流程创建结果。
     *
     * @param processNo    流程号
     * @param businessType 业务类型
     * @param targetNo     业务对象编号
     * @param status       流程状态
     * @param reason       发起原因
     * @param remark       备注
     */
    public record BusinessProcessResult(
            String processNo,
            String businessType,
            String targetNo,
            String status,
            String reason,
            String remark
    ) {
    }
}
