.DEFAULT_GOAL := all
.NOTPARALLEL:
COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

.PHONY: all setup build up down stop start restart logs ps credentials clean fclean re config test

all: up

setup:
	@bash srcs/requirements/tools/setup.sh

build: setup
	@docker info >/dev/null
	$(COMPOSE) config --quiet
	$(COMPOSE) build --pull

up: build
	$(COMPOSE) up -d --wait --wait-timeout 180

down clean:
	$(COMPOSE) down --remove-orphans

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start --wait --wait-timeout 180

restart:
	$(COMPOSE) restart
	$(COMPOSE) up -d --wait --wait-timeout 180

logs:
	$(COMPOSE) logs --tail=100 -f

ps:
	$(COMPOSE) ps -a

credentials: setup
	@bash srcs/requirements/tools/credentials.sh

config: setup
	$(COMPOSE) config --quiet

re: setup
	$(COMPOSE) down --remove-orphans
	$(COMPOSE) build --pull --no-cache
	$(COMPOSE) up -d --wait --wait-timeout 180

# Explicit opt-in: destroys this stack's database, uploads, configuration, and secrets.
fclean:
	@test "$(CONFIRM)" = DELETE || { echo 'Destructive: run make fclean CONFIRM=DELETE to erase this stack.'; exit 1; }
	@bash srcs/requirements/tools/purge.sh

# Runs a disposable fresh-checkout integration suite; leaves the normal stack alone.
test:
	python3 srcs/requirements/tools/verify.py
