locals {
  subnet_ids = var.subnet_ids[var.subnet_type]

}

data "aws_ami" "gitlab-ce" {
  most_recent = false
  owners      = ["679593333241"]
  name_regex  = "GitLab CE ${var.gitlab-version}"
}

resource "aws_key_pair" "gitlab" {
  key_name   = "gitlab"
  public_key = file("${path.module}/public-key/id_rsa.pub")
}

resource "aws_instance" "gitlab" {
  ami                    = data.aws_ami.gitlab-ce.id
  instance_type          = var.instance_type
  vpc_security_group_ids = []
  subnet_id              = local.subnet_ids[0]

  root_block_device {
    volume_size = var.volume_size
  }

  user_data = templatefile("${path.module}/userdata.tpl",
    {
      nodename = "gitlab-${var.gitlab-version}"
  })

  key_name = aws_key_pair.gitlab.id

  tags = {
    Name    = "gitlab-${var.gitlab-version}"
    version = data.aws_ami.gitlab-ce.name_regex
  }
}

resource "aws_security_group" "gitlab" {
  name        = "gitlab-instance-sg"
  description = "Security group for Gitlab Instance"
  vpc_id      = var.vpc.id

  dynamic "ingress" {
    for_each = local.gitlab_ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitlab-instance"
  }
}