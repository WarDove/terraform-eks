resource "aws_security_group" "alb" {
  count  = local.create_alb ? 1 : 0
  name   = "gitlab-instance-alb-sg"
  vpc_id = var.vpc.id

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "gitlab-instance-alb-sg"
  }
}

resource "aws_lb" "main" {
  count                      = local.create_alb ? 1 : 0
  name                       = "gitlab-instance-alb"
  internal                   = local.internal_alb
  load_balancer_type         = "application"
  security_groups            = aws_security_group.alb[*].id
  subnets                    = local.subnet_ids
  enable_deletion_protection = false

  tags = {
    Name = "gitlab-instance-alb"
  }
}

resource "aws_alb_target_group" "main" {
  count       = local.create_alb ? 1 : 0
  name        = "gitlab-instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc.id
  target_type = "instance"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/-/health"
    unhealthy_threshold = "2"
  }

  tags = {
    Name = "gitlab-instance"
  }
}

# HTTP only listener
resource "aws_alb_listener" "http_only" {
  count             = local.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.main[0].id
    type             = "forward"
  }
}

# HTTPS
resource "aws_alb_listener" "http" {
  count             = local.create_alb && var.tls_termination ? 1 : 0
  load_balancer_arn = aws_lb.main[0].id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTP to HTTPS redirect
resource "aws_alb_listener" "https" {
  count             = local.create_alb && var.tls_termination ? 1 : 0
  load_balancer_arn = aws_lb.main[0].id
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.main[0].id
    type             = "forward"
  }

  lifecycle {
    precondition {
      condition     = var.tls_termination == true && var.certificate_arn != "none"
      error_message = "Invalid input: TLS termination is on, certificate cannot be set to \"none\""
    }
  }
}

# If subnet is public and no alb created then eip will be allocated
resource "aws_eip" "ngw_eip" {
  count    = local.allocate_eip ? 1 : 0
  instance = aws_instance.gitlab.id
  vpc      = true
  tags = {
    Name = "gitlab-instance"
  }
}