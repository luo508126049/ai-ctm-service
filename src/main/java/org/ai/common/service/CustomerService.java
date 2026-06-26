package org.ai.common.service;

import dev.langchain4j.data.document.Document;
import dev.langchain4j.data.document.DocumentSplitter;
import dev.langchain4j.data.document.loader.FileSystemDocumentLoader;
import dev.langchain4j.data.document.parser.TextDocumentParser;
import dev.langchain4j.data.document.splitter.DocumentSplitters;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.rag.content.retriever.EmbeddingStoreContentRetriever;
import dev.langchain4j.service.AiServices;
import dev.langchain4j.service.SystemMessage;
import dev.langchain4j.service.TokenStream;
import dev.langchain4j.service.UserMessage;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.inmemory.InMemoryEmbeddingStore;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

@Service
public class CustomerService {

    interface Assistant {
        @SystemMessage("你是一个专业的客服助理。\n"
                + "请根据提供的\"知识库内容\"来回答用户的问题。\n"
                + "如果知识库中没有相关信息，请礼貌地告知用户你不知道，并建议转接人工客服。\n"
                + "严禁编造答案。")
        String chat(@UserMessage String userMessage);
    }

    interface StreamingAssistant {
        @SystemMessage("你是一个专业的客服助理。\n"
                + "请根据提供的\"知识库内容\"来回答用户的问题。\n"
                + "如果知识库中没有相关信息，请礼貌地告知用户你不知道，并建议转接人工客服。\n"
                + "严禁编造答案。")
        TokenStream chat(@UserMessage String userMessage);
    }

    @Autowired
    private EmbeddingModel embeddingModel;

    @Autowired
    private OpenAiChatModel chatModel;

    @Autowired
    private OpenAiStreamingChatModel streamingChatModel;

    private Assistant assistant;
    private StreamingAssistant streamingAssistant;

    @PostConstruct
    public void init() {
        System.out.println("正在加载知识库文档...");

        Path knowledgeBasePath = Paths.get("src/main/resources/knowledge_base");
        List<Document> documents = FileSystemDocumentLoader.loadDocuments(
                knowledgeBasePath,
                doc -> doc.getFileName().toString().endsWith(".txt"),
                new TextDocumentParser()
        );
        System.out.println("已加载 " + documents.size() + " 个文档");

        DocumentSplitter splitter = DocumentSplitters.recursive(500, 50);
        List<TextSegment> segments = splitter.splitAll(documents);
        System.out.println("文档已切分为 " + segments.size() + " 个片段");

        System.out.println("正在生成向量索引，首次运行可能需要下载模型，请稍等...");
        EmbeddingStore<TextSegment> embeddingStore = new InMemoryEmbeddingStore<>();
        embeddingStore.addAll(embeddingModel.embedAll(segments).content(), segments);
        System.out.println("向量索引创建完成");

        ContentRetriever contentRetriever = EmbeddingStoreContentRetriever.builder()
                .embeddingStore(embeddingStore)
                .embeddingModel(embeddingModel)
                .maxResults(3)
                .build();

        this.assistant = AiServices.builder(Assistant.class)
                .chatLanguageModel(chatModel)
                .contentRetriever(contentRetriever)
                .build();

        this.streamingAssistant = AiServices.builder(StreamingAssistant.class)
                .streamingChatLanguageModel(streamingChatModel)
                .contentRetriever(contentRetriever)
                .build();
    }

    public String chat(String userMessage) {
        return assistant.chat(userMessage);
    }

    public void chatStream(String userMessage, SseEmitter emitter) {
        streamingAssistant.chat(userMessage)
                .onNext(token -> {
                    try {
                        emitter.send(token);
                    } catch (IOException e) {
                        emitter.completeWithError(e);
                    }
                })
                .onComplete(response -> {
                    try {
                        emitter.send(SseEmitter.event().name("complete").data("[DONE]"));
                        emitter.complete();
                    } catch (IOException e) {
                        emitter.completeWithError(e);
                    }
                })
                .onError(emitter::completeWithError)
                .start();
    }
}
