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
  subnet_id              = var.subnet_ids[var.subnet_type][0]

  root_block_device {
    volume_size = var.volume_size
  }

  user_data = templatefile("${path.module}/userdata.tpl",
    {
      nodename = "gitlab-${var.gitlab-version}"
  })

  key_name = aws_key_pair.gitlab.id

  tags = {
    Name = "gitlab-${var.gitlab-version}"
  }
}

resource "aws_security_group" "gitlab" {
  name        = "gitlab-instance-sg"
  description = "Security group for Gitlab Instance"
  vpc_id      = var.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}