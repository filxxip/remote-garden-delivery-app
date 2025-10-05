SERVICES = admin agent api mqtt_broker csr_signer mock_mqtt gh_proxy

SERVICE ?= all

.PHONY: run
run:
ifeq ($(SERVICE), all)
	@echo ">>> Starting all services with rebuild (no cache)"
	docker compose build --no-cache && docker compose up --force-recreate
else
	@echo ">>> Starting $(SERVICE) service with rebuild (no cache)"
	cd $(SERVICE) && docker compose build --no-cache && docker compose up --force-recreate
endif

.PHONY: run-detached
run-detached:
ifeq ($(SERVICE), all)
	@echo ">>> Starting all services in background with rebuild"
	docker compose up -d --build --force-recreate
else
	@echo ">>> Starting $(SERVICE) service in background with rebuild"
	cd $(SERVICE) && docker compose up -d --build --force-recreate
endif

.PHONY: up
up:
ifeq ($(SERVICE), all)
	@echo ">>> Starting all services"
	docker compose up
else
	@echo ">>> Starting $(SERVICE) service"
	cd $(SERVICE) && docker compose up
endif

.PHONY: up-detached
up-detached:
ifeq ($(SERVICE), all)
	@echo ">>> Starting all services in background"
	docker compose up -d
else
	@echo ">>> Starting $(SERVICE) service in background"
	cd $(SERVICE) && docker compose up -d
endif

.PHONY: stop
stop:
ifeq ($(SERVICE), all)
	@echo ">>> Stopping all services"
	docker compose down
else
	@echo ">>> Stopping $(SERVICE) service"
	cd $(SERVICE) && docker compose down
endif

.PHONY: stop-clean
stop-clean:
ifeq ($(SERVICE), all)
	@echo ">>> Stopping all services and removing volumes"
	docker compose down -v
else
	@echo ">>> Stopping $(SERVICE) service and removing volumes"
	cd $(SERVICE) && docker compose down -v
endif

.PHONY: logs
logs:
ifeq ($(SERVICE), all)
	@echo ">>> Showing logs from all services"
	docker compose logs -f
else
	@echo ">>> Showing logs from $(SERVICE) service"
	cd $(SERVICE) && docker compose logs -f
endif

.PHONY: ps
ps:
ifeq ($(SERVICE), all)
	@echo ">>> Listing all running containers"
	docker compose ps
else
	@echo ">>> Listing containers for $(SERVICE) service"
	cd $(SERVICE) && docker compose ps
endif

.PHONY: pull
pull:
ifeq ($(SERVICE), all)
	@echo ">>> Pulling images for all services"
	docker compose pull
else
	@echo ">>> Pulling images for $(SERVICE) service"
	cd $(SERVICE) && docker compose pull
endif

.PHONY: restart
restart: stop run-detached
	@echo ">>> Services restarted"

.PHONY: list
list:
	@echo "Available services:"
	@for s in $(SERVICES); do \
		echo "  - $s"; \
	done

.PHONY: help
help:
	@echo ""
	@echo "Usage: make [target] [SERVICE=name]"
	@echo ""
	@echo "Targets:"
	@echo "  run            Build and start containers (no cache, force recreate)"
	@echo "  run-detached   Build and start containers in background (no cache, force recreate)"
	@echo "  up             Start containers without rebuild"
	@echo "  up-detached    Start containers in background without rebuild"
	@echo "  stop           Stop containers"
	@echo "  stop-clean     Stop containers and remove volumes"
	@echo "  logs           Show and follow container logs"
	@echo "  ps             List running containers"
	@echo "  restart        Stop and restart containers in background"
	@echo "  list           Show available services"
	@echo ""
	@echo "Variables:"
	@echo "  SERVICE        Service to manage (default: all)"
	@echo "                 Available: $(SERVICES)"
	@echo ""
	@echo "Examples:"
	@echo "  make run                    # Start all services with full rebuild"
	@echo "  make run SERVICE=admin      # Start only admin service"
	@echo "  make up-detached SERVICE=api # Start only api service in background"
	@echo "  make logs SERVICE=mqtt_broker # Watch mqtt_broker logs"
	@echo "  make stop SERVICE=agent     # Stop only agent service"
	@echo "  make stop-clean             # Stop all and clean volumes"
	@echo ""

.DEFAULT_GOAL := help