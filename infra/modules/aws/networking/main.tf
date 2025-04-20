resource "aws_vpc" "cloud_ops_manager_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cloud_ops_manager_vpc"
  }
}

resource "aws_subnet" "cloud_ops_manager_public_subnet_a" {
  vpc_id                  = aws_vpc.cloud_ops_manager_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloud_ops_manager_public_subnet_a"
  }
}

resource "aws_subnet" "cloud_ops_manager_public_subnet_b" {
  vpc_id                  = aws_vpc.cloud_ops_manager_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloud_ops_manager_public_subnet_b"
  }
}

resource "aws_subnet" "cloud_ops_manager_private_subnet_a" {
  vpc_id            = aws_vpc.cloud_ops_manager_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "cloud_ops_manager_private_subnet_a"
  }
}

resource "aws_subnet" "cloud_ops_manager_private_subnet_b" {
  vpc_id            = aws_vpc.cloud_ops_manager_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "cloud_ops_manager_private_subnet_b"
  }
}

resource "aws_internet_gateway" "cloud_ops_manager_igw" {
  vpc_id = aws_vpc.cloud_ops_manager_vpc.id
}

resource "aws_eip" "cloud_ops_manager_nat_a" {
  tags = {
    Name = "cloud_ops_manager_nat_a"
  }
}

resource "aws_eip" "cloud_ops_manager_nat_b" {
  tags = {
    Name = "cloud_ops_manager_nat_b"
  }
}

resource "aws_nat_gateway" "cloud_ops_manager_nat_gateway_a" {
  allocation_id     = aws_eip.cloud_ops_manager_nat_a.id
  subnet_id         = aws_subnet.cloud_ops_manager_public_subnet_a.id
}

resource "aws_nat_gateway" "cloud_ops_manager_nat_gateway_b" {
  allocation_id     = aws_eip.cloud_ops_manager_nat_b.id
  subnet_id         = aws_subnet.cloud_ops_manager_public_subnet_b.id
}

resource "aws_route_table" "cloud_ops_manager_public_route_table" {
  vpc_id = aws_vpc.cloud_ops_manager_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_ops_manager_igw.id
  }
}

resource "aws_route_table" "cloud_ops_manager_private_route_table_a" {
  vpc_id = aws_vpc.cloud_ops_manager_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cloud_ops_manager_nat_gateway_a.id
  }
}

resource "aws_route_table" "cloud_ops_manager_private_route_table_b" {
  vpc_id = aws_vpc.cloud_ops_manager_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cloud_ops_manager_nat_gateway_b.id
  }
}

resource "aws_route_table_association" "cloud_ops_manager_public_association_a" {
  subnet_id      = aws_subnet.cloud_ops_manager_public_subnet_a.id
  route_table_id = aws_route_table.cloud_ops_manager_public_route_table.id
}

resource "aws_route_table_association" "cloud_ops_manager_public_association_b" {
  subnet_id      = aws_subnet.cloud_ops_manager_public_subnet_b.id
  route_table_id = aws_route_table.cloud_ops_manager_public_route_table.id
}

resource "aws_route_table_association" "cloud_ops_manager_private_association_a" {
  subnet_id      = aws_subnet.cloud_ops_manager_private_subnet_a.id
  route_table_id = aws_route_table.cloud_ops_manager_private_route_table_a.id
}

resource "aws_route_table_association" "cloud_ops_manager_private_association_b" {
  subnet_id      = aws_subnet.cloud_ops_manager_private_subnet_b.id
  route_table_id = aws_route_table.cloud_ops_manager_private_route_table_b.id
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.cloud_ops_manager_private_subnet_a.id, aws_subnet.cloud_ops_manager_private_subnet_b.id]

  tags = {
    Name = "rds-subnet-group"
  }
}