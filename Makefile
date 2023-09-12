# Executables (local)
DOCKER_COMP = docker compose

# Docker containers
PHP_CONT   = $(DOCKER_COMP) exec php
NODE_CONT  = $(DOCKER_COMP) exec node
CADDY_CONT = $(DOCKER_COMP) exec caddy
MARIADB_CONT = $(DOCKER_COMP) exec mariadb

# PHP Executables
PHP      = $(PHP_CONT) php
COMPOSER = $(PHP_CONT) composer
SYMFONY  = $(PHP_CONT) bin/console

# Node Executables
YARN  = $(NODE_CONT) yarn
VITE = $(NODE_CONT) vite

# Misc
.DEFAULT_GOAL = help
.PHONY        : help build up start down logs sh composer vendor sf cc

## —— 🎵 🐳 The Symfony Docker Makefile 🐳 🎵 ——————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
build: ## Builds the Docker images
	@$(DOCKER_COMP) build --pull --no-cache

up: ## Start the docker hub in detached mode (no logs)
	@$(DOCKER_COMP) up --detach

start: build up ## Build and start the containers

restart: ## Restart the containers
	@$(DOCKER_COMP) restart

down: ## Stop the docker hub
	@$(DOCKER_COMP) down --remove-orphans

prod: ## Start the docker hub in production mode
	@$(DOCKER_COMP) -f docker-compose.yml -f docker-compose.prod.yml up --detach

logs: ## Show live logs
	@$(DOCKER_COMP) logs --tail=0 --follow

psh: ## Connect to the PHP FPM container
	@$(PHP_CONT) sh

nsh: ## Connect to the node container
	@$(NODE_CONT) sh

csh: ## Connect to the caddy container
	@$(CADDY_CONT) sh

msh: ## Connect to the mariadb container
	@$(MARIADB_CONT) sh

## —— Composer 🧙 ——————————————————————————————————————————————————————————————
composer: ## Run composer, pass the parameter "c=" to run a given command, example: make composer c='req symfony/orm-pack'
	@$(eval c ?=)
	@$(COMPOSER) $(c)

vendor: ## Install vendors according to the current composer.lock file
vendor: c=install --prefer-dist --no-dev --no-progress --no-scripts --no-interaction
vendor: composer

## —— yarn 🧞‍♂️ ——————————————————————————————————————————————————————————————
yarn: ## Run npm, pass the parameter "c=" to run a given command, example: make yarn c=install
	@$(eval c ?=)
	@$(YARN) $(c)

## —— vite 🦸‍♂️ ——————————————————————————————————————————————————————————————
vite: ## Run vite, pass the parameter "c=" to run a given command, example: make vite c=build
	@$(eval c ?=)
	@$(VITE) $(c)

## —— Symfony 🎵 ———————————————————————————————————————————————————————————————
sf: ## List all Symfony commands or pass the parameter "c=" to run a given command, example: make sf c=about
	@$(eval c ?=)
	@$(SYMFONY) $(c)

cc: c=c:c ## Clear the cache
cc: sf
