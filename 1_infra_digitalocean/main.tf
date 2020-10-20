terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "1.23.0"
    }
    template = {
      source = "hashicorp/template"
      version = "2.2.0"
    }
  }
}

provider "template" {
  # Configuration options
}

variable "do_datacenter" {
  type    = string
  default = "nyc3"
}
variable "idm_hostname" {
  type    = string
  default = "idm"
}
variable "domain" {
  type    = string
  default = "example.com"
}
variable "droplet_size" {
  type    = string
  default = "s-1vcpu-1gb"
}
variable "droplet_image" {
  type    = string
  default = "centos-8-x64"
}
variable "do_token" {}
variable "do_vpc_cidr" {}

provider "digitalocean" {
  token = var.do_token
}

resource "tls_private_key" "cluster_new_key" {
  algorithm = "RSA"
}

resource "local_file" "cluster_new_priv_file" {
  content         = tls_private_key.cluster_new_key.private_key_pem
  filename        = "../.generated/.${var.idm_hostname}.${var.domain}/priv.pem"
  file_permission = "0600"
}
resource "local_file" "cluster_new_pub_file" {
  content  = tls_private_key.cluster_new_key.public_key_openssh
  filename = "../.generated/.${var.idm_hostname}.${var.domain}/pub.key"
}

resource "digitalocean_ssh_key" "cluster_ssh_key" {
  name       = "${var.idm_hostname}SSHKey"
  public_key = tls_private_key.cluster_new_key.public_key_openssh
}

locals {
  ssh_fingerprint = digitalocean_ssh_key.cluster_ssh_key.fingerprint
}

data "template_file" "ansible_inventory" {
  template = file("./inventory.tpl")
  vars = {
    idm_node = join("\n", formatlist("%s ansible_do_host=%s ansible_internal_private_ip=%s", digitalocean_droplet.idm_node.ipv4_address, digitalocean_droplet.idm_node.name, digitalocean_droplet.idm_node.ipv4_address_private))
    ssh_private_file = "../.generated/.${var.idm_hostname}.${var.domain}/priv.pem"
  }
  depends_on = [digitalocean_droplet.idm_node]
}

resource "local_file" "ansible_inventory" {
  content  = data.template_file.ansible_inventory.rendered
  filename = "../.generated/.${var.idm_hostname}.${var.domain}/inventory"
}

resource "digitalocean_vpc" "idmVPC" {
  name     = "${var.idm_hostname}-priv-net"
  region   = var.do_datacenter
  ip_range = var.do_vpc_cidr
}

resource "digitalocean_droplet" "idm_node" {
  image              = var.droplet_image
  name               = "${var.idm_hostname}.${var.domain}"
  region             = var.do_datacenter
  size               = var.droplet_size
  private_networking = true
  vpc_uuid           = digitalocean_vpc.idmVPC.id
  ssh_keys           = [local.ssh_fingerprint]
  depends_on         = [digitalocean_ssh_key.cluster_ssh_key, digitalocean_vpc.idmVPC]
  tags               = [var.idm_hostname]
}

resource "digitalocean_record" "idmHostname" {
  domain      = var.domain
  type        = "A"
  name        = var.idm_hostname
  value       = digitalocean_droplet.idm_node.ipv4_address
  ttl         = "6400"
  depends_on  = [digitalocean_droplet.idm_node]
}
resource "digitalocean_record" "idmCAHostname" {
  domain      = var.domain
  type        = "A"
  name        = "${var.idm_hostname}-ca"
  value       = digitalocean_droplet.idm_node.ipv4_address
  ttl         = "6400"
  depends_on  = [digitalocean_droplet.idm_node]
}
resource "digitalocean_record" "kerberosTXT" {
  domain   = var.domain
  type     = "TXT"
  name     = "_kerberos"
  value    = var.domain
  ttl      = "6400"
}
resource "digitalocean_record" "kerberosTCPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_kerberos._tcp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "88"
  weight   = "100"
  ttl      = "6400"
}
resource "digitalocean_record" "kerberosUDPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_kerberos._udp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "88"
  weight   = "100"
  ttl      = "6400"
}
resource "digitalocean_record" "kerberosMasterTCPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_kerberos-master._tcp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "88"
  weight   = "100"
  ttl      = "6400"
}
resource "digitalocean_record" "kerberosMasterUDPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_kerberos-master._udp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "88"
  weight   = "100"
  ttl      = "6400"
}

resource "digitalocean_record" "kpasswdTCPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_kpasswd._tcp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "464"
  weight   = "100"
  ttl      = "6400"
}
resource "digitalocean_record" "kpasswdUDPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_kpasswd._udp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "464"
  weight   = "100"
  ttl      = "6400"
}

resource "digitalocean_record" "ldapTCPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_ldap._tcp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "389"
  weight   = "100"
  ttl      = "6400"
}
resource "digitalocean_record" "ldapsTCPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_ldaps._tcp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "636"
  weight   = "100"
  ttl      = "6400"
}

resource "digitalocean_record" "ntpTCPSRV" {
  domain   = var.domain
  type     = "SRV"
  name     = "_ntp._tcp"
  value    = "${var.idm_hostname}.${var.domain}."
  priority = "0"
  port     = "123"
  weight   = "100"
  ttl      = "6400"
}