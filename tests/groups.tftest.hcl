provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

run "invalid_identifier" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    node_groups = [
      {
        identifier      = "first-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "second-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "third-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "ab"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "fifth-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      }
    ]
  }

  expect_failures = [var.node_groups]
}

run "duplicated_identifier" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    node_groups = [
      {
        identifier      = "first-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "second-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "third-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "first-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "fifth-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      }
    ]
  }

  expect_failures = [var.node_groups]
}

run "min_size_bigger_than_max_size" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    node_groups = [
      {
        identifier      = "first-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "second-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
        min_size        = 2
        max_size        = 1
      },
      {
        identifier      = "third-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      }
    ]
  }

  expect_failures = [var.node_groups]
}

run "duplicate_taint_key" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    node_groups = [
      {
        identifier      = "first-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "second-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
        taints = [
          {
            key    = "first-key"
            value  = "true"
            effect = "NO_EXECUTE"
          },
          {
            key    = "second-key"
            value  = "true"
            effect = "NO_EXECUTE"
          },
          {
            key    = "first-key"
            value  = "true"
            effect = "NO_EXECUTE"
          }
        ]
      },
      {
        identifier      = "third-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      }
    ]
  }

  expect_failures = [var.node_groups]
}

run "invalid_taint_effect" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    node_groups = [
      {
        identifier      = "first-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      },
      {
        identifier      = "second-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
        taints = [
          {
            key    = "first-key"
            value  = "true"
            effect = "NO_EXECUTE"
          },
          {
            key    = "second-key"
            value  = "true"
            effect = "NO_EXECUTE"
          },
          {
            key    = "third-key"
            value  = "true"
            effect = "NO_TEST"
          },
          {
            key    = "fourth-key"
            value  = "true"
            effect = "NO_EXECUTE"
          }
        ]
      },
      {
        identifier      = "third-node-group"
        subnets         = ["subnet-"]
        launch_template = "lt-testid"
      }
    ]
  }

  expect_failures = [var.node_groups]
}
