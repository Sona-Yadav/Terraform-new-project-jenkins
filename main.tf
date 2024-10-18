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

# Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# Route table to make the subnet public
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate subnets with the public route table
resource "aws_route_table_association" "public_subnet_assoc" {
  for_each       = aws_subnet.subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# Replace aws_launch_configuration with aws_launch_template
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-lt"
  image_name      = "ubuntu"  # Replace with a valid AMI ID
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [for subnet in aws_subnet.subnet : subnet.id]
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  desired_capacity     = 2
  max_size             = 2
  min_size             = 2

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}

output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}
