#!/bin/bash
# Claude Code Telegram Bot - Run Script
# This script handles starting and restarting the bot safely

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POETRY="/Users/sternelee/Library/Python/3.9/bin/poetry"
PROJECT_DIR="/Users/sternelee/www/coding-telegram-bot"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$PROJECT_DIR/bot.pid"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if bot is running
is_bot_running() {
    # First check PID file
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "$PID"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi

    # Also check for any running bot processes (Python processes only)
    local BOT_PID=$(ps aux | grep -E "python.*claude-telegram-bot" | grep -v grep | awk '{print $2}' | head -1)
    if [ -n "$BOT_PID" ]; then
        echo "$BOT_PID"
        # Update PID file
        echo "$BOT_PID" > "$PID_FILE"
        return 0
    fi

    return 1
}

# Function to stop the bot
stop_bot() {
    print_info "Stopping bot..."

    # Kill all bot processes
    pkill -9 -f "claude-telegram-bot" 2>/dev/null || true

    # Wait for processes to stop
    sleep 2

    # Verify no processes remain
    REMAINING=$(ps aux | grep -E "claude-telegram-bot" | grep -v grep | wc -l)
    if [ "$REMAINING" -eq 0 ]; then
        print_success "All bot processes stopped"
    else
        print_warning "Some processes may still be running"
        ps aux | grep -E "claude-telegram-bot" | grep -v grep
    fi

    rm -f "$PID_FILE"
}

# Function to start the bot
start_bot() {
    local MODE="${1:-normal}"

    print_info "Starting bot in $MODE mode..."
    cd "$PROJECT_DIR"

    if [ "$MODE" = "debug" ]; then
        # Start in debug mode with output to console and log
        $POETRY run claude-telegram-bot --debug 2>&1 | tee -a "$LOG_DIR/bot-$(date +%Y%m%d).log" &
    else
        # Start in normal mode with output to log only
        $POETRY run claude-telegram-bot >> "$LOG_DIR/bot-$(date +%Y%m%d).log" 2>&1 &
    fi

    local PID=$!
    echo $PID > "$PID_FILE"

    sleep 3

    # Verify bot is running
    if is_bot_running; then
        print_success "Bot started successfully (PID: $PID)"
        print_info "Logs: $LOG_DIR/bot-$(date +%Y%m%d).log"
        print_info "PID file: $PID_FILE"
    else
        print_error "Bot failed to start. Check logs for details."
        exit 1
    fi
}

# Function to restart the bot
restart_bot() {
    local MODE="${1:-normal}"
    print_info "Restarting bot..."
    stop_bot
    start_bot "$MODE"
}

# Function to show bot status
show_status() {
    print_info "Checking bot status..."

    local PID=$(is_bot_running)
    if [ $? -eq 0 ]; then
        print_success "Bot is running (PID: $PID)"

        # Show process details
        ps -p "$PID" -o pid,ppid,%mem,%cpu,etime 2>/dev/null || ps -p "$PID" 2>/dev/null

        # Show recent log entries
        if [ -f "$LOG_DIR/bot-$(date +%Y%m%d).log" ]; then
            print_info "Recent log entries:"
            tail -20 "$LOG_DIR/bot-$(date +%Y%m%d).log"
        fi
    else
        print_warning "Bot is not running"
    fi
}

# Function to show logs
show_logs() {
    local LINES="${1:-50}"

    if [ -f "$LOG_DIR/bot-$(date +%Y%m%d).log" ]; then
        print_info "Showing last $LINES lines of today's log:"
        tail -n "$LINES" "$LOG_DIR/bot-$(date +%Y%m%d).log"
    else
        print_warning "No log file found for today"
    fi
}

# Function to follow logs
follow_logs() {
    if [ -f "$LOG_DIR/bot-$(date +%Y%m%d).log" ]; then
        print_info "Following log output (Ctrl+C to exit)..."
        tail -f "$LOG_DIR/bot-$(date +%Y%m%d).log"
    else
        print_warning "No log file found for today"
    fi
}

# Main command handling
case "${1:-start}" in
    start)
        if is_bot_running; then
            print_warning "Bot is already running. Use 'restart' to restart."
            exit 1
        fi
        start_bot "${2:-normal}"
        ;;

    debug)
        if is_bot_running; then
            print_warning "Bot is already running. Use 'restart' to restart."
            exit 1
        fi
        start_bot "debug"
        ;;

    stop)
        stop_bot
        ;;

    restart)
        restart_bot "${2:-normal}"
        ;;

    restart-debug)
        restart_bot "debug"
        ;;

    status)
        show_status
        ;;

    logs)
        show_logs "${2:-50}"
        ;;

    follow)
        follow_logs
        ;;

    *)
        echo "Claude Code Telegram Bot - Run Script"
        echo ""
        echo "Usage: $0 {start|debug|stop|restart|restart-debug|status|logs|follow}"
        echo ""
        echo "Commands:"
        echo "  start          - Start bot in normal mode (background)"
        echo "  debug          - Start bot in debug mode (with console output)"
        echo "  stop           - Stop all bot processes"
        echo "  restart        - Restart bot in normal mode"
        echo "  restart-debug  - Restart bot in debug mode"
        echo "  status         - Show bot status and recent logs"
        echo "  logs [N]       - Show last N lines of logs (default: 50)"
        echo "  follow         - Follow log output in real-time"
        echo ""
        echo "Examples:"
        echo "  $0 start           # Start bot"
        echo "  $0 debug           # Start in debug mode"
        echo "  $0 restart         # Restart bot"
        echo "  $0 status          # Check status"
        echo "  $0 logs 100        # Show last 100 log lines"
        echo "  $0 follow          # Watch logs in real-time"
        exit 1
        ;;
esac
