resource "aws_security_group" "alb" {
  count  = local.create_alb ? 1 : 0
  name   = "${var.name}-alb-sg"
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
    Name = "${var.name}-instance-alb-sg"
  }
}

resource "aws_lb" "main" {
  count                      = local.create_alb ? 1 : 0
  name                       = "${var.name}-instance-alb"
  internal                   = local.internal_alb
  load_balancer_type         = "application"
  security_groups            = aws_security_group.alb[*].id
  subnets                    = local.internal_alb ? var.subnet_ids["private"] : var.subnet_ids["public"]
  enable_deletion_protection = false

  tags = {
    Name = "${var.name}-instance-alb"
  }
}

resource "random_id" "target_group_id" {
  byte_length = 4
  keepers = {
    "load_balancer_id" = aws_lb.main[0].id
  }
}

resource "aws_alb_target_group" "main" {
  count       = local.create_alb ? 1 : 0
  name        = "${var.name}-instance-${random_id.target_group_id.hex}"
  port        = var.tls_termination ? 443 : 80
  protocol    = var.tls_termination ? "HTTPS" : "HTTP"
  vpc_id      = var.vpc.id
  target_type = "instance"
  depends_on  = [aws_lb.main]

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTPS"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name}-instance"
  }
}

resource "aws_lb_target_group_attachment" "main" {
  count            = local.create_alb ? 1 : 0
  target_group_arn = aws_alb_target_group.main[0].arn
  target_id        = aws_instance.main.id
  port             = var.tls_termination ? 443 : 80
}

# HTTP only listener
resource "aws_alb_listener" "http_only" {
  count             = local.create_alb && !var.tls_termination ? 1 : 0
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
}

# If subnet is public and no alb created then eip will be allocated
resource "aws_eip" "instance_eip" {
  count    = local.allocate_eip ? 1 : 0
  instance = aws_instance.main.id
  vpc      = true
  tags = {
    Name = "${var.name}-instance"
  }
}