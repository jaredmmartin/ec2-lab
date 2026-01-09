############ Local Variables ############

locals {
  name_prefix = "lab"
}

################################ Generators ################################

resource "random_pet" "this" {
  prefix = local.name_prefix
}

############ Data Sources ############

# Find the latest Amazon Linux AMI
data "aws_ami" "this" {
  filter {
    name   = "name"
    values = ["al2023-ami-2023.10.*-kernel-6.1-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  most_recent = true
  owners      = ["137112412989"]
}

data "aws_availability_zone" "a" {
  name = "${data.aws_region.this.region}a"
}

data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

data "aws_service_principal" "ec2" {
  service_name = "ec2"
}

data "aws_subnet" "private0" {
  availability_zone = data.aws_availability_zone.a.id
  filter {
    name   = "tag:type"
    values = ["private"]
  }
  vpc_id = data.aws_vpc.this.id
}

data "aws_subnet" "private1" {
  availability_zone = data.aws_availability_zone.b.id
  filter {
    name   = "tag:type"
    values = ["private"]
  }
  vpc_id = data.aws_vpc.this.id
}

data "aws_vpc" "this" {
  cidr_block = "10.64.0.0/16"
}

data "http" "this" {
  url = "https://myipv4.p1.opendns.com/get_my_ip"
}

############ S3 ############

resource "aws_s3_bucket" "this" {
  bucket        = "${local.name_prefix}-${data.aws_caller_identity.this.account_id}-${data.aws_region.this.region}"
  force_destroy = true
}

resource "aws_s3_object" "this" {
  for_each = fileset("files/s3/", "**")

  bucket      = aws_s3_bucket.this.bucket
  key         = each.value
  source      = "files/s3/${each.value}"
  source_hash = filesha256("files/s3/${each.value}")
}

############ IAM ############

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [data.aws_service_principal.ec2.name]
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.this.account_id]
      variable = "aws:SourceAccount"
    }
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "lab-ec2"
}

data "aws_iam_policy_document" "ec2" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_policy" "ec2" {
  name   = "${local.name_prefix}-ec2"
  policy = data.aws_iam_policy_document.ec2.json
}

resource "aws_iam_policy_attachment" "ec2" {
  name       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.ec2.arn
  roles      = [aws_iam_role.this.name]
}

data "aws_iam_policy" "ssm" {
  name = "AmazonSSMManagedEC2InstanceDefaultPolicy"
}

resource "aws_iam_policy_attachment" "ssm" {
  name       = aws_iam_role.this.name
  policy_arn = data.aws_iam_policy.ssm.arn
  roles      = [aws_iam_role.this.name]
}

resource "aws_iam_instance_profile" "this" {
  name = aws_iam_role.this.name
  role = aws_iam_role.this.name
}

############ EC2 ############

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${local.name_prefix}-${data.aws_region.this.region}-key-pair"
  public_key = tls_private_key.this.public_key_openssh
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.this.private_key_pem}' > ${path.root}/keypair.pem
      chmod 600 ${path.root}/keypair.pem
    EOT
  }
}

resource "aws_security_group" "this" {
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = -1
    to_port     = 0
  }
  ingress {
    cidr_blocks = [
      "${(jsondecode(data.http.this.response_body).ip[*])[0]}/32",
      data.aws_vpc.this.cidr_block,
    ]
    from_port = -1
    protocol  = "icmp"
    to_port   = -1
  }
  ingress {
    cidr_blocks = [
      "${(jsondecode(data.http.this.response_body).ip[*])[0]}/32",
      data.aws_vpc.this.cidr_block,
    ]
    from_port = 22
    protocol  = "tcp"
    to_port   = 22
  }
  name   = "${local.name_prefix}-${data.aws_region.this.region}-sg-ec2"
  vpc_id = data.aws_vpc.this.id
}

resource "aws_instance" "thing_1" {
  ami                         = data.aws_ami.this.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = data.aws_subnet.private0.id
  tags = {
    Name = "${random_pet.this.id}-1"
  }
  user_data              = templatefile("files/userdata.sh", { aws_s3_bucket = aws_s3_bucket.this.bucket })
  vpc_security_group_ids = [aws_security_group.this.id]
}

resource "aws_instance" "thing_2" {
  ami                         = data.aws_ami.this.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = data.aws_subnet.private1.id
  tags = {
    Name = "${random_pet.this.id}-2"
  }
  user_data              = templatefile("files/userdata.sh", { aws_s3_bucket = aws_s3_bucket.this.bucket })
  vpc_security_group_ids = [aws_security_group.this.id]
}

############ EC2 ############

output "ec2_instance_name_1" {
  value = aws_instance.thing_1.tags.Name
}

output "ec2_instance_private_ip_1" {
  value = aws_instance.thing_1.private_ip
}

output "ec2_instance_name_2" {
  value = aws_instance.thing_2.tags.Name
}

output "ec2_instance_private_ip_2" {
  value = aws_instance.thing_2.private_ip
}
