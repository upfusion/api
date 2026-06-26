.PHONY: help local local-down run deploy down restart reload build logs shell health check-config status clean test

# Variables
COMPOSE := docker compose
CONTAINER := upfusion-api
NETWORK := www-network

# Default target
help:
	@echo "Upfusion Audio API"
	@echo ""
	@echo "Local:"
	@echo "  make local           Start locally (port 8080)"
	@echo "  make local-down      Stop local instance"
	@echo ""
	@echo "Production:"
	@echo "  make run             Start container"
	@echo "  make deploy          Recreate with fresh config (near-zero downtime)"
	@echo "  make build           Rebuild image from scratch (no cache)"
	@echo "  make down            Stop container"
	@echo "  make restart         Restart container"
	@echo "  make reload          Reload nginx config without restart"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs            Follow container logs"
	@echo "  make shell           Open shell in container"
	@echo "  make health          Check health endpoint"
	@echo "  make status          Show container status"
	@echo "  make check-config    Validate nginx config"
	@echo ""
	@echo "Testing:"
	@echo "  make test            Run all endpoint tests"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean           Stop and remove containers"

# ── Local Development ──

local:
	@echo "Starting locally on port 8080..."
	$(COMPOSE) -f docker-compose.yml -f docker-compose.local.yml up -d
	@echo "✓ Running at http://127.0.0.1:8080"
	@echo "  Health: http://127.0.0.1:8080/health"
	@echo "  Stream: http://127.0.0.1:8080/stream/deftones/eros/destiny"

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

deploy:
	@echo "Deploying (fresh config)..."
	$(COMPOSE) up -d --force-recreate
	@echo "✓ Deployed with fresh config"

build:
	@echo "Building with no cache..."
	$(COMPOSE) build --no-cache
	@echo "✓ Built"

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
	@docker exec $(CONTAINER) wget -qO- http://127.0.0.1:8080/health && echo " ✓ healthy" || echo "✗ not responding"

status:
	@docker ps --filter name=$(CONTAINER) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# ── Testing ──

test:
	@echo "── Health ──"
	@docker exec $(CONTAINER) wget -qO- http://127.0.0.1:8080/health && echo " ✓" || echo " ✗"
	@echo ""
	@echo "── Stream with valid referer ──"
	@docker exec $(CONTAINER) wget -qS --header="Referer: https://upfusion.net/" -O /dev/null http://127.0.0.1:8080/stream/deftones/eros/destiny 2>&1 | head -1
	@echo ""
	@echo "── Stream without referer (expect 403) ──"
	@docker exec $(CONTAINER) wget -qS -O /dev/null http://127.0.0.1:8080/stream/deftones/eros/destiny 2>&1 | head -1
	@echo ""
	@echo "── All tracks ──"
	@for track in destiny brenda melanie smile margot candy sable electra trempest diamond briana; do \
		docker exec $(CONTAINER) wget -qO /dev/null --header="Referer: https://upfusion.net/" http://127.0.0.1:8080/stream/deftones/eros/$$track 2>/dev/null \
		&& echo "  ✓ $$track" || echo "  ✗ $$track"; \
	done

# ── Cleanup ──

clean:
	@echo "Cleaning up..."
	$(COMPOSE) -f docker-compose.yml -f docker-compose.local.yml down --remove-orphans 2>/dev/null; true
	$(COMPOSE) down --remove-orphans 2>/dev/null; true
	@echo "✓ Cleaned"
