package org.ai.common.service;

import org.ai.common.tool.CustomerBusinessTools;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;

@Service
public class CustomerService {

    private static final String SYSTEM_PROMPT = """
            你是一个企业客服与业务助手。
            你可以回答普通客服问题，也可以在用户询问统计数据、查询结果或业务流程处理时调用工具。
            调用工具前先判断用户意图，工具返回后用简洁中文解释结果。
            如果用户请求缺少必要参数，请先追问，不要编造数据。
            涉及写入、创建流程、状态变更类操作时，需要在回复中明确说明已经触发的是系统工具能力。
            """;

    private final ChatClient chatClient;
    private final CustomerBusinessTools customerBusinessTools;

    public CustomerService(ChatClient.Builder chatClientBuilder, CustomerBusinessTools customerBusinessTools) {
        this.chatClient = chatClientBuilder
                .defaultSystem(SYSTEM_PROMPT)
                .build();
        this.customerBusinessTools = customerBusinessTools;
    }

    /**
     * 执行一次普通对话，模型可根据用户意图自动调用业务工具。
     *
     * @param userMessage 用户输入
     * @return AI 生成的最终回复
     */
    public String chat(String userMessage) {
        return chatClient.prompt()
                .user(userMessage)
                .tools(customerBusinessTools)
                .call()
                .content();
    }

    /**
     * 执行流式对话，模型可根据用户意图自动调用业务工具。
     *
     * @param userMessage 用户输入
     * @param emitter     SSE 输出通道
     */
    public void chatStream(String userMessage, SseEmitter emitter) {
        chatClient.prompt()
                .user(userMessage)
                .tools(customerBusinessTools)
                .stream()
                .content()
                .subscribe(
                        token -> sendToken(emitter, token),
                        emitter::completeWithError,
                        () -> completeStream(emitter)
                );
    }

    private void sendToken(SseEmitter emitter, String token) {
        try {
            emitter.send(token);
        } catch (IOException e) {
            emitter.completeWithError(e);
        }
    }

    private void completeStream(SseEmitter emitter) {
        try {
            emitter.send(SseEmitter.event().name("complete").data("[DONE]"));
            emitter.complete();
        } catch (IOException e) {
            emitter.completeWithError(e);
        }
    }
}
