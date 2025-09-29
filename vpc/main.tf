############ Local Variables ############

locals {
  name_prefix = "lab"
}

############ Data Sources ############

data "aws_availability_zone" "a" {
  name = "${data.aws_region.this.region}a"
}

data "aws_availability_zone" "b" {
  name = "${data.aws_region.this.region}b"
}

data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

data "aws_service_principal" "ec2" {
  service_name = "ec2"
}

############ VPC ############

resource "aws_vpc" "this" {
  cidr_block           = "10.64.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-vpc"
  }
}

locals {
  usw2_subnets = cidrsubnets(aws_vpc.this.cidr_block, 8, 8, 8, 8)
}

resource "aws_subnet" "public0" {
  availability_zone = data.aws_availability_zone.a.name
  cidr_block        = local.usw2_subnets[0]
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-subnet-public-0"
    "type" = "public"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "public1" {
  availability_zone = data.aws_availability_zone.b.name
  cidr_block        = local.usw2_subnets[1]
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-subnet-public-1"
    "type" = "public"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "private0" {
  availability_zone = data.aws_availability_zone.a.name
  cidr_block        = local.usw2_subnets[2]
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-subnet-private-0"
    "type" = "private"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "private1" {
  availability_zone = data.aws_availability_zone.b.name
  cidr_block        = local.usw2_subnets[3]
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-subnet-private-1"
    "type" = "private"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_internet_gateway" "this" {
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-igw"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_eip" "this" {
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-eip-ngw"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public0.id
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-ngw"
  }
}

resource "aws_route_table" "private" {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-rtb-private"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    "Name" = "${local.name_prefix}-${data.aws_region.this.region}-rtb-public"
  }
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table_association" "private0" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private0.id
}

resource "aws_route_table_association" "private1" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private1.id
}

resource "aws_route_table_association" "public0" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public0.id
}

resource "aws_route_table_association" "public1" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public1.id
}

############ VPC Endpoints ############

resource "aws_security_group" "this" {
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = -1
    to_port     = 0
  }
  ingress {
    cidr_blocks = [aws_vpc.this.cidr_block]
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
  }
  name   = "${local.name_prefix}-${data.aws_region.this.region}-sg-vpce"
  vpc_id = aws_vpc.this.id
}

resource "aws_vpc_endpoint" "ec2" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.this.id]
  service_name        = "com.amazonaws.${data.aws_region.this.region}.ec2"
  subnet_ids          = [aws_subnet.private0.id, aws_subnet.private1.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.this.id
}

resource "aws_vpc_endpoint" "ec2messages" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.this.id]
  service_name        = "com.amazonaws.${data.aws_region.this.region}.ec2messages"
  subnet_ids          = [aws_subnet.private0.id, aws_subnet.private1.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.this.id
}

resource "aws_vpc_endpoint" "s3" {
  route_table_ids = [aws_route_table.private.id]
  service_name    = "com.amazonaws.${data.aws_region.this.region}.s3"
  vpc_id          = aws_vpc.this.id
}

resource "aws_vpc_endpoint" "ssm" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.this.id]
  service_name        = "com.amazonaws.${data.aws_region.this.region}.ssm"
  subnet_ids          = [aws_subnet.private0.id, aws_subnet.private1.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.this.id
}

resource "aws_vpc_endpoint" "ssmmessages" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.this.id]
  service_name        = "com.amazonaws.${data.aws_region.this.region}.ssmmessages"
  subnet_ids          = [aws_subnet.private0.id, aws_subnet.private1.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.this.id
}
