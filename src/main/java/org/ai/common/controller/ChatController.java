package org.ai.common.controller;

import org.ai.common.service.CustomerService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api")
public class ChatController {

    @Autowired
    private CustomerService customerService;

    @PostMapping("/chat")
    public String chat(@RequestParam("message") String message) {
        return customerService.chat(message);
    }

    @GetMapping(value = "/chat-stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chatStream(@RequestParam("message") String message) {
        SseEmitter emitter = new SseEmitter();
        customerService.chatStream(message, emitter);
        return emitter;
    }
}
