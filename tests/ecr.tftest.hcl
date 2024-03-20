provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

run "without_repository" {
  command = plan

  variables {
    identifier = "abc"

    image = null

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }

  assert {
    condition     = length(aws_ecr_repository.main) == 1
    error_message = "ECR repository was not created"
  }
}

run "with_repository" {
  command = plan

  variables {
    identifier = "abc"

    image = {
      uri = "registry.test:latest"
    }

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }

  assert {
    condition     = length(aws_ecr_repository.main) == 0
    error_message = "ECR repository was created unexpectedly"
  }
}
