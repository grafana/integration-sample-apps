variable "credentials" {
  type        = string
  description = "GCP authentication file"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "project" {
  type        = string
  description = "GCP project name"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
}

variable "agent_config_content" {
  description = "Contents of the agent-config.yaml file"
  type        = string
  default     = ""
}
