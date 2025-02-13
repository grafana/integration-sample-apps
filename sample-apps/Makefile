### ----- NOTES ----- ###
# This makefile is meant to be called from *within* a sample app!
# As such, there are references to variables defined in child Makefiles
### ----- NOTES ----- ###

WORK_DIR = $(shell pwd)
# Ops script dir, as referred to when this script is *called by a sample app*, e.g. one directory deeper
OPS_SCRIPTS_DIR = "../../ops/scripts"

.PHONY: k3s-setup k3s-stop

k3s-setup:
	@bash $(OPS_SCRIPTS_DIR)/k3s_setup.sh $(VM_NAME) 

k3s-stop:
	@bash $(OPS_SCRIPTS_DIR)/k3s_stop.sh $(VM_NAME)

k3s-setup-cluster:
	@bash $(OPS_SCRIPTS_DIR)/k3s_setup.sh $(VM_NAME) cluster

k3s-stop-cluster:
	@bash $(OPS_SCRIPTS_DIR)/k3s_stop.sh $(VM_NAME) cluster
