terraform {
  required_providers {
    oci = {
      source = "hashicorp/oci"
    }
  }
}

provider "oci" {
  region              = var.region
  auth                = "SecurityToken"
  config_file_profile = "DEFAULT"
}

resource "random_password" "cluster_token" {
  length = 64
}

resource "oci_core_vcn" "main" {
  dns_label      = "main"
  cidr_block     = var.vcn_subnet
  compartment_id = var.compartment_id
  display_name   = "main"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id 
  display_name = "main"
}

resource "oci_core_nat_gateway" "private_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "private_subnet"

}

resource "oci_core_subnet" "private_subnet" {
  vcn_id                      = oci_core_vcn.main.id
  cidr_block                  = var.private_subnet
  compartment_id              = var.compartment_id
  display_name                = "Private subnet"
  dns_label                   = "private"
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block     = var.public_subnet
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "Public subnet"
  dns_label      = "public"
}

resource "oci_core_default_route_table" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id

    description = "internet gateway"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_route_table" "private_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id

  display_name = "private_subnet_natgw"

  route_rules {
    network_entity_id = oci_core_nat_gateway.private_subnet.id

    description = "k8s private to public internal"
    destination = "0.0.0.0/0"

  }

  # TODO: add service gateway
}


resource "oci_core_default_security_list" "default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "17"
  }

  dynamic "ingress_security_rules" {
    for_each = var.whitelist_subnets
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "SSH"

      tcp_options {
        max = 22
        min = 22
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.whitelist_subnets
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "Kubernetes API"

      tcp_options {
        max = 6443
        min = 6443
      }
    }
  }
  
  dynamic "ingress_security_rules" {
    for_each = var.whitelist_subnets
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "MySQL"

      tcp_options {
        max = 3306
        min = 3306
      }
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = var.vcn_subnet
    description = "Kubernetes VXLAN"

    udp_options {
      max = 8472
      min = 8472
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_subnet
    description = "Kubernetes Metrics"

    tcp_options {
      max = 10250
      min = 10250
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_subnet
    description = "Nginx Ingress NodePort"

    tcp_options {
      max = 30080
      min = 30080
    }
  }
}

data "oci_core_images" "amd64" {
  compartment_id = var.compartment_id
  operating_system = "Canonical Ubuntu"
  operating_system_version = "20.04"

  filter {
    name   = "display_name"
    values = ["^([a-zA-z]+)-([a-zA-z]+)-([\\.0-9]+)-([\\.0-9-]+)$"]
    regex  = true
  }

}

data "oci_core_images" "aarch64" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "20.04"

  filter {
    name   = "display_name"
    values = ["^.*-aarch64-.*$"]
    regex  = true
  }
}

data "template_file" "externaldb_template" {
  template = file("./scripts/externaldb.template.sh")

  vars = {
    password = var.mysql_password
  }
}

data "template_file" "externaldb_cloud_init_file" {
  template = file("./cloud-init/cloud-init.template.yaml")

  vars = {
    bootstrap_sh_content = base64gzip(data.template_file.externaldb_template.rendered)
  }

}

data "template_cloudinit_config" "externaldb" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "externaldb.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.externaldb_cloud_init_file.rendered
  }
}

data "template_file" "server_template" {
  template = file("./scripts/server.template.sh")

  vars = {
    password = var.mysql_password
    cluster_token = random_password.cluster_token.result
  }
}

data "template_file" "server_cloud_init_file" {
  template = file("./cloud-init/cloud-init.template.yaml")

  vars = {
    bootstrap_sh_content = base64gzip(data.template_file.server_template.rendered)
  }

}

data "template_cloudinit_config" "server" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "server.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.server_cloud_init_file.rendered
  }
}

data "template_file" "worker_template" {
  template = file("./scripts/worker.template.sh")

  vars = {
    cluster_token = random_password.cluster_token.result
  }
}

data "template_file" "worker_cloud_init_file" {
  template = file("./cloud-init/cloud-init.template.yaml")

  vars = {
    bootstrap_sh_content = base64gzip(data.template_file.worker_template.rendered)
  }

}

data "template_cloudinit_config" "worker" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "worker.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.worker_cloud_init_file.rendered
  }
}

resource "oci_core_instance" "externaldb" {
  availability_domain  = "JHRb:EU-FRANKFURT-1-AD-1"
  compartment_id       = var.compartment_id
  display_name         = "ExternalDB"
  preserve_boot_volume = false
  shape                = "VM.Standard.E2.1.Micro"

  source_details {
    source_id = data.oci_core_images.amd64.images.0.id
    source_type = "image"
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.private_subnet.id
    display_name              = "primary"
    assign_public_ip          = true
    hostname_label            = "externaldb"
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub")
    user_data           = data.template_cloudinit_config.externaldb.rendered
  }
} 

resource "oci_core_instance" "master" {
  availability_domain  = "JHRb:EU-FRANKFURT-1-AD-1"
  compartment_id       = var.compartment_id
  display_name         = "Master"
  preserve_boot_volume = false
  shape                = "VM.Standard.E2.1.Micro"

  depends_on = [ oci_core_instance.externaldb ]

  source_details {
    source_id = data.oci_core_images.amd64.images.0.id
    source_type = "image"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.private_subnet.id
    display_name     = "primary"
    assign_public_ip = true
    hostname_label   = "master"
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub")
    user_data           = data.template_cloudinit_config.server.rendered 
  }
}

resource "oci_core_instance" "worker1" {
  compartment_id = var.compartment_id
  availability_domain  = "JHRb:EU-FRANKFURT-1-AD-3"
  display_name   = "Worker1"
  shape = "VM.Standard.A1.Flex"
  
  depends_on = [ oci_core_instance.master ]

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "worker1"
  }

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_id    = data.oci_core_images.aarch64.images.0.id
    source_type = "image"
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub")
    user_data           = data.template_cloudinit_config.worker.rendered
  }
}

resource "oci_core_instance" "worker2" {
  compartment_id = var.compartment_id
  availability_domain  = "JHRb:EU-FRANKFURT-1-AD-3"
  display_name   = "Worker2"
  shape = "VM.Standard.A1.Flex"

  depends_on = [ oci_core_instance.master ]

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "worker2"
  }

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_id    = data.oci_core_images.aarch64.images.0.id
    source_type = "image"
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub")
    user_data           = data.template_cloudinit_config.worker.rendered
  }
}
