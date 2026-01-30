#!/bin/bash
# Test script to verify Telegram bot configuration

set -e

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check required variables
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN not set"
    echo "Please set it in .env file or export it"
    exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_CHAT_ID not set"
    echo "Please set it in .env file or export it"
    exit 1
fi

echo "Testing Telegram Bot Configuration"
echo "==================================="
echo ""

# Test 1: Get bot info
echo "1. Getting bot info..."
BOT_INFO=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe")
echo "$BOT_INFO" | python3 -m json.tool 2>/dev/null || echo "$BOT_INFO"
echo ""

# Check if bot token is valid
if echo "$BOT_INFO" | grep -q '"ok":true'; then
    echo "✓ Bot token is valid"
    BOT_NAME=$(echo "$BOT_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['username'])" 2>/dev/null || echo "unknown")
    echo "  Bot username: @$BOT_NAME"
else
    echo "✗ Bot token is invalid"
    exit 1
fi
echo ""

# Test 2: Send test message
echo "2. Sending test message to chat ID: $TELEGRAM_CHAT_ID..."
TEST_MESSAGE="🔔 *Test Message from Job Alerts Workflow*

This is a test message to verify your Telegram bot configuration is working correctly.

If you see this message, your setup is complete!

Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

SEND_RESULT=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"text\": \"${TEST_MESSAGE}\",
        \"parse_mode\": \"Markdown\"
    }")

echo "$SEND_RESULT" | python3 -m json.tool 2>/dev/null || echo "$SEND_RESULT"
echo ""

if echo "$SEND_RESULT" | grep -q '"ok":true'; then
    echo "✓ Test message sent successfully!"
    echo ""
    echo "Your Telegram configuration is working correctly."
    echo "You can now import and activate the n8n workflow."
else
    echo "✗ Failed to send message"
    echo ""
    echo "Common issues:"
    echo "  - Bot not added to the chat/group"
    echo "  - Incorrect chat ID"
    echo "  - Bot doesn't have permission to send messages"
    echo ""
    echo "To fix:"
    echo "  1. Start a chat with your bot on Telegram"
    echo "  2. Send /start to the bot"
    echo "  3. For groups: add the bot to the group"
    exit 1
fi
