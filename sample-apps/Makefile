### ----- NOTES ----- ###
# This makefile is meant to be called from *within* a sample app!
# As such, there are references to variables defined in child Makefiles
### ----- NOTES ----- ###

# Ops dir, as referred to when this script is *called by a sample app*, e.g. one directory deeper
COMMON_DIR = "../../ops/common"
SAMPLETOOL = go run ../../ops/cmd/sampletool
VM_MAIN = ""
ifdef VM_CLUSTER_MAIN
	VM_MAIN = $(VM_CLUSTER_MAIN)
else ifdef VM_K3S_NAME
	VM_MAIN = $(VM_K3S_NAME)
else
	VM_MAIN = $(VM_NAME)
endif

.PHONY: k3s-setup k3s-stop k3s-setup-cluster k3s-stop-cluster configure-k3d-dns shell

#k3s/multinode setup
k3s-setup:
	@$(SAMPLETOOL) k3s up $(VM_NAME)

k3s-stop:
	@$(SAMPLETOOL) k3s down $(VM_NAME)

k3s-setup-cluster:
	@$(SAMPLETOOL) k3s up --cluster $(VM_NAME)

k3s-stop-cluster:
	@$(SAMPLETOOL) k3s down --cluster $(VM_NAME)

# k3d (local dev) testing
configure-k3d-dns:
	@echo "Adding required dns entries for k3d to $(VM_MAIN)"

	@echo "Configuring for k3s cluster mode, main node will have DNS entries for k3d."
	@multipass transfer $(COMMON_DIR)/scripts/configure_k3d_dns.sh $(VM_MAIN):/home/ubuntu/configure_k3d_dns.sh
	@multipass exec $(VM_MAIN) -- bash -c "chmod +x configure_k3d_dns.sh && sudo ./configure_k3d_dns.sh"

shell:
	@multipass shell $(VM_MAIN)
