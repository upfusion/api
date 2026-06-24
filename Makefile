.PHONY: help local local-down run down restart reload logs shell health check-config status clean test

# Variables
COMPOSE := docker compose
CONTAINER := upfusion-api
NETWORK := www-network

# Default target
help:
	@echo "Upfusion Audio API - Available Commands"
	@echo ""
	@echo "Local Development:"
	@echo "  make local         Start locally (port 8080)"
	@echo "  make local-down    Stop local instance"
	@echo ""
	@echo "Production:"
	@echo "  make run           Start on server (requires www-network)"
	@echo "  make down          Stop server instance"
	@echo "  make restart       Restart container"
	@echo "  make reload        Reload nginx config (no downtime)"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs          Follow container logs"
	@echo "  make shell         Open shell in container"
	@echo "  make health        Check health endpoint"
	@echo "  make status        Show container status"
	@echo "  make check-config  Validate nginx config"
	@echo ""
	@echo "Testing:"
	@echo "  make test          Run all endpoint tests"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean         Stop and remove containers"

# ── Local Development ──

local:
	@echo "Starting locally on port 8080..."
	$(COMPOSE) -f docker-compose.yml -f docker-compose.local.yml up -d
	@echo "✓ Running at http://localhost:8080"
	@echo "  Health: http://localhost:8080/health"
	@echo "  Stream: http://localhost:8080/stream/deftones/eros/destiny"

local-down:
	@echo "Stopping local instance..."
	$(COMPOSE) -f docker-compose.yml -f docker-compose.local.yml down
	@echo "✓ Stopped"

# ── Production ──

run:
	@echo "Starting on server..."
	$(COMPOSE) up -d
	@echo "✓ Running on www-network"
	@echo "  Health: make health"

down:
	@echo "Stopping..."
	$(COMPOSE) down
	@echo "✓ Stopped"

restart:
	@echo "Restarting..."
	docker restart $(CONTAINER)
	@echo "✓ Restarted"

reload: check-config
	@echo "Reloading nginx config..."
	docker exec $(CONTAINER) nginx -s reload
	@echo "✓ Reloaded"

# ── Monitoring ──

check-config:
	@echo "Validating nginx config..."
	@docker exec $(CONTAINER) nginx -t
	@echo "✓ Config valid"

logs:
	docker logs -f $(CONTAINER)

shell:
	docker exec -it $(CONTAINER) /bin/sh

health:
	@curl -sf http://localhost:8080/health && echo " ✓ healthy" || echo "✗ not responding"

status:
	@docker ps --filter name=$(CONTAINER) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# ── Testing ──

test:
	@echo "── Health ──"
	@curl -sf http://localhost:8080/health && echo " ✓" || echo " ✗"
	@echo ""
	@echo "── Stream with valid referer ──"
	@curl -sI http://localhost:8080/stream/deftones/eros/destiny -H "Referer: https://upfusion.net/" | head -1
	@echo ""
	@echo "── Stream without referer (expect 403) ──"
	@curl -sI http://localhost:8080/stream/deftones/eros/destiny | head -1
	@echo ""
	@echo "── Stream with wrong referer (expect 403) ──"
	@curl -sI http://localhost:8080/stream/deftones/eros/destiny -H "Referer: https://evil.com/" | head -1
	@echo ""
	@echo "── Unknown track (expect 404) ──"
	@curl -sI http://localhost:8080/stream/deftones/eros/fakesong -H "Referer: https://upfusion.net/" | head -1
	@echo ""
	@echo "── All tracks ──"
	@for track in destiny brenda melanie smile margot candy sable electra trempest diamond briana; do \
		STATUS=$$(curl -so /dev/null -w "%{http_code}" http://localhost:8080/stream/deftones/eros/$$track -H "Referer: https://upfusion.net/"); \
		if [ "$$STATUS" = "200" ]; then echo "  ✓ $$track"; else echo "  ✗ $$track ($$STATUS)"; fi; \
	done

# ── Cleanup ──

clean:
	@echo "Cleaning up..."
	$(COMPOSE) -f docker-compose.yml -f docker-compose.local.yml down --remove-orphans 2>/dev/null; true
	$(COMPOSE) down --remove-orphans 2>/dev/null; true
	@echo "✓ Cleaned"
