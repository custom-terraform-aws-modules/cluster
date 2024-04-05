provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

run "duplicate_service_account_key" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    service_accounts = [
      {
        name_space      = "default"
        service_account = "bar"
        iam_role_name   = "test-service-role-one"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "foo"
        iam_role_name   = "test-service-role-two"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "test"
        iam_role_name   = "test-service-role-three"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "test"
        iam_role_name   = "test-service-role-four"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      }
    ]
  }

  expect_failures = [var.service_accounts]
}

run "duplicate_service_account_name" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    service_accounts = [
      {
        name_space      = "default"
        service_account = "bar"
        iam_role_name   = "test-service-role-one"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "test"
        iam_role_name   = "test-service-role-two"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "hihi"
        iam_role_name   = "test-service-role-three"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "another-namespace"
        service_account = "bar"
        iam_role_name   = "test-service-role-four"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      }
    ]
  }
}

run "duplicate_iam_role_name" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    service_accounts = [
      {
        name_space      = "default"
        service_account = "bar"
        iam_role_name   = "test-service-role-one"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "test"
        iam_role_name   = "test-service-role-two"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "hihi"
        iam_role_name   = "test-service-role-two"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "part"
        iam_role_name   = "test-service-role-four"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      }
    ]
  }

  expect_failures = [var.service_accounts]
}

run "empty_policies" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    service_accounts = [
      {
        name_space      = "default"
        service_account = "bar"
        iam_role_name   = "test-service-role-one"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "test"
        iam_role_name   = "test-service-role-two"
        policies        = []
      },
      {
        name_space      = "default"
        service_account = "hihi"
        iam_role_name   = "test-service-role-three"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "part"
        iam_role_name   = "test-service-role-four"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      }
    ]
  }

  expect_failures = [var.service_accounts]
}

run "valid_service_accounts" {
  command = plan

  variables {
    identifier = "abc"
    subnets    = ["subnet-"]
    service_accounts = [
      {
        name_space      = "default"
        service_account = "bar"
        iam_role_name   = "test-service-role-one"
        policies        = ["arn:aws:iam::123456789012:policy/ManageCredentialsPermissions"]
      },
      {
        name_space      = "default"
        service_account = "test"
        iam_role_name   = "test-service-role-two"
        policies = [
          "arn:aws:iam::123456789012:policy/ManageCredentialsPermissions",
          "arn:aws:iam::123456789012:policy/my-test-policy"
        ]
      },
      {
        name_space      = "default"
        service_account = "hihi"
        iam_role_name   = "test-service-role-three"
        policies = [
          "arn:aws:iam::123456789012:policy/ManageCredentialsPermissions",
          "arn:aws:iam::123456789012:policy/my-test-policy"
        ]
      },
      {
        name_space      = "default"
        service_account = "part"
        iam_role_name   = "test-service-role-four"
        policies = [
          "arn:aws:iam::123456789012:policy/ManageCredentialsPermissions",
          "arn:aws:iam::123456789012:policy/my-test-policy"
        ]
      }
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.main) == 7
    error_message = "Unexpected amount of policy attachments has been created"
  }
}
