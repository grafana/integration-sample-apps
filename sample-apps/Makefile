### ----- NOTES ----- ###
# This makefile is meant to be called from *within* a sample app!
# As such, there are references to variables defined in child Makefiles
### ----- NOTES ----- ###

SAMPLETOOL = go run ../../ops/cmd/sampletool
VM_MAIN = ""
ifdef VM_CLUSTER_MAIN
	VM_MAIN = $(VM_CLUSTER_MAIN)
else ifdef VM_K3S_NAME
	VM_MAIN = $(VM_K3S_NAME)
else
	VM_MAIN = $(VM_NAME)
endif

.PHONY: k3s-setup k3s-stop k3s-setup-cluster k3s-stop-cluster shell

#k3s/multinode setup
k3s-setup:
	@$(SAMPLETOOL) k3s up $(VM_NAME)

k3s-stop:
	@$(SAMPLETOOL) k3s down $(VM_NAME)

k3s-setup-cluster:
	@$(SAMPLETOOL) k3s up --cluster $(VM_NAME)

k3s-stop-cluster:
	@$(SAMPLETOOL) k3s down --cluster $(VM_NAME)

shell:
	@multipass shell $(VM_MAIN)
