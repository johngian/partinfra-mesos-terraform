provider "aws" {
  region = "${var.region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

# Setup dedicated VPC for mesos cluster
resource "aws_vpc" "mesos" {
  cidr_block = "${var.vpc_cidr_block}"
  enable_dns_hostnames = true
  tags = {
    Name = "mesos"
    Cluster = "mesos-cluster"
  }
}

# Create internet gateway for mesos cluster
resource "aws_internet_gateway" "mesos-gw" {
  vpc_id = "${aws_vpc.mesos.id}"
  tags = {
    Name = "mesos-igw"
    Cluster = "mesos-cluster"
  }
}

# Define public subnet for mesos cluster
resource "aws_subnet" "mesos-public-subnet" {
  vpc_id = "${aws_vpc.mesos.id}"
  cidr_block = "${var.mesos_subnet_cidr_block}"
  map_public_ip_on_launch = true
  tags = {
    Name = "mesos-public-subnet"
    Cluster = "mesos-cluster"
  }
}

# Define routing table for mesos cluster
resource "aws_route_table" "mesos-route-table" {
  vpc_id = "${aws_vpc.mesos.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.mesos-gw.id}"
  }

  tags = {
    Name = "mesos-public-route-table"
    Cluster = "mesos-cluster"
  }
}

# Associate routing table with mesos-public-subnet
resource "aws_route_table_association" "mesos-route-table" {
  subnet_id = "${aws_subnet.mesos-public-subnet.id}"
  route_table_id = "${aws_route_table.mesos-route-table.id}"
}

# Allow all internal VPC traffic
resource "aws_security_group" "mesos-default-sg" {
  name = "mesos-default-sg"
  description = "Allow traffic from mesos-public-subnet."

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${aws_subnet.mesos-public-subnet.cidr_block}"]
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["${aws_subnet.mesos-public-subnet.cidr_block}"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["${aws_subnet.mesos-public-subnet.cidr_block}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.mesos.id}"
}

# Allow OpenVPN traffic to OpenVPN node
resource "aws_security_group" "mesos-openvpn-sg" {
  name = "mesos-openvpn-sg"
  description = "Allow OpenVPN traffic"

  ingress {
    from_port = 1194
    to_port = 1194
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.mesos.id}"
}

# Allow SSH access
resource "aws_security_group" "mesos-ssh-sg" {
  name = "mesos-ssh-sg"
  description = "Allow OpenVPN traffic"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.mesos.id}"
}

# EC2 instances
## OpenVPN node
resource "aws_instance" "mesos-openvpn" {
  depends_on = ["aws_internet_gateway.mesos-gw"]

  ami = "${var.openvpn_ami}"
  instance_type = "${var.openvpn_instance_type}"
  key_name = "${var.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.mesos-ssh-sg.id}",
    "${aws_security_group.mesos-default-sg.id}",
    "${aws_security_group.mesos-openvpn-sg.id}"
  ]

  subnet_id = "${aws_subnet.mesos-public-subnet.id}"

  tags = {
    Name = "mesos-openvpn"
    Cluster = "Mesos"
    Role = "OpenVPN"
  }
}

## Mesos master nodes
resource "aws_instance" "mesos-master" {
  depends_on = ["aws_internet_gateway.mesos-gw"]

  count = 3
  ami = "${var.mesos_master_ami}"
  instance_type = "${var.mesos_master_instance_type}"
  key_name = "${var.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.mesos-default-sg.id}"
  ]

  subnet_id = "${aws_subnet.mesos-public-subnet.id}"
  private_ip = "${lookup(var.master_node_ips, count.index)}"

  tags = {
    Name = "${format("mesos-master%d", count.index)}"
    Cluster = "MesosProd"
    Role = "MesosMaster"
    env = "prod"
    app = "mesosmaster"
  }
}

## Mesos slave nodes
resource "aws_instance" "mesos-slave" {
  depends_on = ["aws_internet_gateway.mesos-gw"]

  count = 3
  ami = "${var.mesos_slave_ami}"
  instance_type = "${var.mesos_slave_instance_type}"
  key_name = "${var.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.mesos-default-sg.id}"
  ]

  subnet_id = "${aws_subnet.mesos-public-subnet.id}"
  private_ip = "${lookup(var.slave_node_ips, count.index)}"

  tags = {
    Name = "${format("mesos-slave%d", count.index)}"
    Cluster = "MesosProd"
    Role = "MesosSlave"
    env = "prod"
    app = "mesosslave"
  }
}

# Assign elastic IP to openvpn node
resource "aws_eip" "openpvn-eip" {
  instance = "${aws_instance.mesos-openvpn.id}"
  vpc = true
}
