
# Resolve the GitHub token from a per-identity env var derived from the
# local git identity (e.g. "alexander-gesinn" -> GH_TOKEN_ALEXANDER_GESINN),
# falling back to GH_API_TOKEN for contributors who haven't migrated yet.
GH_USER := $(shell git config user.name)
GH_TOKEN_VAR := GH_TOKEN_$(shell echo $(GH_USER) | tr '[:lower:]-' '[:upper:]_')
GH_TOKEN := $(or $($(GH_TOKEN_VAR)),$(GH_API_TOKEN))
# docker compose reads it from the environment as build secret GH_API_TOKEN (see docker-compose.yml);
# exported, not part of "environment" below, so that it does not show up in the printed commands
ifneq ($(GH_TOKEN),)
export GH_API_TOKEN := $(GH_TOKEN)
endif
# ======== Naming ========
EXTENSION_FOLDER := /var/www/html/extensions/$(EXTENSION)
extension := $(shell echo $(EXTENSION) | tr A-Z a-z})
IMAGE_NAME := $(extension):test-$(MW_VERSION)-$(SMW_VERSION) # ggf hier Timestamp 


# ======== CI ENV Variables ========
DB_TYPE ?= sqlite
DB_IMAGE ?= ""
MW_INSTALL_PATH ?= /var/www/html

environment = \
AL_VERSION=$(AL_VERSION) \
AR_VERSION=$(AR_VERSION) \
BROWSER_TESTS=$(BROWSER_TESTS) \
CHAMELEON_VERSION=$(CHAMELEON_VERSION) \
COMPOSER_EXT=$(COMPOSER_EXT) \
DB_IMAGE=$(DB_IMAGE) \
DB_TYPE=$(DB_TYPE) \
DT_VERSION=$(DT_VERSION) \
ECHO_VERSION=$(ECHO_VERSION) \
EXTENSION=$(EXTENSION)  \
EXTENSION_FOLDER=$(EXTENSION_FOLDER) \
IMAGE_NAME=$(IMAGE_NAME) \
MAPS_VERSION=$(MAPS_VERSION) \
LINGO_VERSION=${LINGO_VERSION} \
SCRIBUNTO_VERSION=${SCRIBUNTO_VERSION} \
MM_VERSION=$(MM_VERSION) \
MW_INSTALL_PATH=$(MW_INSTALL_PATH) \
MW_VERSION=$(MW_VERSION)  \
NODE_JS=$(NODE_JS)  \
PF_REPO=$(PF_REPO) \
PF_VERSION=$(PF_VERSION) \
PHP_EXTENSIONS="$(PHP_EXTENSIONS)" \
OS_PACKAGES="$(OS_PACKAGES)" \
PHP_VERSION=$(PHP_VERSION) \
PS_VERSION=$(PS_VERSION) \
SMW_VERSION=$(SMW_VERSION) \
SRF_VERSION=$(SRF_VERSION) \


ifneq (,$(wildcard ./build/docker-compose.override.yml))
     COMPOSE_OVERRIDE=-f build/docker-compose.override.yml
endif


compose = $(environment) docker compose -f build/docker-compose.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)
compose-ci = $(environment) docker compose -f build/docker-compose.yml -f build/docker-compose-ci.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)
compose-dev = $(environment) docker compose -f build/docker-compose.yml -f build/docker-compose-dev.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)

compose-run = $(compose) run -T --rm
compose-exec-wiki = $(compose) exec -T wiki
compose-exec-wiki-ci = $(compose-ci) exec -T wiki

show-current-target = @echo; echo "======= $@ ========"

# ======== CI ========
# ======== Global Targets ========

.PHONY: analyze
analyze: install composer-analyze

.PHONY: ci
ci: install composer-test npm-test

.PHONY: ci-coverage
ci-coverage: install composer-test-coverage npm-test-coverage

.PHONY: fix
fix: install composer-fix

.PHONY: install
install: destroy up .install

.PHONY: up
up: .init .build .up

.PHONY: down
down: .init .down

.PHONY: destroy
destroy: .init .destroy

.PHONY: bash
bash: .bash

# ======== General Docker-Compose Helper Targets ========

.PHONY: .build
.build:
	$(show-current-target)
	$(compose-ci) build --no-cache wiki

.PHONY: .up
.up:
	$(show-current-target)
	$(compose-ci) up -d
	$(compose-exec-wiki-ci) bash -c "rm -r -f coverage"

.PHONY: .install
.install: .wait-for-db
	$(show-current-target)
	$(compose-exec-wiki) bash -c "sudo -u www-data \
		php maintenance/install.php \
		    --pass=wiki4everyone --server=http://localhost:8080 --scriptpath='' \
		    --dbname=wiki --dbuser=wiki --dbpass=wiki $(WIKI_DB_CONFIG) wiki WikiSysop && \
		cat __setup_extension__ >> LocalSettings.php && \
		sudo -u www-data php maintenance/update.php --skip-external-dependencies --quick \
		"

.PHONY: .down
.down:
	$(show-current-target)
	$(compose-ci) down

	# Cleanup: remove images belonging to this compose project
	@echo "Removing test images for project $(extension)-$(DB_TYPE) ..."
	@docker images --filter "label=com.docker.compose.project=$(extension)-$(DB_TYPE)" -q | \
		xargs -r docker rmi -f


.PHONY: .destroy
.destroy:
	$(show-current-target)
	$(compose-ci) down -v

.PHONY: .bash
.bash: .init
	$(show-current-target)
	$(compose) exec wiki bash -c "cd $(EXTENSION_FOLDER) && bash"

# ======== Analyze Targets ========

.PHONY: composer-analyze
composer-analyze: .init
ifdef COMPOSER_EXT
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer analyze $(COMPOSER_PARAMS)"
endif

# ======== Test Targets ========

.PHONY: composer-phpunit
composer-phpunit: .init
ifdef COMPOSER_EXT
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer phpunit $(COMPOSER_PARAMS)"
endif

.PHONY: composer-test
composer-test: .init
ifdef COMPOSER_EXT
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer test $(COMPOSER_PARAMS)"
endif

.PHONY: composer-test-coverage
composer-test-coverage: .init
ifdef COMPOSER_EXT
	$(show-current-target)
	$(compose-ci) exec -T -e XDEBUG_MODE=coverage wiki bash -c "cd $(EXTENSION_FOLDER) && composer test-coverage $(COMPOSER_PARAMS) && { composer post-test-coverage > /dev/null 2>&1 || true; }"
endif

.PHONY: composer-fix
composer-fix: .init
ifdef COMPOSER_EXT
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer fix $(COMPOSER_PARAMS)" 
endif

.PHONY: npm-test
npm-test: .init
ifdef NODE_JS
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && npm run test"
endif

.PHONY: npm-test-coverage
npm-test-coverage: .init
ifdef NODE_JS
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && npm run test-coverage" 
endif

# ======== Dev Targets ========

.PHONY: dev-bash
dev-bash: .init
	$(compose-dev) run -it wiki bash -c 'service apache2 start && bash'

.PHONY: run
run:
	$(compose-dev) -f docker-compose-dev.yml run -it wiki

# ======== Releasing ========
VERSION = `node -e 'console.log(require("./extension.json").version)'`

.PHONY: release
release: ci git-push gh-login
	gh release create $(VERSION)

.PHONY: git-push
git-push:
	git diff --quiet || (echo 'git directory has changes'; exit 1)
	git push

.PHONY: gh-login
gh-login: require-GH_TOKEN
	gh config set prompt disabled
	@echo $(GH_TOKEN) | gh auth login --with-token

.PHONY: require-GH_TOKEN
require-GH_TOKEN:
ifndef GH_TOKEN
	$(error No GitHub token found. Set $(GH_TOKEN_VAR) (derived from git config user.name "$(GH_USER)") or GH_API_TOKEN as a fallback.)
endif

# ======== Develop ========

.PHONY: prepare-dev
prepare-dev: .init
	$(show-current-target)
	$(compose-exec-wiki) bash -c "sed -i 's|/var/www/html/\(.*\)|$(EXTENSION_FOLDER)/|' /tools/prepare-dev.sh"
	$(compose-exec-wiki) bash -c "sed -i 's|/var/www/html\(.*\)|${EXTENSION_FOLDER}\1|' /tools/files/.vscode/launch.json"
	$(compose-exec-wiki) bash -c "bash prepare-dev.sh"

	@echo "Xdebug has been configured successfully."

# ======== Helpers ========
.PHONY: .init
.init:
	$(show-current-target)
	$(eval COMPOSE_ARGS = --project-name ${extension}-$(DB_TYPE) --profile $(DB_TYPE))
ifeq ($(DB_TYPE), sqlite)
	$(eval WIKI_DB_CONFIG = --dbtype=$(DB_TYPE) --dbpath=/tmp/sqlite)
else
	$(eval WIKI_DB_CONFIG = --dbtype=$(DB_TYPE) --dbserver=$(DB_TYPE) --installdbuser=root --installdbpass=database)
endif
	@echo "COMPOSE_ARGS: $(COMPOSE_ARGS)"

.PHONY: .wait-for-db
.wait-for-db:
	$(show-current-target)
ifeq ($(DB_TYPE), mysql)
	$(compose-run) wait-for $(DB_TYPE):3306 -t 120
else ifeq ($(DB_TYPE), postgres)
	$(compose-run) wait-for $(DB_TYPE):5432 -t 120
endif
