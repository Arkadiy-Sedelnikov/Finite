# See docs
#  * https://dev.azure.com/irkoil-dev/ink_ep_backend/_wiki/wikis/WikiEP/125/Makefile
#  * https://guides.hexlet.io/makefile-as-task-runner/

#### Makefile global configuration
.PHONY: build
.DEFAULT_GOAL := help
SHELL = /bin/bash

# Configs
PARALLEL_NUM        ?= 6
PHP_MEMORY_LIMIT    ?= 2G
PHPCPD_MIN_LINES    ?= 20
FLOW_ID             := $(shell date +"%H%M%S")
TC_REPORT           ?= "tc-inspections"

#### Predefined global variables/functions
# Colors for SH scripts. See https://www.shellhacks.com/bash-colors/
CE           = \033[0m
C_RED        = \033[0;31m
C_GREEN      = \033[0;32m
C_YELLOW     = \033[0;33m
C_TITLE      = \033[0;30;46m

# Paths
PATH_ROOT    ?= `pwd`
PATH_SRC     ?= $(PATH_ROOT)/src
PATH_SRC_ALT ?= $(PATH_ROOT)
PATH_BUILD   ?= $(PATH_ROOT)/build

# Binary files
PHP_BIN             ?= php
PHP_BIN_CONF        ?= XDEBUG_MODE=off $(PHP_BIN) -d max_execution_time=900 -d memory_limit=$(PHP_MEMORY_LIMIT) -d error_reporting=~E_DEPRECATED
VENDOR_BIN          ?= $(PHP_BIN_CONF) $(PATH_ROOT)/bin
COMPOSER_BIN        ?= $(PHP_BIN_CONF) $(PATH_ROOT)/tools/composer.phar
PHPCPD_BIN          ?= $(PHP_BIN_CONF) $(PATH_ROOT)/tools/phpcpd.phar
PHAN_BIN            ?= $(PHP_BIN_CONF) $(PATH_ROOT)/tools/phan.phar
PDEPEND_BIN         ?= $(PHP_BIN_CONF) $(PATH_ROOT)/tools/pdepend.phar
PHPLOC_BIN          ?= $(PHP_BIN_CONF) $(PATH_ROOT)/tools/phploc.phar
CI_REPORT_CONVERTER ?= $(VENDOR_BIN)/ci-report-converter convert        --root-path="$(PATH_SRC)" --tc-flow-id=$(FLOW_ID) -v
CI_REPORT_STATS     ?= $(VENDOR_BIN)/ci-report-converter teamcity:stats --root-path="$(PATH_SRC)" --tc-flow-id=$(FLOW_ID) -v

# Render colored title before executing a command
define title
    @echo ""
    @echo -e "$(C_YELLOW)>>>> >>>> >>>> >>>> >>>> >>>> $(C_TITLE) $(1) $(CE)"
endef

# Render colored title before executing a command
define tcStart
    @echo "##teamcity[progressStart '$(1)']"
endef

define tcFinish
    @echo "##teamcity[progressFinish '$(1)']"
endef

list: ## Full list of targets
	@$(MAKE) -pRrq -f $(MAKEFILE_LIST) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

#### Testing Actions ###################################################################################################
test: ##@Testing Run a full check with all available linters.
	@make test-phpunit
	@make test-phpstan

#### PhpUnit - Unit Testing ############################################################################################
test-phpunit: ##@Testing PhpUnit - Unit Testing
	$(call title,"PHPUnit - Unit tests")
	@$(VENDOR_BIN)/phpunit                                          \
        --cache-result-file="$(PATH_BUILD)/phpunit.cache"           \
        --colors=always


test-phpunit-ci: ##@CI PHPUnit - Unit Testing
	$(call tcStart,"test-phpunit-ci: PHPUnit - Unit Testing")
	@$(VENDOR_BIN)/phpunit                                          \
        --cache-result-file="$(PATH_BUILD)/phpunit.cache"           \
        --teamcity
	@$(CI_REPORT_STATS)                                             \
        --input-format="junit-xml"                                  \
        --input-file="$(PATH_BUILD)/phpunit-junit/index.xml"
	@-$(CI_REPORT_STATS)                                            \
        --input-format="phpunit-clover-xml"                         \
        --input-file="$(PATH_BUILD)/phpunit-clover.xml"
	$(call tcFinish,"test-phpunit-ci: PHPUnit - Unit Testing")


#### PHPStan - Static Analysis Tool ####################################################################################
test-phpstan: ##@Testing PHPStan - Static Analysis Tool
	$(call title,"PHPStan - Static Analysis Tool")
	@echo "Src Path: $(PATH_SRC)"
	@$(VENDOR_BIN)/phpstan analyse                                      \
        --configuration="$(PATH_ROOT)/phpstan.neon"                     \
        --memory-limit=$(PHP_MEMORY_LIMIT)                              \
        --error-format="checkstyle"                                     \
        --no-ansi                                                       \
        "$(PATH_SRC)" > "$(PATH_BUILD)/phpstan-checkstyle.xml"          || true
	@$(CI_REPORT_CONVERTER)                                             \
        --input-format="checkstyle"                                     \
        --input-file="$(PATH_BUILD)/phpstan-checkstyle.xml"             \
        --output-format="plain"                                         \
        --non-zero-code=yes


test-phpstan-ci: ##@CI PHPStan - Static Analysisc Tool
	$(call tcStart,"test-phpstan-ci: PHPstan - Static Analysis Tool")
	@echo "Src Path: $(PATH_SRC)"
	@$(VENDOR_BIN)/phpstan analyse                                      \
        --configuration="$(PATH_ROOT)/phpstan.neon"                     \
        --error-format=checkstyle                                       \
        --memory-limit=$(PHP_MEMORY_LIMIT)                              \
        --no-progress                                                   \
        "$(PATH_SRC)" > "$(PATH_BUILD)/phpstan-checkstyle.xml"          || true
	@$(CI_REPORT_CONVERTER)                                             \
        --input-format="checkstyle"                                     \
        --input-file="$(PATH_BUILD)/phpstan-checkstyle.xml"             \
        --output-format="tc-tests"                                      \
        --suite-name="PHPstan"                                          \
        --non-zero-code=no
	$(call tcFinish,"test-phpstan-ci: PHPstan - Static Analysis Tool")
