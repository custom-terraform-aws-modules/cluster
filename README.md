# Modules: Cluster

This is an agglomeration of Terraform modules relevant to build a Fargate ECS cluster. After creating a base ECS cluster any amount of services can be added to the cluster. With service discovery private DNS namespaces can be created for cluster internal communication between services. Services can also be autoscaled and publicly exposed by adding them to a target group of the load balancer module.

![Cluster visualized](.github/diagrams/cluster-transparent.png)

## Contents

- [Requirements](#requirements)
- [Examples](#examples)

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | >= 5.20 |

## Examples

```hcl
module "cluster" {
  source = "github.com/custom-terraform-aws-modules/cluster/cluster"

  identifier = "example-cluster"

  log_config = {
    retention_in_days = 7
  }

  tags = {
    Project     = "example-project"
    Environment = "dev"
  }
}

module "load_balancer" {
  source = "github.com/custom-terraform-aws-modules/cluster/load-balancer"

  identifier = "example-load-balancer"
  vpc_id     = "vpc-1234567890"
  subnets    = ["subnet-1", "subnet-2", "subnet-3"]

  target_groups = [
    {
      name              = "first-target-group"
      host_domain       = "example.com"
      certificate_arn   = "arn:aws:acm:eu-central-1:1234567890:example"
      health_check_path = "/health"
    }
  ]

  tags = {
    Project     = "example-project"
    Environment = "dev"
  }
}

module "cache_service" {
  source = "github.com/custom-terraform-aws-modules/cluster/service"

  identifier         = "cache-service"
  cluster_id         = module.cluster.id
  region             = "eu-central-1"
  cpu_architecture   = "ARM64"
  dns_namespace      = "cache.local"
  vpc_id             = "vpc-1234567890"
  execution_role_arn = "arn:aws:iam::1234567890:role/execution-role"
  container_port     = 6379
  subnets            = ["subnet-1", "subnet-2", "subnet-3"]
  task_count         = 1
  task_cpu           = 256
  task_memory        = 512

  image = {
    uri = "redis:latest"
  }

  log_config = {
    retention_in_days = 7
  }

  tags = {
    Project     = "example-project"
    Environment = "dev"
  }
}

module "web_server_service" {
  source = "github.com/custom-terraform-aws-modules/cluster/service"

  identifier         = "web-server-service"
  cluster_id         = module.cluster.id
  region             = "eu-central-1"
  cpu_architecture   = "ARM64"
  vpc_id             = "vpc-1234567890"
  execution_role_arn = "arn:aws:iam::1234567890:role/execution-role"
  container_port     = 8000
  subnets            = ["subnet-1", "subnet-2", "subnet-3"]
  security_groups    = [module.cache_service.security_group]
  target_group       = module.load_balancer.target_groups[0]
  task_count         = 3
  task_cpu           = 256
  task_memory        = 512

  autoscaling = {
    min_count = 3
    max_count = 5
  }

  log_config = {
    retention_in_days = 7
  }

  tags = {
    Project     = "example-project"
    Environment = "dev"
  }
}
```
