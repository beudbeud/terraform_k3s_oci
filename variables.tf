variable "compartment_id" {
  description = "OCID from your tenancy page"
  type        = string
}
variable "region" {
  description = "region where you have OCI tenancy"
  type        = string
  default     = "us-sanjose-1"
}
variable "whitelist_subnets" {
  description = "List of white list subnets" 
  type        = list
  default     = [
    "172.217.170.4/32",
    "10.0.0.0/8"
  ]
}
variable "vcn_subnet" {
  description = "Main subnet"
  type        = string
  default     = "10.0.0.0/16"
}
variable "private_subnet" {
  description = "Private Subnet"
  type        = string
  default     = "10.0.2.0/23"
}
variable "public_subnet" {
  description = "Public subnet"
  type        = string
  default     = "10.0.0.0/23"
}

variable "mysql_password" {
  description = "Password MySQL"
  type        = string
}

