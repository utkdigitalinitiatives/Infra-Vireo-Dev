variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-rocky-vm"
}

variable "location" {
  description = "The Azure Region in which all resources should be created"
  type        = string
  default     = "East US"
}

variable "vm_size" {
  description = "Size of the Virtual Machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "The username of the local administrator used for the Virtual Machine"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_name" {
  description = "Name of the Virtual Machine"
  type        = string
  default     = "vm-rocky-linux"
}