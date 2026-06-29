# Frontend Engineer Task Notes - Phase 1

- Added Windows one-click frontend service script.
- Static frontend is served by Spring Boot on port 8984.
- Added start, stop, restart, and status actions.
- Runtime PID and logs are stored under `.run/`.
- Added `.run/` to `.gitignore`.
- Added port-process detection to avoid killing unrelated services.
