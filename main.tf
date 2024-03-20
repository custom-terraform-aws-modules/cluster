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
  name              = "${var.identifier}-fargate"
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
  desired_count        = var.desired_task_count
  force_new_deployment = true

  network_configuration {
    subnets          = try(var.network_config["subnets"], null)
    assign_public_ip = false
    security_groups  = var.security_groups
  }

  tags = var.tags
}
