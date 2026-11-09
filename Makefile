# Piksel Platform Makefile
# A set of commands to manage ODC development and deployment

# =========================
# Settings
# =========================
COMPOSE_FILE := docker-compose.yml
PROJECT_NAME := piksel
ENVIRONMENT ?= default
EPSG ?= 4326

# Common Docker Compose command with environment variables
DOCKER_COMPOSE = docker compose --env-file .env -f $(COMPOSE_FILE) -p $(PROJECT_NAME)

# Colors for pretty output
BLUE=\033[34;1m
GREEN=\033[32m
RED=\033[31m
YELLOW=\033[33m
NC=\033[0m # No Color

# =========================
# Auto-help
# =========================
.PHONY: help
help: ## Show this help
	@echo ""
	@echo "$(BLUE)Make Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##";} \
	     /^[a-zA-Z0-9_.-]+:.*##/ { printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 

# =========================
# Docker image build commands
# =========================
.PHONY: build-odc build-jupyter build-jupyter-dev build-all
build-odc: ## Build base services (Postgis + ODC)
	@echo "$(BLUE)Building odc docker image...$(NC)"
	$(DOCKER_COMPOSE) build odc

build-jupyter: ## Build Jupyter Docker image
	@echo "$(BLUE)Building jupyter docker image...$(NC)"
	$(DOCKER_COMPOSE) build jupyter

build-jupyter-dev: ## Build Jupyter dev Docker image
	@echo "$(BLUE)Building jupyter-dev docker image...$(NC)"
	$(DOCKER_COMPOSE) build jupyter-dev

build-all: build-odc build-jupyter ## Build all Docker images
	@echo "$(GREEN)All Docker images built successfully!$(NC)"

build-all-dev: build-odc build-jupyter-dev ## Build all dev Docker images
	@echo "$(GREEN)All Docker images built successfully!$(NC)"

# =========================
# Environment / configuration
# =========================
.PHONY: setup check-config

setup: ## Create .env and generate datacube.conf
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)Created .env file from template.$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists. Skipping.$(NC)"; \
	fi
	@echo "$(BLUE)Generating datacube.conf from template...$(NC)"
	@chmod +x scripts/generate_config.sh
	@export $$(grep -v '^#' .env | xargs) && ./scripts/generate_config.sh
	@echo "$(GREEN)Configuration generated successfully!$(NC)"


check-config: ## Check datacube configuration (runs inside ODC container)
	@echo "$(BLUE)Checking datacube configuration...$(NC)"
	$(DOCKER_COMPOSE) exec odc datacube system check

# =========================
# Service lifecycle
# =========================
.PHONY: up up-all up-jupyter up-jupyter-dev up-explorer stop down rmvol restart ps logs clean
up: ## Start base services
	@echo "$(BLUE)Starting Piksel Base services...$(NC)"
	@export $$(grep -v '^#' .env | xargs) && \
	$(DOCKER_COMPOSE) up -d && \
	echo "$(BLUE)ODC and PostgreSQL Services Started$(NC)" && \
	echo "To Start With Jupyter Notebook: $(BLUE)make up-jupyter$(NC)" && \
	echo "To Start With Datacube Explorer: $(BLUE)make up-explorer$(NC)"

up-jupyter: ## Start services with Jupyter profile
	@echo "$(BLUE)Starting Piksel Base services...$(NC)"
	@export $$(grep -v '^#' .env | xargs) && \
	COMPOSE_PROFILES=jupyter $(DOCKER_COMPOSE) up -d && \
	echo "$(GREEN)Services started. Jupyter is available at http://localhost:$$JUPYTER_PORT$(NC)"

up-jupyter-dev: ## Start services with Jupyter dev profile
	@echo "$(BLUE)Starting With Jupyter Development Container...$(NC)"
	@export $$(grep -v '^#' .env | xargs) && \
	COMPOSE_PROFILES=jupyter-dev $(DOCKER_COMPOSE) up -d && \
	echo "$(GREEN)Services started. Jupyter is available at http://localhost:$$JUPYTER_PORT$(NC)"

up-explorer: setup ## Start services with Explorer profile
	@echo "$(BLUE)Starting Piksel Base services...$(NC)"
	@export $$(grep -v '^#' .env | xargs) && \
	COMPOSE_PROFILES=explorer $(DOCKER_COMPOSE) up -d && \
	echo "$(GREEN)Services started. Datacube Explorer is available at http://localhost:$$EXPLORER_PORT$(NC)"

up-all: ## Start services with Jupyter + Explorer profiles
	@echo "$(BLUE)Starting Piksel Base services...$(NC)"
	@export $$(grep -v '^#' .env | xargs) && \
	COMPOSE_PROFILES=jupyter,explorer $(DOCKER_COMPOSE) up -d && \
	echo "$(GREEN)Services started. Jupyter is available at http://localhost:$$JUPYTER_PORT$(NC)" && \
	echo "$(GREEN)Services started. Datacube Explorer is available at http://localhost:$$EXPLORER_PORT$(NC)"

stop: ## Stop project containers (without removing)
	@echo "$(BLUE)Stopping Piksel services...$(NC)"
	$(DOCKER_COMPOSE) stop

down: ## Stop and remove containers (preserve volumes)
	@echo "$(BLUE)Stopping and removing Piksel containers (preserving volumes)...$(NC)"
	COMPOSE_PROFILES=jupyter,jupyter-dev,explorer $(DOCKER_COMPOSE) down

rmvol: ## Stop and remove containers + volumes (destructive)
	@echo "$(BLUE)Stopping and removing Piksel containers and volumes...$(NC)"
	COMPOSE_PROFILES=jupyter,jupyter-dev,explorer $(DOCKER_COMPOSE) down -v

restart: ## Restart all services
	@echo "$(BLUE)Restarting Piksel services...$(NC)"
	$(DOCKER_COMPOSE) restart

ps: ## Show service status
	@echo "$(BLUE)Piksel service status:$(NC)"
	$(DOCKER_COMPOSE) ps

logs: ## Tail logs from all services
	@echo "$(BLUE)Viewing Piksel logs (press Ctrl+C to exit)...$(NC)"
	$(DOCKER_COMPOSE) logs -f

clean: ## Prune unused Docker resources (prompts; affects whole Docker host)
	@echo $(YELLOW)"WARNING: This will prune ALL unused Docker resources."$(NC)
	@echo "Do you want to proceed? (y/n)"; \
	read ans; \
	if [ "$$ans" = "y" ]; then \
		docker system prune -a -f; \
	else \
		echo "Aborted clean."; \
	fi

# =========================
# Explorer initialization
# =========================
.PHONY: cubedash-init
cubedash-init: ## Initialize Datacube Explorer (Cubedash)
	@echo "$(BLUE)Initializing Datacube Explorer...$(NC)"
	$(DOCKER_COMPOSE) exec datacube-explorer cubedash-gen --init --all

# =========================
# Database / Datacube system
# =========================
.PHONY: init-db reset-db spindex-create spindex-update backup-db psql update-metadata

init-db: ## Initialize ODC database: ensure PostGIS, datacube init, and check
	@echo "$(BLUE)Initializing ODC database for environment '$(ENVIRONMENT)'...$(NC)"
	@echo "$(BLUE)1. Checking PostgreSQL connection...$(NC)"
	@$(DOCKER_COMPOSE) exec postgres psql -U piksel_user -d piksel_db -c "SELECT version();" || { echo "$(RED)Failed to connect to PostgreSQL$(NC)"; exit 1; }
	@echo "$(BLUE)2. Creating PostGIS extension...$(NC)"
	@$(DOCKER_COMPOSE) exec postgres psql -U piksel_user -d piksel_db -c "CREATE EXTENSION IF NOT EXISTS postgis;"
	@echo "$(BLUE)3. Initializing ODC system...$(NC)"
	@$(DOCKER_COMPOSE) exec odc bash -c "datacube -v system init"
	@echo "$(BLUE)4. Verifying ODC system...$(NC)"
	@$(DOCKER_COMPOSE) exec odc bash -c "datacube -v system check"
	@echo "$(BLUE)5. Listing available products (if any)...$(NC)"
	@$(DOCKER_COMPOSE) exec odc bash -c "datacube product list" || echo "$(YELLOW)No products available yet. This is normal for a fresh installation.$(NC)"
	@echo "$(GREEN)ODC database initialization successful!$(NC)"

reset-db: ## Reset ODC database (drops public schema; destructive)
	@echo "$(RED)WARNING: This will destroy all data in the ODC database for environment '$(ENVIRONMENT)'!$(NC)"
	@read -p "Are you sure you want to proceed? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Dropping public schema in PostgreSQL...$(NC)"; \
		$(DOCKER_COMPOSE) exec postgres psql -U piksel_user piksel_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"; \
		echo "$(BLUE)Reinitializing ODC database for environment '$(ENVIRONMENT)'...$(NC)"; \
		$(DOCKER_COMPOSE) exec odc datacube -E $(ENVIRONMENT) system init && \
		$(DOCKER_COMPOSE) exec odc datacube -E $(ENVIRONMENT) spindex create 9468 && \
		$(DOCKER_COMPOSE) exec odc datacube -E $(ENVIRONMENT) spindex update 9468; \
	else \
		echo "$(BLUE)Database reset cancelled$(NC)"; \
	fi

spindex-create: ## Create spatial index (EPSG=$(EPSG))
	@echo "$(BLUE)Adding spatial index for EPSG:$(EPSG)...$(NC)"
	$(DOCKER_COMPOSE) exec odc datacube spindex create $(EPSG)

spindex-update: ## Update spatial index (EPSG=$(EPSG))
	@echo "$(BLUE)Updating spatial index for EPSG:$(EPSG)...$(NC)"
	$(DOCKER_COMPOSE) exec odc datacube spindex update $(EPSG)

backup-db: ## Backup the database to ./backups (gzip)
	@echo "$(BLUE)Backing up ODC database...$(NC)"
	@mkdir -p ./backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	$(DOCKER_COMPOSE) exec -T postgres pg_dump -U piksel_user piksel_db | gzip > ./backups/piksel_db_$$timestamp.sql.gz; \
	@echo "$(GREEN)Database backup created in ./backups$(NC)"

psql: ## Open an interactive PostgreSQL shell
	@echo "$(BLUE)Connecting to PostgreSQL database...$(NC)"
	$(DOCKER_COMPOSE) exec postgres psql -U piksel_user -d piksel_db

update-metadata: ## Add or update metadata definition
	@echo "$(BLUE)Adding or updating metadata definition...$(NC)"
	@$(DOCKER_COMPOSE) exec odc bash -c "datacube metadata update --allow-unsafe /home/venv/metadata/custom_metadata.odc-type.yaml"
	@echo "$(GREEN)Metadata add/update complete!$(NC)"

# =========================
# Product commands
# =========================
.PHONY: check list-products all-products add-product rm-product
check: ## Run 'datacube system check' inside ODC container
	@echo "$(BLUE)Checking system...$(NC)"
	$(DOCKER_COMPOSE) exec odc datacube system check

list-products: ## List all registered ODC products
	@echo "${BLUE}Listing ODC products:${NC}"
	$(DOCKER_COMPOSE) exec odc datacube product list

all-products: ## Add all product YAMLs from ./products/*.yaml
	@echo "${BLUE}Adding all product definitions...${NC}"
	@for product in products/*.yaml; do \
		echo "${YELLOW}Adding product: $$product${NC}"; \
		$(DOCKER_COMPOSE) exec -T odc bash -c "datacube product add /home/venv/products/$$(basename $$product)" || echo "${RED}Failed to add product: $$product${NC}"; \
	done

add-product: ## Add a specific product definition (usage: make add-product F=<product.yaml>)
	@if [ -z "$(F)" ]; then \
		echo "${RED}Error: Missing product file. Usage: make add-product F=<product.yaml>${NC}"; \
		exit 1; \
	fi
	@echo "${BLUE}Adding product definition: $(F)${NC}"
	$(DOCKER_COMPOSE) exec -T odc bash -c "datacube product add /home/venv/products/$(F)"

rm-product: ## Remove a product by name (usage: make rm-product P=<product_name>)
	@if [ -z "$(P)" ]; then \
		echo "${RED}Error: Missing product name. Usage: make rm-product P=<product_name>${NC}"; \
		exit 1; \
	fi
	@echo "${YELLOW}Deleting product: $(P)${NC}"
	$(DOCKER_COMPOSE) exec -T odc bash -c "echo 'y' | datacube product delete --force $(P)"

# =========================
# Indexing commands
# =========================
LANDSATLOOK ?= https://landsatlook.usgs.gov/stac-server/

Bbox ?= 105,-8,106,-5
Date ?= 2024-01-01/2024-05-31
CollectionS2 ?= sentinel-2-l2a

DateLsOld ?= 2000-01-01/2000-07-31
CollectionLsSR ?= landsat-c2l2-sr
CollectionLsST ?= landsat-c2l2-st

LIMIT ?= 9999

.PHONY: index-sentinel2 index-s1-rtc index-ls9-st index-ls8-st index-ls7-st index-ls5-st \
	index-ls9-sr index-ls8-sr index-ls7-sr index-ls5-sr index-all index-landsat index-landsat-sr index-landsat-st index-gm index-s2-gm-annual index-s2-gm-annual-lowres index-flood-hazard

index-all: index-sentinel2 index-landsat index-s1-rtc index-gm ## Index Sentinel-2 + Landsat + Sentinel-1 + S2 GeoMAD
	@echo "$(GREEN)All products indexed successfully!$(NC)"

index-landsat-sr: index-ls9-sr index-ls8-sr index-ls7-sr index-ls5-sr ## Index Landsat surface reflectance (SR)

index-landsat-st: index-ls9-st index-ls8-st index-ls7-st index-ls5-st ## Index Landsat surface temperature (ST)

index-landsat: index-landsat-sr index-landsat-st ## Index all Landsat SR + ST

index-gm: index-s2-gm-annual index-s2-geomad-annual-lowres ## Index Sentinel-2 Geomedian (14-band) + S2 GeoMAD Low Resolution Mosaic (RGB)

index-sentinel2: ## Index Sentinel-2 L2A via STAC (params: Bbox, Date, CollectionS2)
	@echo "$(BLUE)Indexing Sentinel-2 L2A data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='https://earth-search.aws.element84.com/v1/' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionS2)' \
	            --datetime='$(Date)' \
	            --rename-product='s2_l2a'

index-ls9-st: ## Index Landsat-9 Surface Temperature via STAC
	@echo "$(BLUE)Indexing LS9 C2L2 ST data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsST)' \
	            --datetime='$(Date)' \
	            --rename-product='ls9_c2l2_st' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_9\"]}}" \

index-ls8-st: ## Index Landsat-8 Surface Temperature via STAC
	@echo "$(BLUE)Indexing LS8 C2L2 ST data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsST)' \
	            --datetime='$(Date)' \
	            --rename-product='ls8_c2l2_st' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_8\"]}}" \

index-ls7-st: ## Index Landsat-7 Surface Temperature via STAC
	@echo "$(BLUE)Indexing LS7 C2L2 ST data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsST)' \
	            --datetime='$(DateLsOld)' \
	            --rename-product='ls7_c2l2_st' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_7\"]}}" \

index-ls5-st: ## Index Landsat-5 Surface Temperature via STAC
	@echo "$(BLUE)Indexing LS5 C2L2 ST data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsST)' \
	            --datetime='$(DateLsOld)' \
	            --rename-product='ls5_c2l2_st' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_5\"]}}" \

index-ls9-sr: ## Index Landsat-9 Surface Reflectance via STAC
	@echo "$(BLUE)Indexing LS9 C2L2 SR data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsSR)' \
	            --datetime='$(Date)' \
	            --rename-product='ls9_c2l2_sr' \
	            --url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_9\"]}}" \

index-ls8-sr: ## Index Landsat-8 Surface Reflectance via STAC
	@echo "$(BLUE)Indexing LS8 C2L2 SR data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsSR)' \
	            --datetime='$(Date)' \
				--rename-product='ls8_c2l2_sr' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_8\"]}}" \

index-ls7-sr: ## Index Landsat-7 Surface Reflectance via STAC
	@echo "$(BLUE)Indexing LS7 C2L2 SR data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsSR)' \
	            --datetime='$(DateLsOld)' \
	            --rename-product='ls7_c2l2_sr' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_7\"]}}" \

index-ls5-sr: ## Index Landsat-5 Surface Reflectance via STAC
	@echo "$(BLUE)Indexing LS5 C2L2 SR data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='${LANDSATLOOK}' \
	            --bbox='$(Bbox)' \
	            --collections='$(CollectionLsSR)' \
	            --datetime='$(DateLsOld)' \
	            --rename-product='ls5_c2l2_sr' \
				--url-string-replace='https://landsatlook.usgs.gov/data,s3://usgs-landsat' \
	            --limit=$(LIMIT) \
	            --options="query={\"platform\":{\"in\":[\"LANDSAT_5\"]}}" \

index-s1-rtc: ## Index Sentinel-1 RTC via STAC
	@echo "$(BLUE)Indexing Sentinel-1 RTC data...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  stac-to-dc --catalog-href='https://planetarycomputer.microsoft.com/api/stac/v1/' \
	            --bbox='$(Bbox)' \
	            --collections='sentinel-1-rtc' \
	            --datetime='$(Date)' \
	            --rename-product='s1_rtc' \
	            --limit=$(LIMIT)

index-s2-gm-annual: ## Index Sentinel-2 Annual Geomedian (14-band) from S3
	@echo "$(BLUE)Indexing Sentinel-2 Annual Geomedian (14-band)...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  bash -c "AWS_DEFAULT_REGION=ap-southeast-3 s3-to-dc --stac \
	           --no-sign-request \
	           --rename-product='s2_geomad_annual' \
	           's3://piksel-staging-public-data/geomad_s2/1.0.0/**/*.stac-item.json' \
	           's2_geomad_annual'"

index-s2-geomad-annual-lowres: ## Index Sentinel-2 Annual Geomedian - Low Resolution Mosaic (RGB) from S3
	@echo "$(BLUE)Indexing Sentinel-2 Annual Geomedian - Low Resolution Mosaic (RGB)...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  bash -c "AWS_DEFAULT_REGION=ap-southeast-3 s3-to-dc --stac \
	           --no-sign-request \
	           --rename-product='s2_geomad_annual_120' \
	           's3://piksel-staging-public-data/s2_geomad_annual_120/1.0.0/**/*.stac-item.json' \
	           's2_geomad_annual_120'"

index-flood-hazard: ## Index Flood Hazard (Bahaya Banjir 2025) from S3
	@echo "$(BLUE)Indexing Flood Hazard (Bahaya Banjir 2025)...$(NC)"
	$(DOCKER_COMPOSE) exec odc \
	  bash -c "AWS_DEFAULT_REGION=ap-southeast-3 s3-to-dc --stac \
	           --no-sign-request \
	           --rename-product='flood_hazard' \
	           's3://piksel-staging-public-data/flood_hazard/1.0.0/**/*.stac-item.json' \
	           'flood_hazard'"
# =========================
# Utility commands
# =========================
.PHONY: bash-odc bash-jupyter jupyter-token
bash-odc: ## Open a shell in the ODC container
	@echo "${BLUE}Opening shell in ODC container...${NC}"
	$(DOCKER_COMPOSE) exec odc bash

bash-jupyter: ## Open a shell in the Jupyter container
	@echo "${BLUE}Opening shell in Jupyter container...${NC}"
	$(DOCKER_COMPOSE) exec jupyter bash

jupyter-token: ## Print Jupyter token URL (if token auth enabled)
	@echo "${BLUE}Getting Jupyter token...${NC}"
	@token=$$($(DOCKER_COMPOSE) exec -T jupyter jupyter server list | grep -oP "token=\K[^[:space:]]*" || echo "No token found"); \
	if [ "$$token" != "No token found" ]; then \
		echo "${GREEN}Jupyter URL: http://localhost:8888/?token=$$token${NC}"; \
	else \
		echo "${YELLOW}No token found. Authentication may be disabled.${NC}"; \
		echo "${GREEN}Jupyter URL: http://localhost:8888/${NC}"; \
	fi

# =========================
# Dependency management (uv)
# =========================
.PHONY: compile-deps update-deps
compile-deps: ## Compile ODC dependency lockfile (pyproject.toml -> uv.lock)
	@echo "$(BLUE)Compiling ODC dependencies using uv...$(NC)"
	@command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
	@uv lock --python 3.12
	@echo "$(GREEN)ODC dependencies compiled!$(NC)"

update-deps: ## Update ODC dependencies to latest versions (uv --upgrade)
	@echo "$(BLUE)Updating ODC dependencies to their latest versions using uv...$(NC)"
	@command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
	@uv lock --python 3.12 --upgrade
	@echo "$(GREEN)Dependencies updated successfully!$(NC)"

# =========================
# Testing
# =========================
TEST_VENV_DIR := .venv
PYTEST_ARGS ?= -v

.PHONY: test test-venv test-deps test-unit test-verbose test-clean

test-venv: ## Create a Python virtual environment for tests (.venv)
	@echo "$(BLUE)Creating Python virtual environment for testing...$(NC)"
	python3 -m venv $(TEST_VENV_DIR)
	@echo "$(GREEN)Virtual environment created at $(TEST_VENV_DIR)$(NC)"
	@echo "$(YELLOW)Activate with: source $(TEST_VENV_DIR)/bin/activate$(NC)"

test-deps: test-venv ## Install test dependencies into .venv
	@echo "$(BLUE)Installing test dependencies...$(NC)"
	$(TEST_VENV_DIR)/bin/pip install --upgrade pip
	$(TEST_VENV_DIR)/bin/pip install pytest pytest-cov python-dotenv pyyaml
	@echo "$(GREEN)Test dependencies installed$(NC)"

test-unit: ## Run unit tests (host .venv)
	@echo "$(BLUE)Running unit tests...$(NC)"
	@if [ ! -d "$(TEST_VENV_DIR)" ]; then \
		echo "$(RED)Virtual environment not found. Run 'make test-deps' first.$(NC)"; \
		exit 1; \
	fi
	$(TEST_VENV_DIR)/bin/pytest $(PYTEST_ARGS) tests/unit

test: test-unit ## Run the test suite (unit tests)

test-verbose: PYTEST_ARGS=-xvs
test-verbose: test-unit ## Run tests with verbose pytest output
	@echo "$(GREEN)Test complete$(NC)"

test-clean: ## Remove pytest caches, coverage, and .venv
	@echo "$(BLUE)Cleaning up test artifacts...$(NC)"
	@rm -rf .pytest_cache
	@find . -name "__pycache__" -type d -exec rm -rf {} +  2>/dev/null || true
	@rm -f .coverage
	@rm -rf htmlcov
	@rm -rf $(TEST_VENV_DIR)
	@echo "$(GREEN)Test artifacts cleaned$(NC)"
