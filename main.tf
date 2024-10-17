provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

variable "regions" {
  default = ["us-east-1", "us-west-2"]
}

resource "aws_vpc" "vpc" {
  for_each   = toset(var.regions)
  provider   = aws.${each.key}
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  for_each           = aws_vpc.vpc
  provider           = aws.${each.key}
  vpc_id             = each.value.id
  cidr_block         = "10.0.1.0/24"
  availability_zone  = "${each.key}a"
}

resource "aws_security_group" "lb_sg" {
  for_each    = aws_vpc.vpc
  provider    = aws.${each.key}
  name        = "lb_sg-${each.key}"
  description = "Allow web traffic"
  vpc_id      = each.value.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app_lb" {
  for_each            = aws_vpc.vpc
  provider            = aws.${each.key}
  name                = "app-lb-${each.key}"
  internal            = false
  load_balancer_type  = "application"
  security_groups     = [aws_security_group.lb_sg[each.key].id]
  subnets             = [aws_subnet.subnet[each.key].id]
}

resource "aws_launch_configuration" "app_lc" {
  for_each      = aws_vpc.vpc
  provider      = aws.${each.key}
  name          = "app-lc-${each.key}"
  image_id      = "ami-12345678" # Update with a valid AMI ID
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "asg" {
  for_each              = aws_vpc.vpc
  provider              = aws.${each.key}
  desired_capacity      = 2
  max_size              = 2
  min_size              = 2
  vpc_zone_identifier   = [aws_subnet.subnet[each.key].id]
  launch_configuration  = aws_launch_configuration.app_lc[each.key].id
}

output "lb_dns" {
  value = aws_lb.app_lb[*].dns_name
}
