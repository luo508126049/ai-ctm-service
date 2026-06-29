# Java Engineer Task Notes - Phase 2

- Added Spring AI Ollama starter for offline server deployment.
- Split AI model configuration into `local` and `server` Spring profiles.
- Kept `local` profile on DeepSeek chat for internet-connected development.
- Added `server` profile for Ollama with Qwen-size model configuration.
- Updated frontend service script to accept an optional Spring profile argument.
