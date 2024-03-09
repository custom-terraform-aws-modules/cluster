################################
# Route53                      #
################################

locals {
  sub_strings = split(".", var.domain)
  base_domain = "${local.sub_strings[length(local.sub_strings) - 2]}.${local.sub_strings[length(local.sub_strings) - 1]}"
}

# get public zone for base domain (must be already present in account)
data "aws_route53_zone" "main" {
  count        = !var.test ? 1 : 0
  name         = local.base_domain
  private_zone = false
}

# conditionally set the zone_id to a dummy value for unit tests to run
locals {
  zone_id = !var.test ? data.aws_route53_zone.main[0].id : "testzone123"
}

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain
  validation_method = "DNS"
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

################################
# IAM Roles                    #
################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.identifier}-ServiceRoleForECSExecution"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role" "task" {
  name               = "${var.identifier}-ServiceRoleForECSTask"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task" {
  count      = length(var.policies)
  role       = aws_iam_role.task.name
  policy_arn = var.policies[count.index]
}

################################
# CloudWatch                   #
################################

resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/fargate/${var.identifier}"
  retention_in_days = try(var.log_config["retention_in_days"], null)

  tags = var.tags
}

################################
# ECR Repository               #
################################

resource "aws_ecr_repository" "main" {
  count                = var.image == null ? 1 : 0
  name                 = "${var.identifier}-cluster"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = var.tags
}

################################
# Security Groups              #
################################

resource "aws_security_group" "lb" {
  name        = "${var.identifier}-load-balancer"
  description = "Allows the load balancer to access the container and be accessed."
  vpc_id      = try(var.network_config["vpc"], null)

  tags = var.tags
}

resource "aws_security_group" "container" {
  name        = "${var.identifier}-container"
  description = "Allows the container to be accessed by the load balancer."
  vpc_id      = try(var.network_config["vpc"], null)

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.lb.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.lb.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lb" {
  security_group_id            = aws_security_group.lb.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.container.id
}

resource "aws_vpc_security_group_ingress_rule" "container" {
  security_group_id            = aws_security_group.container.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.lb.id
}

################################
# Load Balancer                #
################################

resource "aws_lb" "main" {
  name                             = var.identifier
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.lb.id]
  subnets                          = try(var.network_config["lb_subnets"], null)
  idle_timeout                     = var.idle_timeout
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = var.tags
}

resource "aws_route53_record" "main" {
  zone_id = local.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}

resource "aws_alb_target_group" "main" {
  name        = var.identifier
  port        = 80
  protocol    = "HTTP"
  vpc_id      = try(var.network_config["vpc"], null)
  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    interval            = 30
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = 3
    path                = var.health_check
    unhealthy_threshold = 2
  }

  tags = var.tags
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
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

  tags = var.tags
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }

  tags = var.tags
}

################################
# ECS Cluster                  #
################################

resource "aws_ecs_cluster" "main" {
  name = var.identifier

  tags = var.tags
}

resource "aws_ecs_task_definition" "main" {
  family                   = var.identifier
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions = jsonencode([{
    name        = var.identifier
    image       = var.image == null ? "${aws_ecr_repository.main[0].repository_url}:latest" : try(var.image["uri"], null)
    environment = var.env_variables
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.main.id
        awslogs-region        = try(var.log_config["region"], null)
        awslogs-stream-prefix = "cluster"
      }
    }
  }])
  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name                 = var.identifier
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.main.arn
  launch_type          = "FARGATE"
  desired_count        = var.min_count
  force_new_deployment = true

  network_configuration {
    subnets          = try(var.network_config["task_subnets"], null)
    assign_public_ip = false
    security_groups  = concat(var.security_groups, [aws_security_group.container.id])
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = var.identifier
    container_port   = var.container_port
  }

  tags = var.tags
}

################################
# Autoscaling                  #
################################

resource "aws_appautoscaling_target" "main" {
  max_capacity       = var.max_count
  min_capacity       = var.min_count
  resource_id        = "service/${var.identifier}/${var.identifier}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.tags
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.identifier}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = var.memory_limit
  }
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.identifier}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = var.cpu_limit
  }
}
