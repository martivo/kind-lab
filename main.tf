variable "tutor-ssh-key" {
  default     = "martivo-x220"
  type        = string
  description = "The AWS ssh key to use."
}

variable "aws-region" {
  default     = "eu-central-1"
  type        = string
  description = "The AWS Region to deploy EKS"
}

variable "kind-instance-type" {
  default     = "t3.2xlarge"
  type        = string
  description = "Worker Node EC2 instance type"
}

variable "students" {
  default     = 2
  type        = string
  description = "Number of students"
}

variable "dns" {
  default     = "Z00099462ROKZ61HQFQTA"
  type        = string
  description = "Route53 dns zone identifier"
}

variable "registry-host" {
  default     = "kreg"
  type        = string
  description = "Registry hostname to use. Will be a subdomain of dns variable."
}

provider "aws" {
  region = var.aws-region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.48.0"
    }
  }
}
resource "aws_vpc" "main" {
  cidr_block = "10.129.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
     "Name" = "lab-kind-vpc"
    }
}

data "aws_availability_zone" "a" {
  name = "${var.aws-region}a"
}

data "aws_availability_zone" "b" {
  name = "${var.aws-region}b"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "aws_ami" "ubuntu-server" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
      name   = "architecture"
      values = ["x86_64"]
  }
}

data "aws_route53_zone" "dns" {
  zone_id = var.dns
}



resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.129.0.0/24"
  availability_zone_id = data.aws_availability_zone.a.zone_id
  map_public_ip_on_launch = true

  tags = {
     "Name" = "lab-public-a",
     "kubernetes.io/cluster/lab" = "shared",
     "kubernetes.io/role/internal-elb" = "0",
    }
}

resource "aws_subnet" "public-b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.129.1.0/24"
  availability_zone_id = data.aws_availability_zone.b.zone_id
  map_public_ip_on_launch = true

  tags = {
     "Name" = "lab-public-b",
     "kubernetes.io/cluster/lab" = "shared",
     "kubernetes.io/role/internal-elb" = "0",
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat-a" {
  vpc      = true
}


resource "aws_nat_gateway" "gw-a" {
  allocation_id = aws_eip.nat-a.id
  subnet_id     = aws_subnet.public-a.id
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "lab-gw-a"
  }
}


resource "aws_route_table" "r-public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "lab-r-public"
  }
}

resource "aws_route_table_association" "ra-public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r-public.id
}

resource "aws_route_table_association" "ra-public-b" {
  subnet_id      = aws_subnet.public-b.id
  route_table_id = aws_route_table.r-public.id
}

resource "aws_subnet" "private-app-a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.129.4.0/24"
  availability_zone_id = data.aws_availability_zone.a.zone_id
  tags = {
     "Name" = "lab-private-app-a"
    }
}



resource "aws_route_table" "r-private-a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw-a.id
  }
  tags = {
    Name = "lab-r-private-a"
  }
}



resource "aws_route_table_association" "ra-app-a" {
  subnet_id      = aws_subnet.private-app-a.id
  route_table_id = aws_route_table.r-private-a.id
}


resource "aws_security_group" "allow_all" {
  name = "koolitus-kind_all"
  description = "Allow ALL traffic from and to ANY Source"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
   "Name" = "koolitus-kind ALL"
  }
}


resource "aws_instance" "kind" {
    count = var.students
    ami           = data.aws_ami.ubuntu-server.id
    instance_type = var.kind-instance-type
    subnet_id = aws_subnet.public-a.id
    vpc_security_group_ids = [aws_security_group.allow_all.id]
    key_name = var.tutor-ssh-key
    root_block_device {
      volume_size = "200"
    }
    tags = {
      "Name" = "kind-${count.index + 1}"
    }
    provisioner "file" {
      source      = "install-dependencies.sh"
      destination = "/home/ubuntu/install-dependencies.sh"
    }
    provisioner "remote-exec" {
      inline = ["chmod +x /home/ubuntu/*.sh", "sudo /home/ubuntu/install-dependencies.sh ${count.index + 1}"]
    }
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      host = "${self.public_ip}"
    }
}

resource "aws_route53_record" "kind" {
  count = var.students
  zone_id = var.dns
  name = "kind-${count.index + 1}"
  type = "A"
  ttl = 60
  records = [aws_instance.kind[count.index].public_ip]
}

resource "aws_route53_record" "argocd-prod" {
  count = var.students
  zone_id = var.dns
  name = "argocd-prod-${count.index + 1}"
  type = "A"
  ttl = 60
  records = [aws_instance.kind[count.index].public_ip]
}

resource "aws_route53_record" "argocd-test" {
  count = var.students
  zone_id = var.dns
  name = "argocd-test-${count.index + 1}"
  type = "A"
  ttl = 60
  records = [aws_instance.kind[count.index].public_ip]
}

resource "aws_route53_record" "web-prod" {
  count = var.students
  zone_id = var.dns
  name = "web-prod-${count.index + 1}"
  type = "A"
  ttl = 60
  records = [aws_instance.kind[count.index].public_ip]
}

resource "aws_route53_record" "web-test" {
  count = var.students
  zone_id = var.dns
  name = "web-test-${count.index + 1}"
  type = "A"
  ttl = 60
  records = [aws_instance.kind[count.index].public_ip]
}

resource "aws_route53_record" "registry" {
  zone_id = var.dns
  name = "kreg"
  type = "A"
  alias {
    name                   = aws_lb.registry.dns_name
    zone_id                = aws_lb.registry.zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "registry" {
  domain_name       = "${var.registry-host}.${data.aws_route53_zone.dns.name}"
  validation_method = "DNS"
}


resource "aws_route53_record" "registry-validate" {
  name            = aws_acm_certificate.registry.domain_validation_options.*.resource_record_name[0]
  records         = [aws_acm_certificate.registry.domain_validation_options.*.resource_record_value[0]]
  type            = aws_acm_certificate.registry.domain_validation_options.*.resource_record_type[0]
  zone_id         = data.aws_route53_zone.dns.zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "registry" {
  certificate_arn         = aws_acm_certificate.registry.arn
}

resource "aws_lb" "registry" {
  name               = "kind-registry"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_all.id]
  subnets            = [aws_subnet.public-a.id,aws_subnet.public-b.id]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "httptohttps" {
  load_balancer_arn = aws_lb.registry.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}



resource "aws_lb_listener" "registry" {
  load_balancer_arn = aws_lb.registry.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate_validation.registry.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.registry.arn
  }
}


resource "aws_lb_target_group" "registry" {
  name     = "kind-jump-registry"
  port     = 8080
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.main.id
}


resource "aws_autoscaling_attachment" "asg_attachment_registry" {
  autoscaling_group_name = aws_autoscaling_group.registry.id
  alb_target_group_arn   = aws_lb_target_group.registry.arn
}

data "local_file" "registry" {
  filename = "install-registry.sh"
}

resource "aws_launch_configuration" "registry" {
  image_id                    = data.aws_ami.ubuntu-server.id
  instance_type               = "t3.small"
  name_prefix                 = "kind-registry"
  security_groups             = [aws_security_group.allow_all.id]
  user_data_base64            = data.local_file.registry.content_base64
  key_name                    = var.tutor-ssh-key
  lifecycle {
    create_before_destroy = true
  }
  root_block_device { 
    volume_size                 = 50
    volume_type                 = "gp3"
  }
}

resource "aws_autoscaling_group" "registry" {
  desired_capacity     = "1"
  launch_configuration = aws_launch_configuration.registry.id
  max_size             = "1"
  min_size             = "1"
  name                 = "koolitus-kind-registry-asg"
  vpc_zone_identifier  = [aws_subnet.public-a.id]
  depends_on = [aws_launch_configuration.registry]
  
  tag {
    key                 = "Name"
    value               = "koolitus-kind-registry"
    propagate_at_launch = true
  }
  lifecycle {
     ignore_changes = [ target_group_arns ]
  }
}

data "aws_instances" "registry" {
  instance_tags = {
    "Name" = "koolitus-kind-registry"
  }
  depends_on = [
    aws_autoscaling_group.registry 
  ]
}

resource "aws_route53_record" "registry-mgmt" {
  zone_id = var.dns
  name = "kind-mgmt"
  type = "A"
  ttl = 60
  records = data.aws_instances.registry.public_ips
}
