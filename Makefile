### ----- NOTES ----- ###
# 
### ----- NOTES ----- ###
MAKEFLAGS += --no-print-directory
SAMPLETOOL = go run ./ops/cmd/sampletool
DBS_NAME ?= "dbs"
APPS ?= ""
ENV ?= "local"

.PHONY: help setup-dbs stop-dbs setup-apps test-apps stop-apps stop-all

help:
	@$(SAMPLETOOL) help

# DBs
setup-dbs:
	@$(SAMPLETOOL) dbs up --dbs $(DBS_NAME) --env $(ENV)

stop-dbs:
	@$(SAMPLETOOL) dbs down --dbs $(DBS_NAME)

# Sample apps
setup-apps:
	@echo "Setting up apps=$(APPS) for env=$(ENV)"
	@$(SAMPLETOOL) apps up --apps $(APPS) --env $(ENV) --dbs $(DBS_NAME)

test-apps:
	@echo "Testing apps=$(APPS) for env=$(ENV)"
	@$(SAMPLETOOL) apps test --apps $(APPS) --env $(ENV) --dbs $(DBS_NAME)

stop-apps:
	@echo "Tearing down apps=$(APPS)"
	@$(SAMPLETOOL) apps down --apps $(APPS)

# General
stop-all:
	@echo "Deleting all Multipass VMs"
	@multipass delete --all
	@multipass purge
