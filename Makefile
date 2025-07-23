### ----- NOTES ----- ###
# 
### ----- NOTES ----- ###
MAKEFLAGS += --no-print-directory
WORK_DIR = $(shell pwd)
OPS_SCRIPTS_DIR = "./ops/scripts"
DBS_NAME ?= "dbs"
APPS ?= ""
ENV ?= "local"

.PHONY: setup-dbs stop-dbs setup-apps test-apps stop-apps stop-all

# DBs
setup-dbs:
	@bash $(OPS_SCRIPTS_DIR)/setup_dbs.sh $(DBS_NAME) $(ENV)
	@echo "IP of database deployment:"
	@bash $(OPS_SCRIPTS_DIR)/multipass_get_ips.sh $(DBS_NAME)

stop-dbs:
	@echo "Deleting databases"
	@multipass delete $(DBS_NAME)
	@multipass purge

# Sample apps
setup-apps:
	@echo "Setting up apps=$(APPS) for env=$(ENV)"
	@bash $(OPS_SCRIPTS_DIR)/setup_sample_apps.sh $(APPS) $(ENV)

test-apps:
	@echo "Testing apps=$(APPS) for env=$(ENV)"
	@bash $(OPS_SCRIPTS_DIR)/test_sample_apps.sh $(APPS) $(ENV)

stop-apps:
	@echo "Tearing down apps=$(APPS)"
	@bash $(OPS_SCRIPTS_DIR)/stop_sample_apps.sh $(APPS)

# General
stop-all: 
	@echo "Deleting all Multipass VMs"
	@multipass delete --all
	@multipass purge