variable "resource_group_location" {
  default     = "centralus"
  description = "Location of the resource group."
}

variable "prefix" {
  type        = string
  default     = "win-vm-active-directory"
  description = "Prefix of the resource name"
}

##################################
## Active Directory - Variables ##
##################################


