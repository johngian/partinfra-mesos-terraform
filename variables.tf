variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "key_name" {}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "mesos_subnet_cidr_block" {
  default = "10.0.0.0/24"
}

variable "openvpn_ami" {}
variable "openvpn_instance_type" {}
variable "openvpn_node_ip" {
  default = "10.0.0.4"
}

variable "mesos_master_ami" {}
variable "mesos_master_instance_type" {}
variable "master_node_ips" {
  default = {
    "0" = "10.0.0.5"
    "1" = "10.0.0.6"
    "2" = "10.0.0.7"
  }
}

variable "mesos_slave_ami" {}
variable "mesos_slave_instance_type" {}

variable "slave_node_ips" {
  default = {
    "0" = "10.0.0.8"
    "1" = "10.0.0.9"
    "2" = "10.0.0.10"
  }
}
