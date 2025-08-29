provider "aws" {
  region = "eu-central-1" # change if you want
}

# VPC
resource "aws_vpc" "mvp" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "mvp-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.mvp.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "mvp-subnet-public" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mvp.id
  tags = { Name = "mvp-igw" }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.mvp.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "mvp-route" }
}

resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.r.id
}

# Security Group
resource "aws_security_group" "mvp_sg" {
  name        = "mvp-sg"
  description = "Allow SSH, HTTP, HTTPS"
  vpc_id      = aws_vpc.mvp.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["<YOUR_PUBLIC_IP>/32"]  # lock SSH to your IP
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "mvp-sg" }
}

# Key pair note: create key in AWS console or use existing
# Assumes you created key pair <YOUR_KEY_NAME> in the region
variable "key_name" {
  default = "<YOUR_KEY_NAME>"
}

# IAM role & policies for instance (minimal for ECR/S3 access)
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "mvp-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
resource "aws_iam_role_policy_attachment" "ec2_s3" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "mvp-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 instance
resource "aws_instance" "mvp" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.mvp_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  tags = { Name = "mvp-ec2" }

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Instance ready'"
    ]
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("<PATH_TO_YOUR_PRIVATE_KEY>")
      host = self.public_ip
    }
  }
}

# get ubuntu ami
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Elastic IP
resource "aws_eip" "ip" {
  instance = aws_instance.mvp.id
  vpc = true
}

# ECR repo (one repo for MVP)
resource "aws_ecr_repository" "mvp_repo" {
  name = "mvp-service"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# S3 bucket for artifacts
resource "aws_s3_bucket" "mvp_bucket" {
  bucket = "mvp-artifacts-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
  force_destroy = true
}

data "aws_caller_identity" "current" {}

output "ec2_public_ip" {
  value = aws_eip.ip.public_ip
}

output "ecr_repo_url" {
  value = aws_ecr_repository.mvp_repo.repository_url
}

output "s3_bucket" {
  value = aws_s3_bucket.mvp_bucket.bucket
}
