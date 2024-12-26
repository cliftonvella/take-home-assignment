data "aws_availability_zones" "zone" {}

data "aws_key_pair" "key" {
  key_name = "clif-sandbox-master"
}

resource "aws_instance" "bastion" {
  count                       = var.az_count
  ami                         = lookup(var.ami_ids, "bastion", null)
  instance_type               = lookup(var.instance_types, "bastion", var.default_instance_type)
  availability_zone           = data.aws_availability_zones.zone.names[count.index]
  subnet_id                   = module.lb_subnets.subnets[count.index].id
  associate_public_ip_address = "true"
  key_name                    = data.aws_key_pair.key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_ec2_public.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  tags = {
    Name = "bastion-${var.env_alias[var.env]}-${data.aws_availability_zones.zone.names[count.index]}"
  }
}

#Static IP for bastions
resource "aws_eip" "bastion" {
  count    = length(aws_instance.bastion)
  instance = aws_instance.bastion[count.index].id
  domain   = "vpc"
}

# Make a public dns record for the bastion(s)
resource "aws_route53_record" "bastion_public" {
  name    = "bastion"
  type    = "A"
  ttl     = 60
  records = aws_instance.bastion[*].public_ip
  zone_id = aws_route53_zone.sandbox-public.zone_id
}

resource "aws_route53_record" "bastion_public_instance" {
  count   = var.az_count
  name    = "bastion-${count.index}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.bastion[count.index].public_ip]
  zone_id = aws_route53_zone.sandbox-public.zone_id
}

resource "aws_security_group" "bastion_ec2_public" {
  name   = "bastion-public-${var.env}-${var.instance}"
  vpc_id = module.vpc.vpc.id

  ingress {
    cidr_blocks = var.ingress_allowed_cidrs
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH access from allowed public IPs"
  }

  egress {
    cidr_blocks = [module.cidr.cidr_blocks[var.instance]["sandbox"][var.env]]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Access to machines in sandbox ${var.env} VPC"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "Internet access if required"
  }

  tags = {
    Name = "bastion-public-${var.env}-${var.instance}"
  }
}

resource "aws_iam_role" "bastion" {
  name = "bastion-${var.env}-${var.project}-${var.instance}"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach the role to the instance profile
resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-${var.env}-${var.project}-${var.instance}"
  role = aws_iam_role.bastion.name
}
