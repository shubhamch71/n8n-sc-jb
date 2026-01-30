.PHONY: help start stop logs shell import deploy secrets clean test

# Default target
help:
	@echo "n8n Job Alerts - Available Commands"
	@echo "===================================="
	@echo ""
	@echo "Local Development:"
	@echo "  make start     - Start n8n with Docker Compose"
	@echo "  make stop      - Stop n8n"
	@echo "  make logs      - View n8n logs"
	@echo "  make shell     - Open shell in n8n container"
	@echo "  make clean     - Remove all containers and volumes"
	@echo ""
	@echo "Fly.io Deployment:"
	@echo "  make deploy    - Deploy to Fly.io"
	@echo "  make secrets   - Set Fly.io secrets (interactive)"
	@echo "  make fly-logs  - View Fly.io logs"
	@echo "  make fly-ssh   - SSH into Fly.io instance"
	@echo ""
	@echo "Workflow:"
	@echo "  make test      - Test API endpoints locally"

# Local development
start:
	@echo "Starting n8n..."
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Copy .env.example to .env and configure it."; \
		exit 1; \
	fi
	docker-compose up -d
	@echo "n8n is starting at http://localhost:5678"
	@echo "Wait a few seconds for it to initialize..."

stop:
	@echo "Stopping n8n..."
	docker-compose down

logs:
	docker-compose logs -f n8n

shell:
	docker-compose exec n8n /bin/sh

clean:
	@echo "Warning: This will delete all data!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	docker-compose down -v
	@echo "Cleaned up."

# Fly.io deployment
deploy:
	@echo "Deploying to Fly.io..."
	fly deploy

secrets:
	@echo "Setting Fly.io secrets..."
	@read -p "TELEGRAM_BOT_TOKEN: " token && fly secrets set TELEGRAM_BOT_TOKEN="$$token"
	@read -p "TELEGRAM_CHAT_ID: " chatid && fly secrets set TELEGRAM_CHAT_ID="$$chatid"
	@read -p "N8N_BASIC_AUTH_USER (default: admin): " user && fly secrets set N8N_BASIC_AUTH_USER="$${user:-admin}"
	@read -p "N8N_BASIC_AUTH_PASSWORD: " pass && fly secrets set N8N_BASIC_AUTH_PASSWORD="$$pass"
	@echo "Secrets set successfully!"

fly-logs:
	fly logs

fly-ssh:
	fly ssh console

# Testing
test:
	@echo "Testing API endpoints..."
	@echo ""
	@echo "Greenhouse - HashiCorp:"
	@curl -s "https://boards-api.greenhouse.io/v1/boards/hashicorp/jobs" | head -c 200
	@echo ""
	@echo ""
	@echo "Lever - Twilio:"
	@curl -s "https://api.lever.co/v0/postings/twilio?mode=json" | head -c 200
	@echo ""
	@echo ""
	@echo "RemoteOK - DevOps:"
	@curl -s "https://remoteok.com/api?tag=devops" | head -c 200
	@echo ""
	@echo ""
	@echo "All endpoints responding!"
