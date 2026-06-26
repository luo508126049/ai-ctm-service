package org.ai.common.config;

import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class LangChain4jConfig {

    @Value("${deepseek.api-key}")
    private String apiKey;

    @Bean
    public OpenAiChatModel chatModel() {
        return OpenAiChatModel.builder()
                .apiKey(apiKey)
                .baseUrl("https://api.deepseek.com/v1")
                .modelName("deepseek-chat")
                .temperature(0.5)
                .build();
    }

    @Bean
    public EmbeddingModel embeddingModel() {
        // 首次运行会下载约1.3GB的嵌入模型到本地，请耐心等待
        return new AllMiniLmL6V2EmbeddingModel();
    }

    @Bean
    public OpenAiStreamingChatModel streamingChatModel() {
        return OpenAiStreamingChatModel.builder()
                .apiKey(apiKey)
                .baseUrl("https://api.deepseek.com/v1")
                .modelName("deepseek-chat")
                .temperature(0.5)
                .build();
    }
}