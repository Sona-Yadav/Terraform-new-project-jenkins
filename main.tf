provider "aws" {
  region = "us-east-1"  # You can modify to your preferred region
}

variable "azs" {
  default = ["us-east-1a", "us-east-1b"]
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "subnet" {
  for_each          = toset(var.azs)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, each.key == "us-east-1a" ? 1 : 2)
  availability_zone = each.key
  tags = {
    Name = "subnet-${each.key}"
  }
}

resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "lb_sg"
  description = "Allow web traffic"

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

  tags = {
    Name = "lb-sg"
  }
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for subnet in aws_subnet.subnet : subnet.id]

  tags = {
    Name = "app-lb"
  }
}

resource "aws_launch_configuration" "app_lc" {
  name          = "app-lc"
  image_id      = "ami-12345678"  # Replace with valid AMI ID
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [for subnet in aws_subnet.subnet : subnet.id]
  launch_configuration = aws_launch_configuration.app_lc.id
  desired_capacity     = 2
  max_size             = 2
  min_size             = 2

}

output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}
