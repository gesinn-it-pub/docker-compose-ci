

# ======== Naming ========
EXTENSION_FOLDER := /var/www/html/extensions/$(EXTENSION)
extension := $(shell echo $(EXTENSION) | tr A-Z a-z})
IMAGE_NAME := $(extension):test-$(MW_VERSION)-$(SMW_VERSION) # ggf hier Timestamp 


# ======== CI ENV Variables ========
DB_TYPE ?= sqlite
DB_IMAGE ?= ""

export IMAGE_NAME
export EXTENSION
export NODE_JS
export COMPOSER_EXT
export MW_VERSION
export SMW_VERSION
export PHP_VERSION
export PF_VERSION
export PS_VERSION
export DT_VERSION
export AL_VERSION
export MAPS_VERSION
export SRF_VERSION
export CHAMELEON_VERSION
export DB_TYPE
export DB_IMAGE
export EXTENSION_FOLDER

ifneq (,$(wildcard ./build/docker-compose.override.yml))
     COMPOSE_OVERRIDE=-f build/docker-compose.override.yml
endif


compose = docker-compose -f build/docker-compose.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)
compose-ci = docker-compose -f build/docker-compose.yml -f build/docker-compose-ci.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)
compose-dev = docker-compose -f build/docker-compose.yml -f build/docker-compose-dev.yml $(COMPOSE_OVERRIDE) $(COMPOSE_ARGS)

compose-run = $(compose) run -T --rm
compose-exec-wiki = $(compose) exec -T wiki

show-current-target = @echo; echo "======= $@ ========"

# ======== CI ========
# ======== Global Targets ========

.PHONY: ci
ci: install composer-test npm-test

.PHONY: ci-coverage
ci-coverage: install composer-test-coverage npm-test-coverage

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

.PHONY: .destroy
.destroy:
	$(show-current-target)
	$(compose-ci) down -v

.PHONY: .bash
.bash: .init
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && bash"

# ======== Test Targets ========

.PHONY: composer-test
composer-test:
ifdef COMPOSE_EXT
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer test"
endif
.PHONY: composer-test-coverage
composer-test-coverage:
ifdef COMPOSE_EXT
	$(show-current-target)
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && composer test-coverage" 
endif
.PHONY: npm-test
npm-test:
ifdef NODE_JS
	$(compose-exec-wiki) bash -c "cd $(EXTENSION_FOLDER) && npm run test"
endif

.PHONY: npm-test-coverage
npm-test-coverage:
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
gh-login: require-GH_API_TOKEN
	gh config set prompt disabled
	@echo $(GH_API_TOKEN) | gh auth login --with-token

.PHONY: require-GH_API_TOKEN
require-GH_API_TOKEN:
ifndef GH_API_TOKEN
	$(error GH_API_TOKEN is not set)
endif


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