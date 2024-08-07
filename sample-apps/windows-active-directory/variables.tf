variable "resource_group_location" {
  default     = "centralus"
  description = "Location of the resource group."
}

variable "prefix" {
  type        = string
  default     = "win-vm-active-directory"
  description = "Prefix of the resource name"
}

variable "loki_url" {
  type        = string
  description = "The Loki url to set in the agent-config.yaml file."
}

variable "loki_username" {
  type        = string
  description = "The Loki username to set in the agent-config.yaml file."
}

variable "loki_password" {
  type        = string
  description = "The Loki password to set in the agent-config.yaml file."
}

variable "prometheus_username" {
  type        = string
  description = "The Prometheus username to set in the agent-config.yaml file."
}

variable "prometheus_password" {
  type        = string
  description = "The Prometheus password to set in the agent-config.yaml file."
}

variable "prometheus_url" {
  type        = string
  description = "The Prometheus push endpoint to set in the agent-config.yaml file."
}

