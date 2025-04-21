# 1. Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"   # London region
}

# 2. Create a new VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-3tier-vpc"
  }
}

# 3. Create an Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "terraform-3tier-igw"
  }
}

# 4. Create Public Subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"

  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet-1"
  }
}

# 5. Create Public Subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"

  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet-2"
  }
}

# 6. Create Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "terraform-public-rt"
  }
}

# 7. Create a Route to Internet via IGW
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# 8. Associate Public Subnet 1 with Public Route Table
resource "aws_route_table_association" "public_subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

# 9. Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_subnet_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 10. Create Private Subnet 1 (App Server)
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-2a"

  map_public_ip_on_launch = false

  tags = {
    Name = "terraform-private-subnet-1"
  }
}

# 11. Create Private Subnet 2 (Database)
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-west-2b"

  map_public_ip_on_launch = false

  tags = {
    Name = "terraform-private-subnet-2"
  }
}

# 12. Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "terraform-nat-eip"
  }
}

# 13. Create NAT Gateway
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "terraform-nat-gateway"
  }
}

# 14. Create Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "terraform-private-rt"
  }
}

# 15. Create Route for Private Subnets to use NAT
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main_nat.id
}

# 16. Associate Private Subnet 1 with Private Route Table
resource "aws_route_table_association" "private_subnet_1_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

# 17. Associate Private Subnet 2 with Private Route Table
resource "aws_route_table_association" "private_subnet_2_assoc" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# 18. Create Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "terraform-ec2-sg"
  description = "Allow HTTP from ALB"
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

  tags = {
    Name = "terraform-ec2-sg"
  }
}

# 19. Create EC2 instance to host Flask App
resource "aws_instance" "flask_app_server" {
  ami                         = "ami-0a94c8e4ca2674d5a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false

  user_data = <<-EOF
#!/bin/bash
set -e

sudo apt-get update -y
sudo apt-get install -y python3-pip
pip3 install flask

cd /home/ubuntu/

cat <<EOL > app.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from Terraform EC2 Flask App!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
EOL

nohup python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &
EOF

  tags = {
    Name = "terraform-flask-app-server"
  }
}

# 20. Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "terraform-alb-sg"
  description = "Allow HTTP inbound traffic"
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

  tags = {
    Name = "terraform-alb-sg"
  }
}

# 21. Target Group for Flask EC2
resource "aws_lb_target_group" "flask_target_group" {
  name        = "flask-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 22. Attach EC2 instance to Target Group
resource "aws_lb_target_group_attachment" "flask_attachment" {
  target_group_arn = aws_lb_target_group.flask_target_group.arn
  target_id        = aws_instance.flask_app_server.id
  port             = 80
}

# 23. Create ALB
resource "aws_lb" "flask_alb" {
  name               = "terraform-flask-alb"
  internal           = false  # public facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "terraform-flask-alb"
  }
}

# 26. Create Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "terraform-rds-sg"
  description = "Allow PostgreSQL access from Flask EC2 only"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "PostgreSQL from Flask EC2 SG"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups  = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-rds-sg"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "terraform-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "terraform-db-subnet-group"
  }
}

# 23. Create RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier             = "terraform-postgres-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13.15"
  instance_class         = "db.t3.micro"
  username               = "postgresadmin"
  password               = "MySecurePassword123!"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  storage_type           = "gp2"

  tags = {
    Name = "terraform-postgres-db"
  }
}
