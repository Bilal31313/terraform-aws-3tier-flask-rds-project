# -----------------------------------------------------------------------------
# Terraform settings
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {}
}

# -----------------------------------------------------------------------------
# 1. Configure the AWS Provider
# -----------------------------------------------------------------------------
provider "aws" {
  region = "eu-west-2" # London
}

# -----------------------------------------------------------------------------
# 2–17. Networking (VPC, subnets, IGW, NAT, routes)
# -----------------------------------------------------------------------------
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "terraform-3tier-vpc" }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "terraform-3tier-igw" }
}

# Public subnets (AZ a & b)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "terraform-public-subnet-1" }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
  tags                    = { Name = "terraform-public-subnet-2" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "terraform-public-rt" }
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}
resource "aws_route_table_association" "public_subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_subnet_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private subnets (AZ a & b)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"
  tags              = { Name = "terraform-private-subnet-1" }
}
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2b"
  tags              = { Name = "terraform-private-subnet-2" }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "terraform-nat-eip" }
}
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags          = { Name = "terraform-nat-gateway" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "terraform-private-rt" }
}
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main_nat.id
}
resource "aws_route_table_association" "private_subnet_1_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_subnet_2_assoc" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# -----------------------------------------------------------------------------
# 18–19. Compute tier (EC2 + SG)
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "terraform-alb-sg"
  description = "Allow inbound HTTP"
  vpc_id      = aws_vpc.main_vpc.id

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
  tags = { Name = "terraform-alb-sg" }
}

resource "aws_security_group" "ec2_sg" {
  name        = "terraform-ec2-sg"
  description = "Allow app port from ALB"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "terraform-ec2-sg" }
}

resource "aws_instance" "flask_app_server" {
  ami                         = "ami-0a94c8e4ca2674d5a" # Ubuntu 22.04
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false

  user_data = <<EOF
#!/bin/bash
set -e
apt-get update -y
apt-get install -y python3-pip
pip3 install flask

cat <<'APP' > /home/ubuntu/app.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from Terraform EC2 Flask App!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
APP

nohup python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &
EOF

  tags = { Name = "terraform-flask-app-server" }
}

# -----------------------------------------------------------------------------
# 20–23. Application Load Balancer
# -----------------------------------------------------------------------------
resource "aws_lb" "flask_alb" {
  name               = "terraform-flask-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  tags               = { Name = "terraform-flask-alb" }
}

resource "aws_lb_target_group" "flask_tg" {
  name        = "flask-target-group"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = "5000"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "flask_attachment" {
  target_group_arn = aws_lb_target_group.flask_tg.arn
  target_id        = aws_instance.flask_app_server.id
  port             = 5000
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.flask_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
}

# -----------------------------------------------------------------------------
# 24–27. Database (RDS PostgreSQL)
# -----------------------------------------------------------------------------
variable "db_password" {
  description = "Master password for RDS (demo only)"
  type        = string
  sensitive   = true
}

resource "aws_security_group" "rds_sg" {
  name        = "terraform-rds-sg"
  description = "Allow Postgres from EC2 SG"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "terraform-rds-sg" }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "terraform-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags       = { Name = "terraform-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier             = "terraform-postgres-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13.15"
  instance_class         = "db.t3.micro"
  username               = "postgresadmin"
  password               = var.db_password # demo only – use Secrets Manager in prod
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  storage_type           = "gp2"
  tags                   = { Name = "terraform-postgres-db" }
}

# -----------------------------------------------------------------------------
# 28. Outputs
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.flask_alb.dns_name
}
