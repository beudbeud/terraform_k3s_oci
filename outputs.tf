output "vcn_state" {
  description = "The state of the VCN."
  value       = oci_core_vcn.main.state
}

output "vcn_cidr" {
  description = "CIDR block of the core VCN"
  value       = oci_core_vcn.main.cidr_block
}

output "images_amd64" {
  value = data.oci_core_images.amd64.images.0
}

output "images_aarch64" {
  value = data.oci_core_images.aarch64.images.0
}
