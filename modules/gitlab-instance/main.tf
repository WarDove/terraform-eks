
data "aws_ami" "main" {
  most_recent = false
  owners      = var.ami_owners
  name_regex  = var.ami_regex

  # As this data block doesn't depend on any variable and will be created
  # if syntax is valid, placing this precondition to be evaluated in this block
  # setting all general pre-conditions here:
  # If alb is set to "none" then certificate_arn is not needed and must be set
  # to none or omitted as argument input in root module.
  # Second precondition checks if  tls_termination value corresponds to certificate arn
  # both must be true or false: true == arn , false == none
  lifecycle {
    precondition {
      condition     = var.alb || var.internal_alb || var.certificate_arn == "none"
      error_message = "no alb listener will be created to attach the certificate!"
    }
    precondition {
      condition     = local.tls_input_verify
      error_message = "tls termination value doesn't correspond to certificate_arn value"
    }
  }
}

resource "aws_key_pair" "main" {
  key_name   = "${var.name}-instance-key"
  public_key = var.public_key
}

resource "aws_instance" "main" {
  ami                    = data.aws_ami.main.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = local.subnet_ids[0]
  #disable_api_termination     = true
  #disable_api_stop            = true
  user_data_replace_on_change = false

  root_block_device {
    volume_size = var.volume_size
    encrypted   = var.encrypted_volume
  }

  user_data = var.user_data

  key_name = aws_key_pair.main.id

  lifecycle {
    ignore_changes  = [user_data]
    prevent_destroy = false
  }

  tags = {
    Name    = var.name
    version = data.aws_ami.main.name_regex
  }
}

resource "aws_security_group" "main" {
  name        = "${var.name}-instance-sg"
  description = "Security group for ${var.name} Instance"
  vpc_id      = var.vpc.id

  dynamic "ingress" {
    for_each = local.instance_ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  # Adding external ssh access if at least one cidr block is set in external_ssh
  dynamic "ingress" {
    for_each = length(var.external_ssh) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.external_ssh
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-instance-sg"
  }
}