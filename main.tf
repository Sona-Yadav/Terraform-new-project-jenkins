provider "aws" {
  region = "us-east-1"
}

variable "regions" {
  default = ["us-east-1a", "us-east-1b"]  # Availability zones
}

# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# Create a public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Create two subnets for the VPC in different Availability Zones
resource "aws_subnet" "subnet" {
  for_each          = toset(var.regions)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = each.key
}

# Associate subnets with the public route table
resource "aws_route_table_association" "public_subnet_assoc" {
  for_each       = aws_subnet.subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a Security Group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpc.id

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

# Create an Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.subnet[*].id
}

# Create a Launch Configuration for Auto Scaling
resource "aws_launch_configuration" "app_lc" {
  name          = "app-lc"
  image_id      = "ami-12345678"  # Replace with a valid AMI ID
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

# Create an Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  desired_capacity     = 2
  max_size             = 2
  min_size             = 2
  vpc_zone_identifier  = aws_subnet.subnet[*].id
  launch_configuration = aws_launch_configuration.app_lc.id
  health_check_type    = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ASG-Instance"
    propagate_at_launch = true
  }
}

# Output Load Balancer DNS
output "lb_dns" {
  value = aws_lb.app_lb.dns_name
}
