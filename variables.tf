variable "identifier" {
  description = "Unique identifier to differentiate global resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "domain" {
  description = "Custom domain pointed to the load balancer."
  type        = string
}

variable "policies" {
  description = "List of IAM policy ARNs for the Fargate task's IAM role."
  type        = list(string)
  default     = []
}

variable "log_config" {
  description = "Object to define logging configuration for the Fargate tasks to CloudWatch."
  type = object({
    region            = string
    retention_in_days = number
  })
  validation {
    condition = try(var.log_config["retention_in_days"], 1) == 1 || (
      try(var.log_config["retention_in_days"], 3) == 3) || (
      try(var.log_config["retention_in_days"], 5) == 5) || (
      try(var.log_config["retention_in_days"], 7) == 7) || (
      try(var.log_config["retention_in_days"], 14) == 14) || (
      try(var.log_config["retention_in_days"], 30) == 30) || (
      try(var.log_config["retention_in_days"], 365) == 365) || (
    try(var.log_config["retention_in_days"], 0) == 0)
    error_message = "Retention in days must be one of these values: 0, 1, 3, 5, 7, 14, 30, 365"
  }
}

variable "image" {
  description = "Object of the image which will be pulled by the Fargate tasks to execute."
  type = object({
    uri = string
  })
  default = null
}

variable "security_groups" {
  description = "List of security group IDs the ECS service will hold."
  type        = list(string)
  default     = []
  validation {
    condition     = !contains([for v in var.security_groups : startswith(v, "sg-")], false)
    error_message = "Elements must be valid security group IDs"
  }
}

variable "network_config" {
  description = "Object of definition for the network configuration of the ECS service."
  type = object({
    vpc          = string
    task_subnets = list(string)
    lb_subnets   = list(string)
  })
  validation {
    condition     = startswith(try(var.network_config["vpc"], null), "vpc-")
    error_message = "Must be valid VPC ID"
  }
  validation {
    condition     = !contains([for v in var.network_config["task_subnets"] : startswith(v, "subnet-")], false)
    error_message = "Elements in task subnets must be valid subnet IDs"
  }
  validation {
    condition     = !contains([for v in var.network_config["lb_subnets"] : startswith(v, "subnet-")], false)
    error_message = "Elements in load balancer subnets must be valid subnet IDs"
  }
}

variable "env_variables" {
  description = "A map of environment variables for the Fargate task at runtime."
  type        = map(string)
  default     = {}
}

variable "idle_timeout" {
  description = "Timeout in seconds of how long the load balancer will wait for a response from the containers."
  type        = number
  default     = 180
}

variable "container_port" {
  description = "Port on which the application of the container listens."
  type        = number
  default     = 8000
}

variable "health_check" {
  description = "Route of the application for health checks of the container from the load balancer."
  type        = string
  default     = "/health"
}

variable "memory" {
  description = "Amount of memory in MiB used by each Fargate tasks."
  type        = number
  default     = 512
}

variable "cpu" {
  description = "Number of CPU units used by each Fargate tasks."
  type        = number
  default     = 256
}

variable "memory_limit" {
  description = "Percentage of maximum average memory usage of the Fargate tasks, when the service should get scaled up."
  type        = number
  default     = 80
}

variable "cpu_limit" {
  description = "Percentage of maximum average CPU usage of the Fargate tasks, when the service should get scaled up."
  type        = number
  default     = 70
}

variable "min_count" {
  description = "Minimum amount of Fargate tasks running."
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum amount of Fargate tasks running."
  type        = number
  default     = 1
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "test" {
  description = "A flag for wether or not creating a test environment to conduct unit tests with."
  type        = bool
  default     = false
}
