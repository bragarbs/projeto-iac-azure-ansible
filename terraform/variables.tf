
variable "location" {
  description = "Regiao da Azure"
  type        = string
  default     = "Brazil South"
}

variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
  default     = "rg-devops-unidade4"
}

variable "vm_name" {
  description = "Nome da maquina virtual"
  type        = string
  default     = "vm-windows-iis"
}

variable "vm_size" {
  description = "Tamanho da maquina virtual"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Usuario administrador da VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Senha do administrador da VM"
  type        = string
  sensitive   = true
}

variable "allowed_source_ip" {
  description = "IP publico autorizado a acessar a VM"
  type        = string
}
