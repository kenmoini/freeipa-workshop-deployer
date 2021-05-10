terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
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

provider "aws" {
  # Configure the AWS Provider
  region = var.aws_region
}

variable "vpc_id" {
  type    = string
}
variable "aws_region" {
  type    = string
  default = "us-east-2"
}
variable "idm_hostname" {
  type    = string
  default = "idm"
}
# also the R53 zone
variable "domain" {
  type    = string
  default = "example.com"
}

## Cloud Access RHEL
#data "aws_ami" "rhel" {
#  most_recent = true
#  name_regex = "^(RHEL-8.3.0_HVM-)(.*)(Access)*$"
#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }
#  filter {
#    name   = "architecture"
#    values = ["x86_64"]
#  }
#  owners = ["309956199498"] # Red Hat
#}

## AWS Marketplace RHEL
data "aws_ami" "rhel" {
  most_recent = true
  name_regex = "^(RHEL-8.3.0_HVM-)(.*)(Hourly2)*$"
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["309956199498"] # Red Hat
}

data "aws_route53_zone" "zone" {
  name         = var.domain
  private_zone = false
}

data "aws_vpc" "target_vpc" {
  id = var.vpc_id
}

data "aws_subnet" "target_subnet" {
  filter {
    name  = "tag:Name"
    values = ["*public-${var.aws_region}b"]
  }
  filter {
    name  = "availability-zone"
    values = ["${var.aws_region}b"]
  }
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

resource "aws_key_pair" "cluster_ssh_key" {
  key_name   = "${var.idm_hostname}SSHKey"
  public_key = tls_private_key.cluster_new_key.public_key_openssh
}

data "template_file" "ansible_inventory" {
  template = file("./inventory.tpl")
  vars = {
    idm_node = join("\n", formatlist("%s ansible_do_host=%s ansible_internal_private_ip=%s", aws_instance.idm.public_ip, "${var.idm_hostname}.${var.domain}", aws_instance.idm.private_ip))
    ssh_private_file = "../.generated/.${var.idm_hostname}.${var.domain}/priv.pem"
  }
  depends_on = [aws_instance.idm]
}

resource "local_file" "ansible_inventory" {
  content  = data.template_file.ansible_inventory.rendered
  filename = "../.generated/.${var.idm_hostname}.${var.domain}/inventory"

  depends_on = [aws_instance.idm]
}

resource "aws_route53_record" "idm" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.idm_hostname}.${data.aws_route53_zone.zone.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.idm.public_ip]
}

resource "aws_security_group" "idm_sg" {
  name        = "idm_sg"
  description = "Allow idm traffic"
  vpc_id      = data.aws_vpc.target_vpc.id

  tags = {
    Name = "allow_idm"
  }
}

resource "aws_security_group_rule" "allow_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_http_alt" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_dns" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_ntp" {
  type              = "ingress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_udp_kerb_noauth" {
  type              = "ingress"
  from_port         = 88
  to_port           = 88
  protocol          = "udp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_udp_kerb_auth" {
  type              = "ingress"
  from_port         = 464
  to_port           = 464
  protocol          = "udp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_tcp_kerb_noauth" {
  type              = "ingress"
  from_port         = 88
  to_port           = 88
  protocol          = "tcp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_tcp_kerb_auth" {
  type              = "ingress"
  from_port         = 464
  to_port           = 464
  protocol          = "tcp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_tcp_ldap_noauth" {
  type              = "ingress"
  from_port         = 389
  to_port           = 389
  protocol          = "tcp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_security_group_rule" "allow_tcp_ldap_auth" {
  type              = "ingress"
  from_port         = 636
  to_port           = 636
  protocol          = "tcp"
  cidr_blocks      = [data.aws_vpc.target_vpc.cidr_block]
  security_group_id = aws_security_group.idm_sg.id
}

resource "aws_instance" "idm" {
  ami                         = data.aws_ami.rhel.id
  instance_type               = "m5.xlarge"
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.target_subnet.id
  security_groups             = [ aws_security_group.idm_sg.id ]
  key_name                    = aws_key_pair.cluster_ssh_key.key_name

  tags = {
    Name = "idm"
  }
}