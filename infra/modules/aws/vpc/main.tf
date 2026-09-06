# The platform's only VPC: two public and two private subnets across the given
# availability zones, a NAT gateway for private egress, and interface endpoints
# for the AWS services workloads call.
#
# Every other stack consumes this network by reading the SSM parameters written
# in ssm.tf, never by reading this module's state.

locals {
  az_count             = length(var.availability_zones)
  public_subnet_count  = length(var.public_subnet_cidrs)
  private_subnet_count = length(var.private_subnet_cidrs)

  common_tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# The kubernetes.io/role tags are what the AWS Load Balancer Controller looks
# for when choosing subnets: /elb for internet-facing load balancers on the
# public subnets, /internal-elb for internal ones on the private subnets.
resource "aws_subnet" "public" {
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[count.index % local.az_count]

  tags = merge(var.tags, local.common_tags, {
    Name                     = "${var.project}-${var.environment}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_subnets" {
  count          = local.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Fargate pods and the internal NLB run here. Nothing in the private subnets
# receives inbound traffic from the internet.
resource "aws_subnet" "private" {
  count             = local.private_subnet_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % local.az_count]

  tags = merge(var.tags, local.common_tags, {
    Name                              = "${var.project}-${var.environment}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-private-rt"
  })
}

resource "aws_route_table_association" "private_subnets" {
  count          = local.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Outbound internet for the private subnets. Fargate needs it to pull images
# from registries that have no VPC endpoint and to reach third-party APIs such
# as GitHub and Datadog. A single NAT gateway is a deliberate cost trade-off: it
# is a per-AZ single point of failure that a production network would duplicate.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# Interface endpoints below keep AWS API calls from the private subnets on the
# AWS network instead of routing them through the NAT gateway, which both
# reduces data processing charges and keeps the traffic off the public internet.
resource "aws_security_group" "endpoints" {
  name        = "${var.project}-${var.environment}-vpce-sg"
  description = "Allow VPC endpoint traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "TLS from inside the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    description = "Endpoint responses"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-sg"
  })
}

# Reached by the API publishing provision requests and the provisioner consuming
# them.
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-sqs"
  })
}

# Image pulls need both ECR endpoints: ecr.api for authentication and metadata,
# ecr.dkr for the layer transfers. Layers themselves come from S3, which is why
# the S3 gateway endpoint below is also required for pulls to stay off the NAT.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-ecr-api"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-ecr-dkr"
  })
}

# Used by Fargate log routing and by the workloads' own log writes.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-logs"
  })
}

# Workloads resolve their configuration from Parameter Store at startup, so this
# endpoint is on the boot path for every service.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-ssm"
  })
}

# A gateway endpoint, so it attaches to the route table rather than to subnets
# and costs nothing. Required for ECR image layers, which are stored in S3.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(var.tags, local.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-s3"
  })
}
