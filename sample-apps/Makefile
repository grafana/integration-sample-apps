### ----- NOTES ----- ###
# This makefile is meant to be called from *within* a sample app!
# As such, there are references to variables defined in child Makefiles
### ----- NOTES ----- ###

WORK_DIR = $(shell pwd)
# Ops script dir, as referred to when this script is *called by a sample app*, e.g. one directory deeper
COMMON_DIR = "../../ops/common"
OPS_SCRIPTS_DIR = "../../ops/scripts"
VM_MAIN = ""
ifdef VM_CLUSTER_MAIN
	VM_MAIN = $(VM_CLUSTER_MAIN)
else
	VM_MAIN = $(VM_NAME)
endif

.PHONY: k3s-setup k3s-stop configure_k3d_dns

#k3s/multinode setup
k3s-setup:
	@bash $(OPS_SCRIPTS_DIR)/k3s_setup.sh $(VM_NAME) 

k3s-stop:
	@bash $(OPS_SCRIPTS_DIR)/k3s_stop.sh $(VM_NAME)

k3s-setup-cluster:
	@bash $(OPS_SCRIPTS_DIR)/k3s_setup.sh $(VM_NAME) cluster

k3s-stop-cluster:
	@bash $(OPS_SCRIPTS_DIR)/k3s_stop.sh $(VM_NAME) cluster

# k3d (local dev) testing
configure-k3d-dns:
	@echo "Adding required dns entries for k3d to $(VM_MAIN)"

	@echo "Configuring for k3s cluster mode, main node will have DNS entries for k3d."
	@multipass transfer $(COMMON_DIR)/scripts/configure_k3d_dns.sh $(VM_MAIN):/home/ubuntu/configure_k3d_dns.sh
	@multipass exec $(VM_MAIN) -- bash -c "chmod +x configure_k3d_dns.sh && sudo ./configure_k3d_dns.sh"


