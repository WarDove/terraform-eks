
data "aws_ami" "gitlab-ce" {
  most_recent = false
  owners      = ["679593333241"]
  name_regex  = "GitLab CE ${var.gitlab-version}"

  # As this data block doesn't depend on any variable and will be created
  # if syntax is valid, placing this precondition to be evaluated in this block
  # setting all general pre-conditions here:
  # If alb is set to "none" then certificate_arn is not needed and must be set
  # to none or omitted as argument input in root module.
  # Second precondition checks if  tls_termination value corresponds to certificate arn
  # both must be true or false: true == arn , false == none
  lifecycle {
    precondition {
      condition     = local.create_alb || var.certificate_arn == "none"
      error_message = "no alb listener will be created to attach the certificate!"
    }
    precondition {
      condition     = local.tls_input_verify
      error_message = "tls termination value doesn't correspond to certificate_arn value"
    }
  }
}

resource "aws_key_pair" "gitlab" {
  key_name   = "gitlab"
  public_key = file("${path.module}/public-key/id_rsa.pub")
}

resource "aws_instance" "gitlab" {
  ami                         = data.aws_ami.gitlab-ce.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.gitlab.id]
  subnet_id                   = local.subnet_ids[0]
  disable_api_termination     = true
  disable_api_stop            = true
  user_data_replace_on_change = false

  root_block_device {
    volume_size = var.volume_size
  }

  user_data = templatefile("${path.module}/userdata.tpl",
    {
      nodename = "gitlab-${var.gitlab-version}"
  })

  key_name = aws_key_pair.gitlab.id

  lifecycle {
    prevent_destroy = true
  }

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