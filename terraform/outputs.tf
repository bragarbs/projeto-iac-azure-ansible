
output "public_ip" {
  description = "IP publico da VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_name" {
  description = "Nome da VM"
  value       = azurerm_windows_virtual_machine.vm.name
}

output "resource_group" {
  description = "Resource Group criado"
  value       = azurerm_resource_group.rg.name
}
