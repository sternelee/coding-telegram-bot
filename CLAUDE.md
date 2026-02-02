# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Telegram bot that provides remote access to Claude Code, enabling developers to interact with their code projects through Telegram. The bot features a terminal-like interface with directory navigation, file operations, Claude AI integration, session persistence, and advanced features like git integration and file uploads.

**Tech Stack:** Python 3.10+, Poetry for dependency management, SQLite for persistence, python-telegram-bot v22+ for Telegram integration, Anthropic SDK for Claude AI access.

## Common Development Commands

### Environment Setup
```bash
# Install dependencies
make dev

# Copy example configuration
cp .env.example .env
# Edit .env with your settings
```

### Running the Bot
```bash
# Normal mode
make run

# Debug mode (verbose logging, human-readable output)
make run-debug

# Direct Poetry command
poetry run claude-telegram-bot --debug

# With custom config file
poetry run claude-telegram-bot --config-file /path/to/config.env
```

### Testing
```bash
# Run all tests
make test

# Run specific test file
poetry run pytest tests/unit/test_config.py

# Run with coverage output
poetry run pytest --cov=src --cov-report=term-missing

# Run async tests specifically
poetry run pytest tests/unit/test_claude/test_sdk_integration.py -v

# Run with verbose output
poetry run pytest -v

# Run specific test function
poetry run pytest tests/unit/test_config.py::test_load_config
```

### Code Quality
```bash
# Format code
make format

# Run all linting checks
make lint

# Individual tools
poetry run black src tests              # Code formatting
poetry run isort src tests              # Import sorting
poetry run flake8 src tests             # Linting
poetry run mypy src                     # Type checking
```

## Architecture Overview

The codebase follows a layered architecture with clear separation of concerns:

### Core Components

1. **Configuration Layer** (`src/config/`)
   - Pydantic Settings v2 with environment variable loading
   - Environment-specific overrides (development/testing/production)
   - Feature flags system for dynamic functionality control
   - Type-safe configuration with cross-field validation

2. **Bot Layer** (`src/bot/`)
   - **Core** (`core.py`): Main bot orchestrator with handler registration, middleware pipeline, graceful shutdown
   - **Handlers** (`handlers/`): Command handlers, message handlers, callback query handlers
   - **Middleware** (`middleware/`): Authentication, rate limiting, security validation (executed in priority order: security → auth → rate limit)
   - **Features** (`features/`): Modular feature system (file uploads, git integration, quick actions, session export, image handling)
   - **Utils** (`utils/`): Response formatting utilities

3. **Claude Integration** (`src/claude/`)
   - **Dual Mode Integration**: Supports both Python SDK (`sdk_integration.py`) and CLI subprocess (`integration.py`) modes
   - **Facade Pattern** (`facade.py`): High-level API abstracting implementation details
   - **Session Management** (`session.py`): Session state persistence with SQLite backend
   - **Tool Monitoring** (`monitor.py`): Security validation for Claude tool usage
   - **Parser** (`parser.py`): Response parsing and formatting

4. **Storage Layer** (`src/storage/`)
   - Repository pattern with type-safe data access
   - SQLite with migrations and foreign key relationships
   - Session persistence replacing in-memory storage
   - Facade interface for clean separation

5. **Security Layer** (`src/security/`)
   - Multi-provider authentication (whitelist + token-based)
   - Rate limiting with token bucket algorithm
   - Input validation and path traversal prevention
   - Comprehensive audit logging

### Application Bootstrap (`src/main.py`)

The application follows this initialization sequence:
1. Load configuration with environment detection
2. Initialize storage system (SQLite)
3. Create security components (auth, validator, rate limiter, audit logger)
4. Create Claude integration components (session manager, tool monitor, SDK/CLI manager)
5. Construct dependency injection dict
6. Create bot with dependencies
7. Run with signal handling for graceful shutdown

### Dependency Injection Pattern

Handlers receive dependencies through `context.bot_data`:
- `auth_manager`: Authentication check
- `security_validator`: Input/path validation
- `rate_limiter`: Rate limit enforcement
- `audit_logger`: Security event logging
- `claude_integration`: Claude AI interface
- `storage`: Database access (Storage facade)
- `settings`: Application configuration
- `features`: Feature registry (access to file_handler, git, quick_actions, etc.)

### Feature Registry Pattern

The `FeatureRegistry` (`src/bot/features/registry.py`) provides centralized feature management:
- Features are initialized based on configuration flags
- Conditional features: file_uploads, git_integration, quick_actions
- Always-enabled features: session_export, image_handler, conversation
- Access features via `context.bot_data["features"].get_feature("name")`

### Middleware Pipeline

Middleware executes in priority order (groups -3, -2, -1):
1. **Security Middleware** (group=-3): Validates all inputs, sanitizes paths
2. **Auth Middleware** (group=-2): Checks user permissions
3. **Rate Limit Middleware** (group=-1): Enforces request limits

After middleware passes, handlers execute (group=10).

## Configuration Management

### Environment Variables

Required settings in `.env`:
```bash
TELEGRAM_BOT_TOKEN=your_token        # From @BotFather
TELEGRAM_BOT_USERNAME=your_bot
APPROVED_DIRECTORY=/path/to/projects # Security boundary
ALLOWED_USERS=123456789              # Telegram user IDs
```

Claude authentication (choose one method):
- **SDK Mode** (recommended): `USE_SDK=true` + optional `ANTHROPIC_API_KEY`
- **CLI Mode**: `USE_SDK=false` (requires installed Claude CLI)

### Feature Flags

Enable/disable features via environment variables:
- `ENABLE_GIT_INTEGRATION=true` - Git operations
- `ENABLE_FILE_UPLOADS=true` - File and archive uploads
- `ENABLE_QUICK_ACTIONS=true` - Context-aware action buttons
- `ENABLE_SESSION_EXPORT=true` - Export sessions (Markdown/HTML/JSON)
- `ENABLE_IMAGE_UPLOADS=true` - Image/screenshot analysis
- `ENABLE_CONVERSATION_MODE=true` - Follow-up suggestions

## Important Implementation Notes

### Security Model
- **Directory Isolation**: All file operations confined to `APPROVED_DIRECTORY` tree
- **Path Validation**: `SecurityValidator` prevents path traversal attacks
- **Tool Restrictions**: `ToolMonitor` validates Claude tool usage against `CLAUDE_ALLOWED_TOOLS`
- **Audit Trail**: All security events logged via `AuditLogger`

### Claude Integration Architecture
The bot supports two Claude integration modes:
- **SDK Mode** (`use_sdk=true`): Uses Anthropic Python SDK directly (faster, more reliable)
- **CLI Mode** (`use_sdk=false`): Spawns Claude CLI as subprocess (legacy)

Mode selection happens in `main.py:create_application()` based on `config.use_sdk`.

### Async Patterns
- All handlers are `async` functions
- Database operations use `aiosqlite`
- Claude SDK calls are async
- Use `asyncio.create_task()` for concurrent operations

### Error Handling
- Custom exception hierarchy in `src/exceptions.py`
- Global error handler in `ClaudeCodeBot._error_handler()`
- User-friendly error messages mapped by exception type
- Security errors logged to audit system

### Testing Strategy
- Unit tests mirror `src/` structure in `tests/unit/`
- Use `create_test_config()` from `src.config.loader` for test configuration
- Async tests marked with `@pytest.mark.asyncio`
- Fixtures in `tests/conftest.py` for shared test data
- Target coverage: >85% (currently ~87%)

### Test Configuration Helper
The `create_test_config()` function in `src/config/loader.py` creates a Settings instance pre-configured for testing:
- Automatically creates test directory at `/tmp/test_projects`
- Accepts optional overrides via `**kwargs`
- Returns a fully validated Settings instance

## File Organization Patterns

### Adding New Bot Commands
1. Create handler function in `src/bot/handlers/command.py`
2. Register in `ClaudeCodeBot._register_handlers()`
3. Add to `ClaudeCodeBot._set_bot_commands()` for menu
4. Write tests in `tests/unit/test_bot/`

### Adding New Features
1. Create feature module in `src/bot/features/`
2. Implement class with `__init__(self, config, ...)` pattern
3. Register in `FeatureRegistry._initialize_features()` (`src/bot/features/registry.py`)
4. Add feature flag to Settings (`src/config/settings.py`) if conditional
5. Add getter method to `FeatureRegistry` if needed
6. Add tests in `tests/unit/`

### Database Schema Changes
1. Update models in `src/storage/models.py`
2. Create migration in `src/storage/database.py`
3. Update repository methods in `src/storage/repositories.py`
4. Add tests for new queries

## Development Workflow Notes

- **Pre-commit Hooks**: Configured for Black, isort, flake8 (run `make dev` to install)
- **Type Checking**: Strict mypy settings enabled - all code must have type hints
- **Logging**: Use `structlog.get_logger(__name__)` for structured logging
- **Code Style**: Black 88-char line length, isort for imports
- **Commit Format**: Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, etc.)

## Python Version Support

This project requires **Python 3.10 or higher** (as specified in pyproject.toml). The minimum version is enforced by Poetry's dependency configuration.
