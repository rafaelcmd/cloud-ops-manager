resource "aws_vpc" "cloud_ops_manager_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "cloud_ops_manager_public_subnet" {
  vpc_id                  = aws_vpc.cloud_ops_manager_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "cloud_ops_manager_igw" {
  vpc_id = aws_vpc.cloud_ops_manager_vpc.id
}

resource "aws_route_table" "cloud_ops_manager_public_route_table" {
  vpc_id = aws_vpc.cloud_ops_manager_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_ops_manager_igw.id
  }
}

resource "aws_route_table_association" "cloud_ops_manager_public_association" {
  subnet_id      = aws_subnet.cloud_ops_manager_public_subnet.id
  route_table_id = aws_route_table.cloud_ops_manager_public_route_table.id
}