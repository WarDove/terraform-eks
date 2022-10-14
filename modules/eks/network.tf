# Subnet cidr locals
locals {
  private_cidrs = [for i in range(1, 16, 2) : cidrsubnet(var.vpc_cidr, 8, i)]
  public_cidrs  = [for i in range(2, 16, 2) : cidrsubnet(var.vpc_cidr, 8, i)]
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# IGW
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Internet facing NGW and EIP
resource "aws_eip" "ngw_eip" {
  count = var.az_count
  vpc   = true
  tags = {
    Name = "${var.cluster_name}-eip-${var.az_names[count.index]}"
  }
}

resource "aws_nat_gateway" "public_ngw" {
  count         = var.az_count
  allocation_id = aws_eip.ngw_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id

  tags = {
    Name = "${var.cluster_name}-ngw-${var.az_names[count.index]}"
  }

  depends_on = [aws_internet_gateway.main_igw, aws_eip.ngw_eip]
}

# Route Tables
resource "aws_default_route_table" "rt_main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = {
    Name = "${var.cluster_name}-main-rt"
  }
}

resource "aws_route_table" "public_rt" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

resource "aws_route" "ngw_route" {
  count                  = var.az_count
  route_table_id         = aws_route_table.private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public_ngw[count.index].id
  depends_on             = [aws_route_table.private_rt, aws_nat_gateway.public_ngw]
}

resource "aws_route_table_association" "public_rta" {
  count          = var.az_count
  subnet_id      = aws_subnet.public_subnet.*.id[count.index] #alternative aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt[count.index].id
}

resource "aws_route_table_association" "private_rta" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_subnet.*.id[count.index]
  route_table_id = aws_route_table.private_rt[count.index].id
}

# Subnets
resource "aws_subnet" "private_subnet" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = var.az_names[count.index]
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
    Name                                        = "${upper(substr(var.az_names[count.index], -1, 1))} private | ${var.cluster_name}-subnet"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.az_names[count.index]
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
    Name                                        = "${upper(substr(var.az_names[count.index], -1, 1))} public | ${var.cluster_name}-subnet"
  }
}

# Security groups
resource "aws_security_group" "private" {
  name        = "${var.cluster_name}-private-sg"
  description = "Security group for private resources"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "public" {
  name        = "${var.cluster_name}-public-sg"
  description = "Security group for public resources"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}