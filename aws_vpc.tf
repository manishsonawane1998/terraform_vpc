provider "aws" {
region = "us-east-1"
access_key = "+++"
secret_key = "+++++"
token = "+++++++++++++"
}
resource "aws_vpc" "main" {
cidr_block = "20.20.0.0/16"
tags = {
Name = "testvpc"
}
}
resource "aws_subnet" "public" {
availability_zone = "us-east-1a"
vpc_id = aws_vpc.main.id
cidr_block = "20.20.1.0/24"
map_public_ip_on_launch = "true"
tags = {
Name = "public"
}
}
resource "aws_subnet" "private" {
availability_zone = "us-east-1b"
vpc_id = aws_vpc.main.id
cidr_block = "20.20.2.0/24"
map_public_ip_on_launch = "true"
tags = {
Name = "private"
}
}
resource "aws_internet_gateway" "gw" {
vpc_id = aws_vpc.main.id
tags = {
Name = "testgw"
}
}
resource "aws_route_table" "route" {
vpc_id = aws_vpc.main.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id
}
tags = {
Name = "publicroute"
}
}
resource "aws_route_table_association" "a1" {
subnet_id = aws_subnet.public.id
route_table_id = aws_route_table.route.id
}
resource "aws_eip" "eip" {
vpc = "true"
}
resource "aws_nat_gateway" "natgw" {
allocation_id = aws_eip.eip.id
subnet_id = aws_subnet.public.id
tags = {
Name = "testnat"
}
}
resource "aws_route_table" "privateroute" {
vpc_id = aws_vpc.main.id
route {
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.natgw.id
}
tags = {
Name = "privateroute"
}
}
resource "aws_route_table_association" "a2" {
subnet_id = aws_subnet.private.id
route_table_id = aws_route_table.privateroute.id
}



## Security Group##
resource "aws_security_group" "TestSG" {
  description = "Allow traffic"
  vpc_id      = aws_vpc.main.id
  name        = "TestSG"

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
  }


  tags = {
    Name = "TestSG"
  }
}




# To create ec2 instance (public)

resource "aws_instance" "Publicserver" {
    ami = "ami-0742b4e673072066f"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.TestSG.id]
    subnet_id = aws_subnet.public.id
    key_name               = "terraform_demo"
    associate_public_ip_address = true
    tags = {
      Name              = "Publicserver"
    }
}


# To create ec2 instance (Private)

resource "aws_instance" "Privateserver" {
    ami = "ami-0742b4e673072066f"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.TestSG.id]
    subnet_id = aws_subnet.private.id
    key_name               = "terraform_demo"
    associate_public_ip_address = false
    tags = {
      Name              = "Privateserver"
    }
}



#  for creating ALB

resource "aws_lb" "my-test-lb" {
  name               = "my-test-lb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.private.id]
  #enable_deletion_protection = true

}

resource "aws_lb_target_group" "my-alb-tg" {
  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  name        = "my-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
}

resource "aws_lb_target_group_attachment" "my-tg-attachment1" {
  target_group_arn = aws_lb_target_group.my-alb-tg.arn
  target_id        = aws_instance.Publicserver.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "my-tg-attachment2" {
  target_group_arn = aws_lb_target_group.my-alb-tg.arn
  target_id        = aws_instance.Privateserver.id
  port             = 80
}

resource "aws_security_group" "alb-sg" {
  name   = "my-alb-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "http_allow" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb-sg.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "all_outbound_access" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb-sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

