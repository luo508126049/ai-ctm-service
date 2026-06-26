(function () {
    const form = document.getElementById("chatForm");
    const input = document.getElementById("messageInput");
    const messages = document.getElementById("messages");
    const sendBtn = document.getElementById("sendBtn");
    const stopBtn = document.getElementById("stopBtn");
    const clearBtn = document.getElementById("clearBtn");
    const connectionText = document.getElementById("connectionText");
    const quickQuestions = document.querySelectorAll(".quick-question");

    let currentSource = null;
    let currentAssistantBubble = null;
    let hasReceivedToken = false;

    function scrollToBottom() {
        messages.scrollTop = messages.scrollHeight;
    }

    function setStreaming(streaming) {
        sendBtn.disabled = streaming;
        input.disabled = streaming;
        stopBtn.hidden = !streaming;
        connectionText.textContent = streaming ? "正在接收实时回复..." : "等待提问";
    }

    function autoResize() {
        input.style.height = "auto";
        input.style.height = `${Math.min(input.scrollHeight, 150)}px`;
    }

    function createMessage(role, text) {
        const article = document.createElement("article");
        article.className = `message ${role}`;

        const avatar = document.createElement("div");
        avatar.className = "avatar";
        avatar.setAttribute("aria-hidden", "true");
        avatar.textContent = role === "user" ? "我" : "AI";

        const bubble = document.createElement("div");
        bubble.className = "bubble";
        const paragraph = document.createElement("p");
        paragraph.textContent = text;
        bubble.appendChild(paragraph);

        article.appendChild(avatar);
        article.appendChild(bubble);
        messages.appendChild(article);
        scrollToBottom();

        return bubble;
    }

    function createTypingMessage() {
        const bubble = createMessage("assistant", "");
        bubble.innerHTML = '<span class="typing" aria-label="AI 正在输入"><span></span><span></span><span></span></span>';
        return bubble;
    }

    function appendToken(token) {
        if (!currentAssistantBubble) {
            return;
        }

        if (!hasReceivedToken) {
            currentAssistantBubble.textContent = "";
            hasReceivedToken = true;
        }

        currentAssistantBubble.textContent += token;
        scrollToBottom();
    }

    function showError(message) {
        if (currentAssistantBubble) {
            currentAssistantBubble.classList.add("error");
            currentAssistantBubble.textContent = message;
        } else {
            const bubble = createMessage("assistant", message);
            bubble.classList.add("error");
        }
    }

    function closeStream(statusText) {
        if (currentSource) {
            currentSource.close();
            currentSource = null;
        }
        currentAssistantBubble = null;
        hasReceivedToken = false;
        setStreaming(false);
        connectionText.textContent = statusText || "等待提问";
        input.disabled = false;
        input.focus();
    }

    function sendMessage(message) {
        const trimmed = message.trim();
        if (!trimmed || currentSource) {
            return;
        }

        createMessage("user", trimmed);
        currentAssistantBubble = createTypingMessage();
        hasReceivedToken = false;
        input.value = "";
        autoResize();
        setStreaming(true);

        const url = `/api/chat-stream?message=${encodeURIComponent(trimmed)}`;
        currentSource = new EventSource(url);

        currentSource.onmessage = function (event) {
            appendToken(event.data);
        };

        currentSource.onerror = function () {
            if (!hasReceivedToken) {
                showError("连接中断或服务暂不可用，请确认后端已启动并稍后重试。");
            }
            closeStream(hasReceivedToken ? "回复已结束" : "连接失败");
        };

        currentSource.addEventListener("complete", function () {
            closeStream("回复已结束");
        });
    }

    form.addEventListener("submit", function (event) {
        event.preventDefault();
        sendMessage(input.value);
    });

    input.addEventListener("input", autoResize);

    input.addEventListener("keydown", function (event) {
        if (event.key === "Enter" && !event.shiftKey) {
            event.preventDefault();
            form.requestSubmit();
        }
    });

    stopBtn.addEventListener("click", function () {
        closeStream("已停止接收");
    });

    clearBtn.addEventListener("click", function () {
        if (currentSource) {
            closeStream("已停止接收");
        }
        messages.innerHTML = "";
        createMessage("assistant", "你好，我是智能客服。你可以咨询退货、物流、会员积分等问题。");
    });

    quickQuestions.forEach(function (button) {
        button.addEventListener("click", function () {
            if (currentSource) {
                return;
            }
            input.value = button.textContent.trim();
            autoResize();
            input.focus();
        });
    });

    autoResize();
})();
