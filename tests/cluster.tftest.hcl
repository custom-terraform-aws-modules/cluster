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
    identifier = "ab"

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }

  expect_failures = [var.identifier]
}

run "invalid_vpc" {
  command = plan

  variables {
    identifier = "abc"

    network_config = {
      vpc     = "abc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }

  expect_failures = [var.network_config]
}

run "invalid_subnets" {
  command = plan

  variables {
    identifier = "abc"

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "net-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }

  expect_failures = [var.network_config]
}

run "valid_configuration" {
  command = plan

  variables {
    identifier = "abc"

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }
}

run "invalid_security_groups" {
  command = plan

  variables {
    identifier      = "abc"
    security_groups = ["sg-we32558632", "s23423423432", "sg-893hgo23hg23"]

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 7
    }
  }

  expect_failures = [var.security_groups]
}

run "invalid_retention_in_days" {
  command = plan

  variables {
    identifier = "abc"

    network_config = {
      vpc     = "vpc-01234567890abcdef"
      subnets = ["subnet-1242421", "subnet-2344898"]
    }

    log_config = {
      region            = "eu-central-1"
      retention_in_days = 6
    }
  }

  expect_failures = [var.log_config]
}
