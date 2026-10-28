.DEFAULT_GOAL := all
.NOTPARALLEL:

COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml
COLOR ?= auto

# Color only interactive output by default. NO_COLOR always takes precedence.
# Force a palette with COLOR=always, or use COLOR=never for plain output.
define palette
bold=; cyan=; green=; yellow=; red=; dim=; reset=; \
if [ -z "$${NO_COLOR+x}" ] && { [ "$(COLOR)" = always ] || \
    { [ "$(COLOR)" = auto ] && [ -t 1 ] && [ "$${TERM:-dumb}" != dumb ]; }; }; then \
    bold='\033[1m'; cyan='\033[1;36m'; green='\033[1;32m'; \
    yellow='\033[1;33m'; red='\033[1;31m'; dim='\033[2m'; reset='\033[0m'; \
fi;
endef

define status
@$(palette) printf '  %b[%-5s]%b %s\n' "$${$(1)}" '$(2)' "$$reset" '$(3)'
endef

.PHONY: all banner help setup build up down stop start restart logs ps credentials clean fclean re config test

all: up

banner:
	@$(palette) \
	printf '\n%b' "$$cyan"; \
	printf '  +------------------------------------------------------------------+\n'; \
	printf '  |        %-57s |\n' \
	    ' ___ _   _  ____ _____ ____ _____ ___ ___  _   _' \
	    '|_ _| \ | |/ ___| ____|  _ \_   _|_ _/ _ \| \ | |' \
	    ' | ||  \| | |   |  _| | |_) || |  | | | | |  \| |' \
	    ' | || |\  | |___| |___|  __/ | |  | | |_| | |\  |' \
	    '|___|_| \_|\____|_____|_|    |_| |___\___/|_| \_|'; \
	printf '  +------------------------------------------------------------------+\n%b' "$$reset"; \
	printf '  %b%-33s%35s%b\n' "$$bold" 'mhasoneh / 42' 'CONTAINERS. CONNECTED.' "$$reset"; \
	printf '  %bHTTPS :443 -> NGINX -> WORDPRESS / PHP-FPM -> MARIADB\n' "$$dim"; \
	printf '                   +-> STATIC PORTFOLIO%b\n\n' "$$reset"

help: banner
	@$(palette) \
	printf '  %b%-28s %s%b\n' "$$bold" 'COMMAND' 'DESCRIPTION' "$$reset"; \
	printf '  %-28s %s\n' '----------------------------' '--------------------------------------------'; \
	printf '  %b%-28s%b %s\n' "$$cyan" 'make / make up' "$$reset" 'Prepare, build, launch, and wait for health' \
	    "$$cyan" 'make setup' "$$reset" 'Generate missing configuration and secrets' \
	    "$$cyan" 'make build' "$$reset" 'Build every service image' \
	    "$$cyan" 'make down' "$$reset" 'Remove containers and network; keep data' \
	    "$$cyan" 'make stop' "$$reset" 'Stop containers' \
	    "$$cyan" 'make start' "$$reset" 'Start stopped containers and wait for health' \
	    "$$cyan" 'make restart' "$$reset" 'Restart services and wait for health' \
	    "$$cyan" 'make logs' "$$reset" 'Follow service logs; Ctrl-C exits' \
	    "$$cyan" 'make ps' "$$reset" 'Show containers and health' \
	    "$$cyan" 'make credentials' "$$reset" 'Show URLs, usernames, and password locations' \
	    "$$cyan" 'make config' "$$reset" 'Validate Docker Compose configuration' \
	    "$$cyan" 'make clean' "$$reset" 'Remove containers and network; keep data' \
	    "$$cyan" 'make re' "$$reset" 'Rebuild without cache; keep data and secrets' \
	    "$$cyan" 'make test' "$$reset" 'Run the disposable acceptance suite' \
	    "$$red" 'make fclean CONFIRM=DELETE' "$$reset" 'ERASE this stack: data, configuration, secrets'; \
	printf '\n  %bNormal lifecycle commands preserve persistent data.%b\n' "$$green" "$$reset"; \
	printf '  %bDisplay: COLOR=auto|always|never; NO_COLOR disables colors.%b\n\n' "$$dim" "$$reset"

setup: banner
	$(call status,cyan,SETUP,Preparing local configuration and protected secrets)
	@bash srcs/requirements/tools/setup.sh

build: setup
	$(call status,cyan,CHECK,Checking Docker and Compose configuration)
	@docker info >/dev/null
	@$(COMPOSE) config --quiet
	$(call status,cyan,BUILD,Building the four service images)
	@$(COMPOSE) build --pull
	$(call status,green,DONE,All service images built successfully)

up: build
	$(call status,cyan,START,Launching services and waiting for healthchecks)
	@$(COMPOSE) up -d --wait --wait-timeout 180
	$(call status,green,READY,All services are healthy)
	$(call status,dim,HINT,Run make credentials for access details or make help for commands)

down clean:
	$(call status,yellow,DOWN,Removing containers and network; persistent data is preserved)
	@$(COMPOSE) down --remove-orphans
	$(call status,green,DONE,Containers removed; data and credentials retained)

stop:
	$(call status,yellow,STOP,Stopping service processes)
	@$(COMPOSE) stop
	$(call status,green,DONE,Services stopped; run make start to resume)

start:
	$(call status,cyan,START,Starting stopped containers and waiting for healthchecks)
	@$(COMPOSE) start --wait --wait-timeout 180
	$(call status,green,READY,All services are healthy)

restart:
	$(call status,yellow,RESET,Restarting services and checking health)
	@$(COMPOSE) restart
	@$(COMPOSE) up -d --wait --wait-timeout 180
	$(call status,green,READY,All services are healthy)

logs:
	$(call status,cyan,LOGS,Following the last 100 log lines; Ctrl-C exits the viewer)
	@$(COMPOSE) logs --tail=100 -f

ps:
	$(call status,cyan,STATE,Container status and health)
	@$(COMPOSE) ps -a

credentials: setup
	$(call status,cyan,ACCESS,Access details; password contents stay private)
	@bash srcs/requirements/tools/credentials.sh

config: setup
	$(call status,cyan,CHECK,Validating Docker Compose configuration)
	@$(COMPOSE) config --quiet
	$(call status,green,VALID,Compose configuration is valid)

re: setup
	$(call status,yellow,RESET,Recreating the stack; persistent data and credentials are preserved)
	@$(COMPOSE) down --remove-orphans
	$(call status,cyan,BUILD,Rebuilding every image without cache)
	@$(COMPOSE) build --pull --no-cache
	$(call status,cyan,START,Launching rebuilt services and waiting for healthchecks)
	@$(COMPOSE) up -d --wait --wait-timeout 180
	$(call status,green,READY,Rebuilt stack is healthy; persistent data retained)

# Explicit opt-in: destroys this stack's database, uploads, configuration, and secrets.
fclean:
	@test "$(CONFIRM)" = DELETE || { echo 'Destructive: run make fclean CONFIRM=DELETE to erase this stack.'; exit 1; }
	$(call status,red,ERASE,Deleting this stack data and credentials; explicit opt-in received)
	@bash srcs/requirements/tools/purge.sh

# Runs a disposable fresh-checkout integration suite; leaves the normal stack alone.
test:
	$(call status,cyan,TEST,Running isolated acceptance tests; normal stack data is preserved)
	@python3 srcs/requirements/tools/verify.py
	$(call status,green,PASS,All disposable acceptance checks passed)
